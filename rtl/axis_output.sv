// axis_output.sv -- AXI4-Stream 输出接口
//
// 功能：
//   1. 在 shift_en=1 时，按光栅扫描顺序通过 AXI-Stream Master 输出数据
//   2. 内部维护 row_cnt/col_cnt 计数器，生成 tuser（帧起始）和 tlast（行结束）
//   3. zero_fill=1 时输出数据强制为 0
//   4. 最后一拍握手完成后发出 shift_done 脉冲（1 周期）
//   5. 支持下游背压（tready=0 时暂停计数器，数据保持）
//
// 流水线对齐修正 (2026-06-05):
//   frame_buf_mgr 读数据有 1 周期延迟（read_data 在 read_addr 后的下
//   一拍有效）。原始代码中 tuser/tlast/tvalid 基于内部计数器（在 read_data
//   到达的同一拍提前递增），导致：
//     - tuser 在数据有效时已归零（第 2 拍才置位）
//     - tlast 在行末数据有效时已归零
//     - tvalid 在最后一个像素数据有效时变低（all_done 提前置位）
//   修正：引入 row_cnt_q/col_cnt_q 寄存器保存递增前的计数器值，用于
//   tuser/tlast 生成；引入 all_done_q 将 tvalid 关闭延迟 1 拍，使最后
//   一个像素能被正常捕获。
//
// 接口说明：
//   参数
//     DATA_WIDTH : 数据位宽（默认 8）
//     MAX_ROWS   : 最大行数（默认 64，保留未直接使用）
//     MAX_COLS   : 最大列数（默认 64，保留未直接使用）
//   控制输入
//     shift_en       : 移位使能（来自 ctrl_fsm）
//     img_rows[9:0]  : 图像行数（来自 regs_top）
//     img_cols[9:0]  : 图像列数（来自 regs_top）
//   数据输入
//     read_data      : 帧缓冲读数据（来自 frame_buf_mgr）
//     zero_fill      : 补零标志（来自 shift_addr_gen，已与 read_data 对齐）
//   AXI-Stream Master 接口
//     m_axis_tdata   : 输出数据
//     m_axis_tvalid  : 输出有效
//     m_axis_tready  : 下游就绪
//     m_axis_tlast   : 行结束标志
//     m_axis_tuser   : 帧起始标志
//   完成输出
//     shift_done     : 移位完成脉冲（1 周期，送至 ctrl_fsm）

module axis_output #(
    parameter DATA_WIDTH = 8,
    parameter MAX_ROWS   = 64,
    parameter MAX_COLS   = 64
) (
    input  logic        clk,
    input  logic        rstn,

    // 控制接口
    input  logic        shift_en,
    input  logic [ 9:0] img_rows,
    input  logic [ 9:0] img_cols,

    // 数据输入
    input  logic [DATA_WIDTH-1:0] read_data,
    input  logic                   zero_fill,
    input  logic                   data_valid_i,   // SAG 流水线有效（经 BRAM 延迟对齐）

    // AXI-Stream Master 接口
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                   m_axis_tvalid,
    input  logic                   m_axis_tready,
    output logic                   m_axis_tlast,
    output logic                   m_axis_tuser,

    // 完成
    output logic                   shift_done
);

    // ============================================================
    // 内部信号
    // ============================================================
    logic       all_done;        // 所有像素已输出完毕（内部，提前 1 拍）
    logic [9:0] row_cnt;         // 当前输出行位置（0 ~ img_rows-1）
    logic [9:0] col_cnt;         // 当前输出列位置（0 ~ img_cols-1）

    // 流水线对齐寄存器（保存递增前的计数器值，与 read_data 对齐）
    logic [9:0] row_cnt_q;
    logic [9:0] col_cnt_q;
    logic       all_done_q;      // 延迟 1 拍的 all_done，用于 tvalid 关闭

    // ============================================================
    // 计数器与状态控制
    //
    // - shift_en=0 时所有计数器复位到 0，准备下一帧
    // - shift_en=1 && tready=1 且未完成时，光栅扫描推进计数器
    // - 最后一拍握手成功时拉高 shift_done 并置 all_done
    // - shift_done 默认每个周期清零，仅产生 1 周期脉冲
    //
    // 流水线对齐：row_cnt_q/col_cnt_q 在 posedge 捕获 row_cnt/col_cnt
    // 的递增前值，用于输出控制信号，使其与从 BRAM 读回的 read_data 对齐。
    // 这样 tuser 在第一个像素有效时正确置位，tlast 在行末正确置位。
    // all_done_q 将 tvalid 关闭延迟 1 拍，确保最后一个像素被输出。
    // ============================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            row_cnt    <= '0;
            col_cnt    <= '0;
            all_done   <= 1'b0;
            shift_done <= 1'b0;
            row_cnt_q  <= '0;
            col_cnt_q  <= '0;
            all_done_q <= 1'b0;
        end else begin
            shift_done <= 1'b0;  // 默认清零

            // 捕获递增前的计数器值（流水线对齐）
            row_cnt_q  <= row_cnt;
            col_cnt_q  <= col_cnt;
            all_done_q <= all_done;

            if (!shift_en) begin
                // 移位未使能：复位计数器，准备下一帧
                row_cnt  <= '0;
                col_cnt  <= '0;
                all_done <= 1'b0;
            end else if (m_axis_tready && data_valid_i && !all_done) begin
                // 握手成功，按光栅扫描顺序推进
                if (col_cnt == img_cols - 1) begin
                    col_cnt <= '0;
                    if (row_cnt == img_rows - 1) begin
                        // 最后一拍已传输完毕
                        row_cnt    <= '0;
                        all_done   <= 1'b1;
                        shift_done <= 1'b1;
                    end else begin
                        row_cnt <= row_cnt + 1'b1;
                    end
                end else begin
                    col_cnt <= col_cnt + 1'b1;
                end
            end
        end
    end

    // ============================================================
    // 输出组合逻辑
    //
    // - m_axis_tvalid: 使用延迟 1 拍的 all_done_q，确保最后一个像素
    //   的数据输出时 tvalid 仍为高
    // - m_axis_tdata:  zero_fill=1 时强制输出 0，否则透传 read_data
    // - m_axis_tlast:  使用延迟 1 拍的 col_cnt_q，对齐 BRAM 读延迟
    // - m_axis_tuser:  使用延迟 1 拍的 row_cnt_q/col_cnt_q，对齐 BRAM 读延迟
    // ============================================================
    assign m_axis_tvalid = shift_en && data_valid_i && !all_done_q;
    assign m_axis_tdata  = zero_fill ? {DATA_WIDTH{1'b0}} : read_data;
    assign m_axis_tlast  = shift_en && !all_done_q && (col_cnt_q == img_cols - 1);
    assign m_axis_tuser  = shift_en && !all_done_q && (row_cnt_q == '0 && col_cnt_q == '0);

endmodule

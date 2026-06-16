//==============================================================================
// axis_input - AXI4-Stream 输入接口模块
//
// 功能:
//   接收 AXI4-Stream 数据，按光栅顺序生成帧缓冲 BRAM 写地址。
//   在 capture_en=1 时采集数据，维护 row_cnt/col_cnt 跟踪二维位置，
//   收满 img_rows*img_cols 个元素后发出 capture_done 脉冲。
//
// 地址生成:
//   write_addr = row_cnt * img_cols + col_cnt（组合逻辑）
//
// 输入:
//   clk, rstn           - 单时钟域，同步复位（低有效）
//   s_axis_tdata        - AXI-Stream 数据
//   s_axis_tvalid       - AXI-Stream 有效标志
//   s_axis_tlast        - 行结束标志
//   s_axis_tuser        - 帧起始标志
//   capture_en          - 采集使能（来自 ctrl_fsm）
//   img_rows[9:0]       - 图像行数（来自 regs_top）
//   img_cols[9:0]       - 图像列数（来自 regs_top）
//
// 输出:
//   s_axis_tready       - AXI-Stream 就绪（= capture_en）
//   write_addr[11:0]    - BRAM 写地址（组合逻辑）
//   write_data[DATA_WIDTH-1:0] - BRAM 写数据（= s_axis_tdata）
//   write_en            - BRAM 写使能
//   capture_done        - 采集完成脉冲（1 周期宽）
//==============================================================================

module axis_input #(
    parameter DATA_WIDTH = 8,
    parameter MAX_ROWS   = 64,
    parameter MAX_COLS   = 64
) (
    input  logic                     clk,
    input  logic                     rstn,

    input  logic [DATA_WIDTH-1:0]    s_axis_tdata,
    input  logic                     s_axis_tvalid,
    output logic                     s_axis_tready,
    input  logic                     s_axis_tlast,
    input  logic                     s_axis_tuser,

    input  logic                     capture_en,

    input  logic [9:0]               img_rows,
    input  logic [9:0]               img_cols,

    output logic [11:0]              write_addr,
    output logic [DATA_WIDTH-1:0]    write_data,
    output logic                     write_en,

    output logic                     capture_done
);

    // --------------------------------------------------------------------------
    // 内部信号
    // --------------------------------------------------------------------------
    logic [9:0] row_cnt;
    logic [9:0] col_cnt;
    logic       xfer_valid;

    // --------------------------------------------------------------------------
    // AXI-Stream 就绪（寄存输出以满足 100MHz 时序）
    // capture_en=0 时 tready=0，不接收数据
    // --------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) s_axis_tready <= 1'b0;
        else       s_axis_tready <= capture_en;
    end

    // --------------------------------------------------------------------------
    // 有效传输指示
    // --------------------------------------------------------------------------
    assign xfer_valid = capture_en & s_axis_tvalid & s_axis_tready;

    // --------------------------------------------------------------------------
    // 写接口（组合逻辑）
    // write_addr 使用组合逻辑，与 frame_buf_mgr 的 BRAM 直接连接。
    // 同一时钟沿上，frame_buf_mgr 的写 always_ff 与 axis_input 的计数器
    // 更新 always_ff 均在 active region 执行，采样写使能前的地址值，
    // 因此组合逻辑 write_addr 在此处是正确的（写入当前像素的地址）。
    // --------------------------------------------------------------------------
    assign write_data = s_axis_tdata;
    assign write_en   = xfer_valid;
    assign write_addr = (row_cnt * img_cols) + col_cnt;

    // --------------------------------------------------------------------------
    // 计数器与 capture_done 寄存器
    //
    // 计数器更新规则：
    //   - capture_en=0 时：计数器复位到 0，确保 SW_RESET 后重新开始采集
    //     时从地址 0 开始写入，避免因前次部分采集残留的计数器值导致
    //     写地址偏移。
    //   - tuser=1（帧起始）：重置到 (row=0, col=0)
    //     - 若 tlast 同时有效（单列图像），按 img_rows 判断帧完成或换行
    //     - 否则下一元素为 (0, 1)
    //   - tlast=1（行结束）：col 归零，row 递增
    //     - 若 row==img_rows-1，表明最后一行的 tlast，帧采集完成
    //   - 默认：col 递增
    // --------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            row_cnt      <= '0;
            col_cnt      <= '0;
            capture_done <= 1'b0;
        end else begin
            // capture_done 在 capture_en 拉低时清零，而非每拍自清除。
            // 这确保 ctrl_fsm 有足够时间看到高电平并在下一拍跳转到 SHIFT。

            if (!capture_en) begin
                // capture_en=0 时复位计数器，确保下次 capture_en=1 时
                // 从 (row=0, col=0) 开始写入，与 axis_output 的 !shift_en
                // 复位行为保持一致。
                row_cnt      <= '0;
                col_cnt      <= '0;
                capture_done <= 1'b0;
            end else if (xfer_valid) begin
                if (s_axis_tuser) begin
                    // ----------------------------------------------------------
                    // 帧起始：重置计数器
                    // ----------------------------------------------------------
                    if (s_axis_tlast) begin
                        // tuser + tlast 同时有效，只可能发生在单列图像
                        if (img_rows > 1) begin
                            // 多行单列：当前元素结束本行，下一行开始
                            row_cnt <= row_cnt + 1'b1;
                            col_cnt <= '0;
                        end else begin
                            // 单行单列：仅此一个元素，帧完成
                            capture_done <= 1'b1;
                            row_cnt      <= '0;
                            col_cnt      <= '0;
                        end
                    end else begin
                        // 正常多列图像：下一元素从 col=1 开始
                        row_cnt <= '0;
                        col_cnt <= 1'b1;
                    end

                end else if (s_axis_tlast || (col_cnt == img_cols - 1)) begin
                    // ----------------------------------------------------------
                    // 行结束：col 归零，row 递增
                    // ----------------------------------------------------------
                    col_cnt <= '0;
                    if (row_cnt == img_rows - 1) begin
                        // 最后一行完成
                        capture_done <= 1'b1;
                        row_cnt      <= '0;
                    end else begin
                        row_cnt <= row_cnt + 1'b1;
                    end

                end else begin
                    // ----------------------------------------------------------
                    // 正常列递增
                    // ----------------------------------------------------------
                    col_cnt <= col_cnt + 1'b1;
                end
            end
        end
    end

endmodule

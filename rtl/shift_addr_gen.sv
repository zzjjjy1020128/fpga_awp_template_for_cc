// shift_addr_gen.sv -- 移位地址生成器
//
// 功能：
//   1. 内部维护 row_cnt/col_cnt 计数器，跟踪输出位置（光栅扫描顺序）
//   2. 根据 cfg_dir/cfg_step/cfg_wrap_en 计算帧缓冲读出地址
//   3. 支持 NONE / UP / DOWN / LEFT / RIGHT 五种模式
//   4. wrap_en=1 时用取模实现缠绕；wrap_en=0 时对越界地址输出 zero_fill=1
//
// 地址计算公式（base_addr = row * IMG_COLS + col）：
//   NONE : base_addr
//   UP   : ((row + step) % IMG_ROWS) * IMG_COLS + col
//   DOWN : ((row - step + IMG_ROWS) % IMG_ROWS) * IMG_COLS + col
//   LEFT : row * IMG_COLS + ((col + step) % IMG_COLS)
//   RIGHT: row * IMG_COLS + ((col - step + IMG_COLS) % IMG_COLS)
//
// 接口说明：
//   参数
//     MAX_ROWS : 最大行数（默认 64）
//     MAX_COLS : 最大列数（默认 64）
//   控制输入（来自 regs_top / ctrl_fsm）
//     cfg_dir[2:0]    : 移位方向 000=NONE 001=UP 010=DOWN 011=LEFT 100=RIGHT
//     cfg_step[4:0]   : 移位步长（0~31）
//     cfg_wrap_en     : 缠绕使能（0=补零，1=缠绕）
//     shift_en        : 移位使能（来自 ctrl_fsm，每拍一个像素）
//     img_rows[9:0]   : 图像行数
//     img_cols[9:0]   : 图像列数
//   输出（至 frame_buf_mgr）
//     read_addr[11:0] : BRAM 读地址（组合逻辑输出）
//     zero_fill       : 补零标志（wrap_en=0 且越界时为 1）

module shift_addr_gen #(
    parameter  MAX_ROWS = 64,
    parameter  MAX_COLS = 64
) (
    input  logic        clk,
    input  logic        rstn,

    // 配置接口
    input  logic [ 2:0] cfg_dir,
    input  logic [ 4:0] cfg_step,
    input  logic        cfg_wrap_en,
    input  logic        shift_en,
    input  logic [ 9:0] img_rows,
    input  logic [ 9:0] img_cols,

    // 输出接口
    output logic [11:0] read_addr,
    output logic        zero_fill
);

    // ============================================================
    // 输出位置计数器（光栅扫描顺序）
    // ============================================================
    logic [9:0] row_cnt, col_cnt;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            row_cnt <= '0;
            col_cnt <= '0;
        end else if (shift_en) begin
            if (col_cnt == img_cols - 1) begin
                col_cnt <= '0;
                if (row_cnt == img_rows - 1) begin
                    row_cnt <= '0;
                end else begin
                    row_cnt <= row_cnt + 1'b1;
                end
            end else begin
                col_cnt <= col_cnt + 1'b1;
            end
        end
    end

    // ============================================================
    // 地址计算（组合逻辑）
    // ============================================================
    logic [9:0] step;
    logic [9:0] calc_row;
    logic [9:0] calc_col;
    logic       is_zero;

    assign step = {5'd0, cfg_step};  // 零扩展至 10 位

    always_comb begin
        // 默认：NONE 模式
        calc_row = row_cnt;
        calc_col = col_cnt;
        is_zero  = 1'b0;

        case (cfg_dir)
            3'b001: begin  // UP
                if (cfg_wrap_en) begin
                    calc_row = (row_cnt + step) % img_rows;
                end else begin
                    is_zero  = (row_cnt + step >= img_rows);
                    calc_row = is_zero ? row_cnt : (row_cnt + step);
                end
                calc_col = col_cnt;
            end

            3'b010: begin  // DOWN
                if (cfg_wrap_en) begin
                    calc_row = (row_cnt + img_rows - (step % img_rows)) % img_rows;
                end else begin
                    is_zero  = (row_cnt < step);
                    calc_row = is_zero ? row_cnt : (row_cnt - step);
                end
                calc_col = col_cnt;
            end

            3'b011: begin  // LEFT
                if (cfg_wrap_en) begin
                    calc_col = (col_cnt + step) % img_cols;
                end else begin
                    is_zero  = (col_cnt + step >= img_cols);
                    calc_col = is_zero ? col_cnt : (col_cnt + step);
                end
                calc_row = row_cnt;
            end

            3'b100: begin  // RIGHT
                if (cfg_wrap_en) begin
                    calc_col = (col_cnt + img_cols - (step % img_cols)) % img_cols;
                end else begin
                    is_zero  = (col_cnt < step);
                    calc_col = is_zero ? col_cnt : (col_cnt - step);
                end
                calc_row = row_cnt;
            end

            default: begin  // NONE (000) 及非法方向 (101-111)
                calc_row = row_cnt;
                calc_col = col_cnt;
                is_zero  = 1'b0;
            end
        endcase
    end

    // 读地址 = calc_row * IMG_COLS + calc_col
    assign read_addr = calc_row * img_cols + calc_col;
    assign zero_fill = is_zero;

endmodule

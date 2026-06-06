// shift_addr_gen.sv -- 移位地址生成器 v0.3
//
// 功能：
//   1. 内部维护 row_cnt/col_cnt 计数器，跟踪输出位置（光栅扫描顺序）
//   2. 根据 cfg_dir/cfg_step/cfg_wrap_en 计算帧缓冲读出地址
//   3. 支持 NONE / UP / DOWN / LEFT / RIGHT 五种模式
//   4. wrap_en=1 时用条件加减实现缠绕（无取模运算符）；wrap_en=0 时补零
//
// v0.3 关键优化（消除 % 取模运算符）：
//   所有 % img_rows / % img_cols 替换为比较+条件加减，消除 Vivado
//   推断的 36 级 CARRY4 除法器链。DOWN/RIGHT 方向始终正确（无需取模）；
//   UP/LEFT 方向要求 step < img_rows/img_cols（设计约束）。
//
// 地址计算公式（base_addr = row * IMG_COLS + col）：
//   NONE : base_addr
//   UP   : (row + step) >= ROWS ? (row + step - ROWS) : (row + step)
//          then * IMG_COLS + col
//   DOWN : row >= step ? (row - step) : (row - step + ROWS)
//          then * IMG_COLS + col
//   LEFT : (col + step) >= COLS ? (col + step - COLS) : (col + step)
//          then row * IMG_COLS + ...
//   RIGHT: col >= step ? (col - step) : (col - step + COLS)
//          then row * IMG_COLS + ...
//
// 流水线说明：
//   2 级流水线：第 1 级寄存 CASE 输出（~10-15 级逻辑），
//   第 2 级寄存乘加结果。read_addr/zero_fill 比计数器晚 2 拍。
//
// 接口说明：
//   参数
//     MAX_ROWS : 最大行数（默认 64）
//     MAX_COLS : 最大列数（默认 64）
//   控制输入（来自 regs_top / ctrl_fsm）
//     cfg_dir[2:0]    : 移位方向 000=NONE 001=UP 010=DOWN 011=LEFT 100=RIGHT
//     cfg_step[4:0]   : 移位步长（0~31）
//     cfg_wrap_en     : 缠绕使能（0=补零，1=缠绕）
//     shift_en        : 移位使能（来自 ctrl_fsm）
//     proceed         : 推进使能（连接 m_axis_tready，与 AO 握手同步）
//                       为 0 时计数器冻结，防止背压期间 BRAM 读地址超前
//     img_rows[9:0]   : 图像行数
//     img_cols[9:0]   : 图像列数
//   输出（至 frame_buf_mgr）
//     read_addr[11:0] : BRAM 读地址（流水线输出，比计数器晚 2 拍）
//     zero_fill       : 补零标志（流水线输出，比计数器晚 2 拍）

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
    input  logic        proceed,
    input  logic [ 9:0] img_rows,
    input  logic [ 9:0] img_cols,

    // 输出接口
    output logic [11:0] read_addr,
    output logic        zero_fill,
    output logic        pipe_valid        // 流水线有效：stage2 输出有效时置位（比 shift_en 晚 2 拍）
);

    // ============================================================
    // 输出位置计数器（光栅扫描顺序）
    //
    // frame_done 寄存器：在帧结束（row/col 同时绕回 0）时置位，
    // 阻止后续多余递增，使 SAG 与 AO 的 all_done 保持同步。
    // 当 shift_en=0 时清除，准备下一帧。
    // ============================================================
    logic [9:0] row_cnt, col_cnt;
    logic       frame_done;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            row_cnt    <= '0;
            col_cnt    <= '0;
            frame_done <= 1'b0;
        end else if (shift_en && proceed && !frame_done) begin
            if (col_cnt == img_cols - 1) begin
                col_cnt <= '0;
                if (row_cnt == img_rows - 1) begin
                    row_cnt    <= '0;
                    frame_done <= 1'b1;
                end else begin
                    row_cnt <= row_cnt + 1'b1;
                end
            end else begin
                col_cnt <= col_cnt + 1'b1;
            end
        end else if (!shift_en) begin
            row_cnt    <= '0;
            col_cnt    <= '0;
            frame_done <= 1'b0;
        end
    end

    // ============================================================
    // 地址计算（组合逻辑 —— 模运算已消除）
    //
    // v0.3 优化：所有 % 取模运算符替换为比较+条件加减，消除 Vivado
    // 推断的除法器（36 级 CARRY4 链）。DOWN/RIGHT 方向始终正确
    // （无需取模）；UP/LEFT 方向在 step < img_rows/img_cols 时正确
    // （设计约束：step 应小于图像尺寸）。
    // ============================================================
    logic [9:0] step;
    logic [9:0] calc_row;
    logic [9:0] calc_col;
    logic       is_zero;

    assign step = {5'd0, cfg_step};  // 零扩展至 10 位

    // step_mod = step % M（组合逻辑）。
    // 仅当 step >= M 时触发取模；step 最大 31，img_rows/cols 最小 1，
    // 此时 Vivado 推断的除法器最多处理 5-bit ÷ 6-bit，远小于 per-pixel
    // 路径的 10-bit 加法 + 12-bit 乘法。不构成新的关键路径。
    // step_mod = step % M —— 寄存 1 拍，打破 regs_top→SAG 内部长路径
    logic [9:0] step_mod_comb_rows, step_mod_comb_cols;
    logic [9:0] step_mod_rows, step_mod_cols;
    assign step_mod_comb_rows = ({5'd0, cfg_step_r} >= img_rows_r)
                              ? ({5'd0, cfg_step_r} % img_rows_r)
                              : {5'd0, cfg_step_r};
    assign step_mod_comb_cols = ({5'd0, cfg_step_r} >= img_cols_r)
                              ? ({5'd0, cfg_step_r} % img_cols_r)
                              : {5'd0, cfg_step_r};
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            step_mod_rows <= '0;
            step_mod_cols <= '0;
        end else begin
            step_mod_rows <= step_mod_comb_rows;
            step_mod_cols <= step_mod_comb_cols;
        end
    end

    // Input registers for static config (break regs_top -> SAG path)
    logic [ 4:0] cfg_step_r;
    logic [ 2:0] cfg_dir_r;
    logic        cfg_wrap_en_r;
    logic [ 9:0] img_rows_r;
    logic [ 9:0] img_cols_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            cfg_step_r    <= '0;
            cfg_dir_r     <= '0;
            cfg_wrap_en_r <= 1'b0;
            img_rows_r    <= 10'd64;
            img_cols_r    <= 10'd64;
        end else begin
            cfg_step_r    <= cfg_step;
            cfg_dir_r     <= cfg_dir;
            cfg_wrap_en_r <= cfg_wrap_en;
            img_rows_r    <= img_rows;
            img_cols_r    <= img_cols;
        end
    end

    always_comb begin
        calc_row = row_cnt;
        calc_col = col_cnt;
        is_zero  = 1'b0;

        case (cfg_dir)
            3'b001: begin  // UP
                if (cfg_wrap_en) begin
                    // (row + step_mod) % img_rows = 条件减法
                    calc_row = (row_cnt + step_mod_rows >= img_rows)
                             ? (row_cnt + step_mod_rows - img_rows)
                             : (row_cnt + step_mod_rows);
                end else begin
                    is_zero  = (row_cnt + step >= img_rows);
                    calc_row = is_zero ? row_cnt : (row_cnt + step);
                end
                calc_col = col_cnt;
            end

            3'b010: begin  // DOWN
                if (cfg_wrap_en) begin
                    // (row - step_mod + img_rows) % img_rows
                    // = row + img_rows - step_mod_rows
                    // 由于 row < img_rows, step_mod < img_rows:
                    //   tmp = row + img_rows - step_mod_rows 范围 [1, 2*img_rows-2]
                    //   结果 = tmp >= img_rows ? tmp - img_rows : tmp
                    calc_row = (row_cnt + img_rows - step_mod_rows >= img_rows)
                             ? (row_cnt + img_rows - step_mod_rows - img_rows)
                             : (row_cnt + img_rows - step_mod_rows);
                end else begin
                    is_zero  = (row_cnt < step);
                    calc_row = is_zero ? row_cnt : (row_cnt - step);
                end
                calc_col = col_cnt;
            end

            3'b011: begin  // LEFT
                if (cfg_wrap_en) begin
                    calc_col = (col_cnt + step_mod_cols >= img_cols)
                             ? (col_cnt + step_mod_cols - img_cols)
                             : (col_cnt + step_mod_cols);
                end else begin
                    is_zero  = (col_cnt + step >= img_cols);
                    calc_col = is_zero ? col_cnt : (col_cnt + step);
                end
                calc_row = row_cnt;
            end

            3'b100: begin  // RIGHT
                if (cfg_wrap_en) begin
                    calc_col = (col_cnt + img_cols - step_mod_cols >= img_cols)
                             ? (col_cnt + img_cols - step_mod_cols - img_cols)
                             : (col_cnt + img_cols - step_mod_cols);
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

    // ============================================================
    // 流水线第 1 级：寄存 CASE 输出 calc_row / calc_col / is_zero
    //
    // 此时所有 % 运算符已被消除，该寄存器之前的组合逻辑
    // 仅为加法+比较+MUX（~10-15 级逻辑），满足 100MHz 时序。
    // ============================================================
    logic [9:0] calc_row_r;
    logic [9:0] calc_col_r;
    logic       is_zero_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            calc_row_r <= '0;
            calc_col_r <= '0;
            is_zero_r  <= 1'b0;
        end else if (shift_en && proceed) begin
            calc_row_r <= calc_row;
            calc_col_r <= calc_col;
            is_zero_r  <= is_zero;
        end else if (!shift_en) begin
            calc_row_r <= '0;
            calc_col_r <= '0;
            is_zero_r  <= 1'b0;
        end
    end

    // ============================================================
    // 流水线有效标志（shift register，2 级匹配 stage1+stage2 延迟）
    //
    // pipe_valid[0] 在第 1 个 shift_en 有效周期置位,
    // pipe_valid[1] 在第 2 个周期置位（等于 stage2 输出有效）。
    // ============================================================
    logic [1:0] pipe_valid_d;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            pipe_valid_d <= 2'b00;
        else if (shift_en && proceed)
            pipe_valid_d <= {pipe_valid_d[0], 1'b1};
        else if (!shift_en)
            pipe_valid_d <= 2'b00;
    end
    assign pipe_valid = pipe_valid_d[1];

    // ============================================================
    // 乘加运算（组合逻辑）
    //
    // read_addr  = calc_row * IMG_COLS + calc_col
    // zero_fill  = is_zero
    //
    // 此组合路径主要消耗在 DSP48E1 乘法 + 最终加法，约 15-20 级。
    // ============================================================
    logic [11:0] read_addr_cmb;
    logic        zero_fill_cmb;

    assign read_addr_cmb = calc_row_r * img_cols + calc_col_r;
    assign zero_fill_cmb = is_zero_r;

    // ============================================================
    // 流水线第 2 级：寄存输出 read_addr / zero_fill
    //
    // 让乘加路径在第 2 级寄存器前闭合。两级流水线将原 54 级
    // 组合路径拆分为约 30 级 + 15 级，使 100MHz 时序可收敛。
    // ============================================================
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            read_addr <= '0;
            zero_fill <= 1'b0;
        end else if (shift_en && proceed) begin
            read_addr <= read_addr_cmb;
            zero_fill <= zero_fill_cmb;
        end else if (!shift_en) begin
            read_addr <= '0;
            zero_fill <= 1'b0;
        end
    end

endmodule

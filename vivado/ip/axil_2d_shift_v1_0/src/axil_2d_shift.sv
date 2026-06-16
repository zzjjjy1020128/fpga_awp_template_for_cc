// axil_2d_shift.sv -- AXI-Lite 2D Shift 顶层模块
//
// 功能：
//   集成全部 7 个子模块实现 AXI-Lite 控制的 2D 移位器。
//   支持 UP / DOWN / LEFT / RIGHT 四方向移位，补零或缠绕模式。
//
// 子模块实例：
//   - axil_slave_if   : AXI4-Lite Slave 总线接口
//   - regs_top        : 寄存器文件（CTRL / STATUS / CFG / IMG_ROWS / IMG_COLS）
//   - ctrl_fsm        : 主控制器状态机（IDLE / CAPTURE / SHIFT / DONE）
//   - axis_input      : AXI4-Stream 输入接口（采集数据写入 BRAM）
//   - shift_addr_gen  : 移位地址生成器（按方向/步长计算输出地址）
//   - axis_output     : AXI4-Stream 输出接口（从 BRAM 读出并发送）
//   - frame_buf_mgr   : 帧缓冲控制器（双端口 BRAM 读写控制）
//
// 流水线对齐：
//   shift_addr_gen 内部有 2 级流水线（地址计算 + 乘加），因此 read_addr
//   和 zero_fill 输出比内部计数器晚 2 个时钟周期。
//   frame_buf_mgr 读数据有 1 周期延迟（read_data 在 read_addr 后的下一拍有效）。
//   总计：read_data 比 SAG 计数器晚 3 拍。
//   对齐策略：
//     - axis_output 的 shift_en 延迟 1 拍（dly[1]），使 AO
//     - zero_fill 经 1 级寄存器（zero_fill_d1）对齐 BRAM 的 1 拍延迟
//     这样 AO 的第一个捕获周期刚好对应 BRAM 的第一个有效数据。
//
// 参数：
//   DATA_WIDTH      - 数据位宽（默认 8）
//   MAX_ROWS        - 最大行数（默认 64）
//   MAX_COLS        - 最大列数（默认 64）
//   AXIL_ADDR_WIDTH - AXI-Lite 地址位宽（默认 32）
//   AXIL_DATA_WIDTH - AXI-Lite 数据位宽（默认 32）
//
// 顶层端口：
//   时钟/复位   : clk, rstn
//   AXI4-Lite   : s_axil_* (AW/W/B/AR/R 五通道)
//   AXI4-S Slave: s_axis_tdata/tvalid/tready/tlast/tuser
//   AXI4-S Master: m_axis_tdata/tvalid/tready/tlast/tuser

module axil_2d_shift #(
    parameter int DATA_WIDTH      = 8,
    parameter int MAX_ROWS        = 64,
    parameter int MAX_COLS        = 64,
    parameter int AXIL_ADDR_WIDTH = 32,
    parameter int AXIL_DATA_WIDTH = 32
) (
    // =======================
    // 时钟与复位
    // =======================
    input  wire                        clk,
    input  wire                        rstn,

    // =======================
    // AXI4-Lite Slave 接口
    // =======================
    // 写地址通道
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire                        s_axil_awvalid,
    output wire                        s_axil_awready,
    // 写数据通道
    input  wire [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  wire                        s_axil_wvalid,
    output wire                        s_axil_wready,
    // 写响应通道
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input  wire                        s_axil_bready,
    // 读地址通道
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire                        s_axil_arvalid,
    output wire                        s_axil_arready,
    // 读数据通道
    output wire [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input  wire                        s_axil_rready,

    // =======================
    // AXI4-Stream Slave (输入)
    // =======================
    input  wire [DATA_WIDTH-1:0]       s_axis_tdata,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    input  wire                        s_axis_tlast,
    input  wire                        s_axis_tuser,

    // =======================
    // AXI4-Stream Master (输出)
    // =======================
    output wire [DATA_WIDTH-1:0]       m_axis_tdata,
    output wire                        m_axis_tvalid,
    input  wire                        m_axis_tready,
    output wire                        m_axis_tlast,
    output wire                        m_axis_tuser,

    output wire [31:0]                 dbg_port
);

    // =======================
    // 局部参数
    // =======================
    // frame_buf_mgr 地址位宽，根据帧缓冲深度计算
    localparam ADDR_WIDTH = $clog2(MAX_ROWS * MAX_COLS);

    // =======================
    // 内部信号声明
    // =======================

    // axil_slave_if <-> regs_top
    logic [15:0]                       wr_strobe;
    logic [15:0]                       rd_strobe;
    logic [AXIL_DATA_WIDTH-1:0]        wdata;
    logic [AXIL_DATA_WIDTH/8-1:0]      wstrb;
    logic [AXIL_DATA_WIDTH-1:0]        rdata;

    // regs_top -> 各模块 (配置/控制/状态)
    logic                              ctrl_start;
    logic                              ctrl_sw_reset;
    logic [2:0]                        cfg_dir;
    logic [4:0]                        cfg_step;
    logic                              cfg_wrap_en;
    logic [9:0]                        img_rows;
    logic [9:0]                        img_cols;

    // ctrl_fsm -> regs_top (状态标志)
    logic                              status_idle;
    logic                              status_busy_capture;
    logic                              status_busy_shift;
    logic                              status_done;

    // ctrl_fsm <-> axis_input (采集阶段)
    logic                              capture_en;
    logic                              capture_done;

    // ctrl_fsm -> shift_addr_gen (移位阶段)
    logic                              shift_en;
    // shift_en -> axis_output (延迟 2 拍，等 SAG 流水线填满)
    logic [2:0]                        shift_en_dly;
    logic                              shift_en_ao;
    // axis_output -> ctrl_fsm
    logic                              shift_done;

    // axis_input -> frame_buf_mgr (端口 A: 写)
    logic [11:0]                       write_addr;
    logic [DATA_WIDTH-1:0]             write_data;
    logic                              write_en;

    // shift_addr_gen -> frame_buf_mgr (端口 B: 读地址)
    logic [11:0]                       read_addr;

    // shift_addr_gen -> [1-stage pipeline reg] -> axis_output
    logic                              zero_fill;
    logic                              zero_fill_d1;

    // frame_buf_mgr -> axis_output (端口 B: 读数据)
    logic [DATA_WIDTH-1:0]             read_data;

    // =======================
    // 子模块实例化
    // =======================

    // ------------------------------------------------------------------
    // 1. axil_slave_if: AXI4-Lite Slave 接口
    //    - 顶层 AXI-Lite 端口直连
    //    - 输出 wr_strobe / rd_strobe / wdata / wstrb 至 regs_top
    //    - 接收 rdata 来自 regs_top
    // ------------------------------------------------------------------
    axil_slave_if #(
        .AXIL_ADDR_WIDTH (AXIL_ADDR_WIDTH),
        .AXIL_DATA_WIDTH (AXIL_DATA_WIDTH)
    ) u_axil_slave_if (
        .clk              (clk),
        .rstn             (rstn),

        .s_axil_awaddr    (s_axil_awaddr),
        .s_axil_awvalid   (s_axil_awvalid),
        .s_axil_awready   (s_axil_awready),

        .s_axil_wdata     (s_axil_wdata),
        .s_axil_wstrb     (s_axil_wstrb),
        .s_axil_wvalid    (s_axil_wvalid),
        .s_axil_wready    (s_axil_wready),

        .s_axil_bresp     (s_axil_bresp),
        .s_axil_bvalid    (s_axil_bvalid),
        .s_axil_bready    (s_axil_bready),

        .s_axil_araddr    (s_axil_araddr),
        .s_axil_arvalid   (s_axil_arvalid),
        .s_axil_arready   (s_axil_arready),

        .s_axil_rdata     (s_axil_rdata),
        .s_axil_rresp     (s_axil_rresp),
        .s_axil_rvalid    (s_axil_rvalid),
        .s_axil_rready    (s_axil_rready),

        .wr_strobe        (wr_strobe),
        .rd_strobe        (rd_strobe),
        .wdata            (wdata),
        .wstrb            (wstrb),
        .rdata            (rdata)
    );

    // ------------------------------------------------------------------
    // 2. regs_top: 寄存器文件
    //    - 接收 axil_slave_if strobe 信号完成寄存器读写
    //    - 输出配置/控制信号至各功能模块
    //    - 接收状态信号从 ctrl_fsm
    // ------------------------------------------------------------------
    regs_top u_regs_top (
        .clk                (clk),
        .rstn               (rstn),

        .wr_strobe          (wr_strobe),
        .rd_strobe          (rd_strobe),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .rdata              (rdata),

        .ctrl_start         (ctrl_start),
        .ctrl_sw_reset      (ctrl_sw_reset),
        .cfg_dir            (cfg_dir),
        .cfg_step           (cfg_step),
        .cfg_wrap_en        (cfg_wrap_en),
        .img_rows           (img_rows),
        .img_cols           (img_cols),

        .status_idle        (status_idle),
        .status_busy_capture(status_busy_capture),
        .status_busy_shift  (status_busy_shift),
        .status_done        (status_done),
        .status_error       (1'b0)  // 保留，固定为 0
    );

    // ------------------------------------------------------------------
    // 3. ctrl_fsm: 主控制器状态机
    //    - 从 regs_top 接收启动/软复位
    //    - 向 axis_input 发送 capture_en
    //    - 向 shift_addr_gen / axis_output 发送 shift_en
    //    - 从 axis_input / axis_output 接收完成标志
    //    - 向 regs_top 发送状态信号
    // ------------------------------------------------------------------
    ctrl_fsm u_ctrl_fsm (
        .clk                (clk),
        .rstn               (rstn),

        .ctrl_start         (ctrl_start),
        .ctrl_sw_reset      (ctrl_sw_reset),
        .capture_done       (capture_done),
        .shift_done         (shift_done),

        .status_idle        (status_idle),
        .status_busy_capture(status_busy_capture),
        .status_busy_shift  (status_busy_shift),
        .status_done        (status_done),

        .capture_en         (capture_en),
        .shift_en           (shift_en)
    );

    // ------------------------------------------------------------------
    // 4. axis_input: AXI4-Stream 输入接口
    //    - 采集阶段接收 s_axis_* 数据
    //    - 生成 BRAM 写地址（光栅扫描顺序）
    //    - 帧收满后发出 capture_done 脉冲
    // ------------------------------------------------------------------
    axis_input #(
        .DATA_WIDTH (DATA_WIDTH),
        .MAX_ROWS   (MAX_ROWS),
        .MAX_COLS   (MAX_COLS)
    ) u_axis_input (
        .clk            (clk),
        .rstn           (rstn),

        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tuser   (s_axis_tuser),

        .capture_en     (capture_en),

        .img_rows       (img_rows),
        .img_cols       (img_cols),

        .write_addr     (write_addr),
        .write_data     (write_data),
        .write_en       (write_en),

        .capture_done   (capture_done)
    );

    // ------------------------------------------------------------------
    // 5. shift_addr_gen: 移位地址生成器
    //    - 根据 cfg_dir / cfg_step / cfg_wrap_en 计算输出读地址
    //    - 输出 zero_fill 标志（越界补零指示）
    //    - zero_fill 需经 1 级延迟后送 axis_output
    // ------------------------------------------------------------------
    shift_addr_gen #(
        .MAX_ROWS (MAX_ROWS),
        .MAX_COLS (MAX_COLS)
    ) u_shift_addr_gen (
        .clk            (clk),
        .rstn           (rstn),

        .cfg_dir        (cfg_dir),
        .cfg_step       (cfg_step),
        .cfg_wrap_en    (cfg_wrap_en),
        .shift_en       (shift_en),
        .proceed        (m_axis_tready),
        .img_rows       (img_rows),
        .img_cols       (img_cols),

        .read_addr      (read_addr),
        .zero_fill      (zero_fill)
    );

    // ------------------------------------------------------------------
    // 6. axis_output: AXI4-Stream 输出接口
    //    - 移位阶段从 BRAM 读取数据并输出
    //    - 生成 tuser / tlast 标志
    //    - 零填充模式下输出强制为 0
    //    - 最后一拍发出 shift_done 脉冲
    //
    //    注意：zero_fill 使用延迟 1 拍的版本 (zero_fill_d1) 以与
    //    frame_buf_mgr 的 1 周期读延迟对齐。
    // ------------------------------------------------------------------
    axis_output #(
        .DATA_WIDTH (DATA_WIDTH),
        .MAX_ROWS   (MAX_ROWS),
        .MAX_COLS   (MAX_COLS)
    ) u_axis_output (
        .clk            (clk),
        .rstn           (rstn),

        .shift_en       (shift_en_ao),    // 延迟 2 拍，等 SAG 流水线填满
        .img_rows       (img_rows),
        .img_cols       (img_cols),

        .read_data      (read_data),
        .zero_fill      (zero_fill_d1),   // 对齐后的 zero_fill
        .data_valid_i   (shift_en_ao),    // SAG 流水线填满，数据有效

        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tuser   (m_axis_tuser),

        .shift_done     (shift_done),

        .dbg_row_cnt    (ao_dbg_row_cnt),
        .dbg_col_cnt    (ao_dbg_col_cnt),
        .dbg_all_done   (ao_dbg_all_done),
        .dbg_data_valid (ao_dbg_data_valid)
    );

    // ------------------------------------------------------------------
    // 7. frame_buf_mgr: 帧缓冲控制器（双端口 BRAM）
    //    - 端口 A（写）：来自 axis_input 的写地址/数据/使能
    //    - 端口 B（读）：来自 shift_addr_gen 的读地址
    //                     读数据输出至 axis_output（1 周期延迟）
    // ------------------------------------------------------------------
    frame_buf_mgr #(
        .DATA_WIDTH (DATA_WIDTH),
        .MAX_ROWS   (MAX_ROWS),
        .MAX_COLS   (MAX_COLS),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_frame_buf_mgr (
        .clk            (clk),
        .rstn           (rstn),

        .write_addr     (write_addr),
        .write_data     (write_data),
        .write_en       (write_en),

        .read_addr      (read_addr),
        .read_data      (read_data)
    );

    // ==================================================================
    // axis_output shift_en 延迟流水线
    //
    // shift_addr_gen 内部有 2 级流水线，read_addr/zero_fill 输出比内部
    // 计数器晚 2 个时钟周期。axis_output 需要延迟启动 1 拍，使第一个
    // 捕获周期恰好在有效 read_data 到达时。
    //
    // 实现：3-bit shift register (dly[1] 输出，1 周期延迟)
    // ==================================================================
    always_ff @(posedge clk) begin
        if (!rstn)
            shift_en_dly <= '0;
        else
            shift_en_dly <= {shift_en_dly[1:0], shift_en};
    end
    assign shift_en_ao = shift_en_dly[1];

    // ==================================================================
    // ILA Cross-Trigger Debug Infrastructure
    // ==================================================================

    // FSM state encoding (from status bits)
    logic [1:0] fsm_state;
    assign fsm_state = status_idle         ? 2'd0 :
                       status_busy_capture ? 2'd1 :
                       status_busy_shift   ? 2'd2 :
                       status_done         ? 2'd3 : 2'd0;

    // Debug trigger hub
    logic        dbg_trig_pulse;
    logic [31:0] dbg_cycle_cnt;
    logic        dbg_anchor_status;
    logic        trig_in_ack_ctrl;
    logic        trig_in_ack_data;

    // Trigger select: default to fsm_start_edge (2'd0)
    // Can be overridden by AXI-Lite write to a reserved register
    logic [1:0]  trig_sel;
    assign trig_sel = 2'd0;  // TODO: make AXI-Lite configurable via regs_top

    dbg_trigger_hub u_dbg_hub (
        .clk               (clk),
        .rstn              (rstn),
        .trig_sel          (trig_sel),
        .fsm_idle          (status_idle),
        .fsm_capture       (status_busy_capture),
        .fsm_shift         (status_busy_shift),
        .axis_tvalid       (s_axis_tvalid),
        .axis_tready       (s_axis_tready),
        .capture_en        (capture_en),
        .dbg_trig_pulse    (dbg_trig_pulse),
        .dbg_cycle_cnt     (dbg_cycle_cnt),
        .dbg_anchor_status (dbg_anchor_status)
    );

    // RTL ILA: Control plane (FSM, AXI-Lite, config, status)
    ila_ctrl_cross u_ila_ctrl (
        .clk          (clk),
        .trig_in      (dbg_trig_pulse),
        .trig_in_ack  (trig_in_ack_ctrl),
        .probe0       (dbg_cycle_cnt),
        .probe1       ({19'd0, fsm_state, ctrl_start, ctrl_sw_reset, cfg_dir, cfg_step, cfg_wrap_en}),
        .probe2       ({22'd0, img_rows}),
        .probe3       ({22'd0, img_cols}),
        .probe4       ({27'd0, status_idle, status_busy_capture, status_busy_shift, status_done, capture_en}),
        .probe5       ({30'd0, shift_en, shift_done}),
        .probe6       ({ao_dbg_all_done, ao_dbg_data_valid, ao_dbg_row_cnt, ao_dbg_col_cnt, 10'd0}),
        .probe7       ({30'd0, dbg_anchor_status, dbg_trig_pulse})
    );

    // RTL ILA: Data path (AXIS in/out, BRAM writes)
    ila_data_cross u_ila_data (
        .clk          (clk),
        .trig_in      (dbg_trig_pulse),
        .trig_in_ack  (trig_in_ack_data),
        .probe0       (s_axis_tdata),
        .probe1       (s_axis_tvalid),
        .probe2       (s_axis_tready),
        .probe3       (s_axis_tlast),
        .probe4       (s_axis_tuser),
        .probe5       (m_axis_tdata),
        .probe6       (m_axis_tvalid),
        .probe7       (m_axis_tready),
        .probe8       (m_axis_tlast),
        .probe9       (m_axis_tuser),
        .probe10      (write_addr),
        .probe11      (write_data),
        .probe12      (write_en)
    );

    // ==================================================================
    // zero_fill 流水线对齐寄存器
    //
    // frame_buf_mgr 读数据有 1 周期延迟：read_data 在 read_addr 后的
    // 下一拍才有效。shift_addr_gen 的 zero_fill 与 read_addr 同步输出，
    // 因此需要延迟 1 拍后才能与 read_data 对齐。
    //
    // 注意：此 1 级延迟是 BRAM 读延迟的补偿，与 shift_en_ao 的 1 级
    // 延迟（SAG 内部流水线补偿）独立叠加。
    // ==================================================================
    always_ff @(posedge clk) begin
        if (!rstn)
            zero_fill_d1 <= 1'b0;
        else
            zero_fill_d1 <= zero_fill;
    end

    assign dbg_port = {ao_dbg_all_done, ao_dbg_data_valid, ao_dbg_row_cnt, ao_dbg_col_cnt, 10'd0};

endmodule : axil_2d_shift

//==============================================================================
// tb_l1b_control_path - L1b 控制通路闭环验证
//   axil_slave_if -> regs_top -> ctrl_fsm
//
// 验证目标:
//   AXI-Lite 配置写入 -> 寄存器锁存 -> ctrl_start 脉冲 -> ctrl_fsm
//   状态转换 -> capture_en/shift_en 控制时序 -> STATUS 反馈
//
// 验证要点:
//   1. AXI-Lite 配置写入: CFG/IMG_ROWS/IMG_COLS 正确锁存并可回读
//   2. CTRL.start 触发: start=1 -> ctrl_fsm IDLE->CAPTURE, capture_en=1
//   3. capture_done 响应: capture_done=1 -> CAPTURE->SHIFT, shift_en=1
//   4. shift_done 响应: shift_done=1 -> SHIFT->DONE->IDLE(自动), STATUS.done 锁存
//   5. SW_RESET 优先级: 任何状态下 sw_reset=1 -> IDLE
//   6. 配置稳定性: CAPTURE/SHIFT 期间寄存器值不被干扰
//   7. STATUS 互斥: idle/busy_capture/busy_shift/done 正确互斥
//   8. 连续 2 次 start: 第一次 done 后第二次 start 正确重走流程
//
// 时序约定 (AXI-Lite Write):
//   TB 在 #1 (1ns after posedge) 驱动 AW/W 信号
//   DUT 在下一 posedge 采样并执行写操作
//   wr_strobe 在写执行拍有效 (1 周期脉冲)
//   regs_top 在同一 posedge 锁存
//   ctrl_start 从 regs_top 组合输出
//   ctrl_fsm 次态逻辑在相邻 posedge 间组合计算
//   状态跳转在写执行拍的下一 posedge 发生
//
//   Capture -> Shift 转换:
//   TC 在 posedge 前设置 mock_capture_done=1
//   下一 posedge ctrl_fsm 从 CAPTURE 跳转到 SHIFT
//
//   Shift -> Done 转换:
//   类似方式设置 mock_shift_done=1
//
//   最后一拍完成后 TB 撤销 done 信号
//   ctrl_fsm 在 DONE 状态保持 1 周期后自动返回 IDLE
//==============================================================================

`timescale 1ns/1ps

module tb_l1b_control_path;

    // -------------------------------------------------------------------------
    // 参数
    // -------------------------------------------------------------------------
    localparam real CLK_PERIOD = 10.0;  // 100 MHz
    localparam int  AXIL_ADDR_WIDTH = 32;
    localparam int  AXIL_DATA_WIDTH = 32;

    // 寄存器地址
    localparam bit [31:0] ADDR_CTRL     = 32'h0000_0000;
    localparam bit [31:0] ADDR_STATUS   = 32'h0000_0004;
    localparam bit [31:0] ADDR_CFG      = 32'h0000_0008;
    localparam bit [31:0] ADDR_IMG_ROWS = 32'h0000_000C;
    localparam bit [31:0] ADDR_IMG_COLS = 32'h0000_0010;
    localparam bit [31:0] ADDR_RESERVED = 32'h0000_0014;

    // -------------------------------------------------------------------------
    // DUT 信号
    // -------------------------------------------------------------------------
    logic                        clk;
    logic                        rstn;

    // regs_top -> axil_slave_if 内部读数据通路
    wire [AXIL_DATA_WIDTH-1:0]   rdata_int;

    // AXI4-Lite Slave 接口 (连接到 axil_slave_if)
    logic [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr;
    logic                        s_axil_awvalid;
    logic                        s_axil_awready;
    logic [AXIL_DATA_WIDTH-1:0]  s_axil_wdata;
    logic [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb;
    logic                        s_axil_wvalid;
    logic                        s_axil_wready;
    logic [1:0]                  s_axil_bresp;
    logic                        s_axil_bvalid;
    logic                        s_axil_bready;
    logic [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr;
    logic                        s_axil_arvalid;
    logic                        s_axil_arready;
    logic [AXIL_DATA_WIDTH-1:0]  s_axil_rdata;
    logic [1:0]                  s_axil_rresp;
    logic                        s_axil_rvalid;
    logic                        s_axil_rready;

    // regs_top -> ctrl_fsm (内部控制信号)
    logic                        ctrl_start;
    logic                        ctrl_sw_reset;
    logic [2:0]                  cfg_dir;
    logic [4:0]                  cfg_step;
    logic                        cfg_wrap_en;
    logic [9:0]                  img_rows;
    logic [9:0]                  img_cols;

    // ctrl_fsm -> regs_top (状态标志)
    logic                        status_idle;
    logic                        status_busy_capture;
    logic                        status_busy_shift;
    logic                        status_done;

    // ctrl_fsm 使能输出
    logic                        capture_en;
    logic                        shift_en;

    // 模拟 capture_done / shift_done (来自 axis_input / axis_output)
    logic                        mock_capture_done;
    logic                        mock_shift_done;

    // 时钟周期计数器 (用于 DONE 自动 IDLE 检测)
    int                          cycle_count;

    // -------------------------------------------------------------------------
    // 统计
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;
    int test_id    = 0;

    // -------------------------------------------------------------------------
    // DUT 实例化
    // -------------------------------------------------------------------------
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
        .wr_strobe        (),
        .rd_strobe        (),
        .wdata            (),
        .wstrb            (),
        .rdata            (rdata_int)      // 来自 regs_top 的读数据
    );

    regs_top u_regs_top (
        .clk                (clk),
        .rstn               (rstn),
        .wr_strobe          (u_axil_slave_if.wr_strobe),
        .rd_strobe          (u_axil_slave_if.rd_strobe),
        .wdata              (u_axil_slave_if.wdata),
        .wstrb              (u_axil_slave_if.wstrb),
        .rdata              (rdata_int),    // 输出至 axil_slave_if
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
        .status_error       (1'b0)
    );

    ctrl_fsm u_ctrl_fsm (
        .clk                (clk),
        .rstn               (rstn),
        .ctrl_start         (ctrl_start),
        .ctrl_sw_reset      (ctrl_sw_reset),
        .capture_done       (mock_capture_done),
        .shift_done         (mock_shift_done),
        .status_idle        (status_idle),
        .status_busy_capture(status_busy_capture),
        .status_busy_shift  (status_busy_shift),
        .status_done        (status_done),
        .capture_en         (capture_en),
        .shift_en           (shift_en)
    );

    // -------------------------------------------------------------------------
    // 时钟生成
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // 周期计数器
    always_ff @(posedge clk) begin
        if (!rstn) cycle_count <= 0;
        else       cycle_count <= cycle_count + 1;
    end

    // -------------------------------------------------------------------------
    // 辅助任务
    // -------------------------------------------------------------------------

    // 等待 N 个时钟周期
    task wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    // 在 posedge 后延迟 #1 (类似 L1c TB 的驱动时序)
    task drive_delay();
        #1;
    endtask

    // 简单的 check 宏
    task check(input string desc, input logic cond);
        if (cond) begin
            pass_count++;
            $display("  PASS [%0d] %s", test_id, desc);
        end else begin
            fail_count++;
            $display("  FAIL [%0d] %s", test_id, desc);
        end
    endtask

    // -------------------------------------------------------------------------
    // AXI-Lite Master 任务
    // -------------------------------------------------------------------------

    // AXI-Lite 写事务: 驱动 addr/data/strb, 完成握手, 返回
    task axil_write(input [31:0] addr, input [31:0] data, input [3:0] strb);
        @(posedge clk);
        drive_delay();
        s_axil_awaddr  = addr;
        s_axil_awvalid = 1;
        s_axil_wdata   = data;
        s_axil_wstrb   = strb;
        s_axil_wvalid  = 1;
        s_axil_bready  = 1;
        wait(s_axil_awready && s_axil_wready);
        @(posedge clk);
        drive_delay();
        s_axil_awvalid = 0;
        s_axil_wvalid  = 0;
        wait(s_axil_bvalid);
        @(posedge clk);
        drive_delay();
        s_axil_bready  = 0;
    endtask

    // AXI-Lite 读事务: 驱动地址, 读取返回数据
    task axil_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        drive_delay();
        s_axil_araddr  = addr;
        s_axil_arvalid = 1;
        s_axil_rready  = 1;
        wait(s_axil_arready);
        @(posedge clk);
        drive_delay();
        s_axil_arvalid = 0;
        wait(s_axil_rvalid);
        data = s_axil_rdata;
        @(posedge clk);
        drive_delay();
        s_axil_rready  = 0;
    endtask

    // -------------------------------------------------------------------------
    // 高层操作任务
    // -------------------------------------------------------------------------

    // 配置帧参数: rows, cols, dir, step, wrap_en
    task config_frame(
        input int        rows,
        input int        cols,
        input int        dir,
        input int        step,
        input            wrap_en
    );
        reg [31:0] cfg_val;
        begin
            cfg_val = 32'h0;
            cfg_val[2:0] = dir[2:0];
            cfg_val[7:3] = step[4:0];
            cfg_val[8]   = wrap_en;
            axil_write(ADDR_IMG_ROWS, rows, 4'hF);
            axil_write(ADDR_IMG_COLS, cols, 4'hF);
            axil_write(ADDR_CFG, cfg_val, 4'hF);
        end
    endtask

    // 启动采集: 写 CTRL.start=1
    task start_capture();
        axil_write(ADDR_CTRL, 32'h0000_0001, 4'hF);
    endtask

    // 触发软复位: 写 CTRL.sw_reset=1
    task do_sw_reset();
        axil_write(ADDR_CTRL, 32'h0000_0002, 4'hF);
    endtask

    // 读取 STATUS 寄存器
    task read_status(output [31:0] status_val);
        axil_read(ADDR_STATUS, status_val);
    endtask

    // 模拟 capture 完成 (1 周期脉冲)
    task fire_capture_done();
        @(posedge clk);
        drive_delay();
        mock_capture_done = 1;
        @(posedge clk);
        drive_delay();
        mock_capture_done = 0;
    endtask

    // 模拟 shift 完成 (1 周期脉冲)
    task fire_shift_done();
        @(posedge clk);
        drive_delay();
        mock_shift_done = 1;
        @(posedge clk);
        drive_delay();
        mock_shift_done = 0;
    endtask

    // 重置 AXI-Lite 总线信号 (初始化时使用)
    task init_axil_signals();
        s_axil_awaddr  = 0;
        s_axil_awvalid = 0;
        s_axil_wdata   = 0;
        s_axil_wstrb   = 0;
        s_axil_wvalid  = 0;
        s_axil_bready  = 0;
        s_axil_araddr  = 0;
        s_axil_arvalid = 0;
        s_axil_rready  = 0;
    endtask

    // -------------------------------------------------------------------------
    // 仿真初始化
    // -------------------------------------------------------------------------
    initial begin
        $display("============================================================");
        $display("  tb_l1b_control_path - Control Path Integration Simulation");
        $display("  axil_slave_if -> regs_top -> ctrl_fsm");
        $display("============================================================");
        $display("");

        // 初始化
        rstn = 0;
        mock_capture_done = 0;
        mock_shift_done   = 0;
        init_axil_signals();
        wait_cycles(4);
        rstn = 1;
        @(posedge clk);
        drive_delay();

        // ==================================================================
        // TC01: 寄存器配置写入与回读
        // 验证: CFG, IMG_ROWS, IMG_COLS 写入后正确锁存并可回读
        // ==================================================================
        test_id = 1;
        $display("--- TC%0d: Register config write/read-back ---", test_id);
        begin
            reg [31:0] rd;

            // 写入 CFG: dir=UP(1), step=2, wrap=1
            config_frame(6, 4, 1, 2, 1);

            // 回读 IMG_ROWS
            axil_read(ADDR_IMG_ROWS, rd);
            check("IMG_ROWS == 6", rd == 6);
            // 回读 IMG_COLS
            axil_read(ADDR_IMG_COLS, rd);
            check("IMG_COLS == 4", rd == 4);
            // 回读 CFG
            axil_read(ADDR_CFG, rd);
            check("CFG.dir == UP(1)", rd[2:0] == 1);
            check("CFG.step == 2",    rd[7:3] == 2);
            check("CFG.wrap_en == 1", rd[8]   == 1);

            // 验证组合输出信号
            check("cfg_dir == 1 (UP)",   cfg_dir   == 3'b001);
            check("cfg_step == 2",       cfg_step  == 5'd2);
            check("cfg_wrap_en == 1",    cfg_wrap_en == 1);
            check("img_rows == 6",       img_rows  == 6);
            check("img_cols == 4",       img_cols  == 4);
        end

        // ==================================================================
        // TC02: CTRL.start 自清零与 ctrl_start 脉冲
        // 验证: 写 CTRL.start=1 后, ctrl_r[0] 自清零, ctrl_start 脉冲 1 周期
        // ==================================================================
        test_id = 2;
        $display("--- TC%0d: CTRL.start self-clear and ctrl_start pulse ---", test_id);
        begin
            reg [31:0] rd;

            // 先确保 IDLE 状态 (写 CFG 不会影响)
            config_frame(4, 4, 0, 0, 0);

            // 写 CTRL.start=1
            start_capture();

            // 读回 CTRL (地址 0x00), 应该为 0 (自清零)
            axil_read(ADDR_CTRL, rd);
            check("CTRL read-back == 0 (self-cleared)", rd == 0);

            // 验证 STATUS: 经过 start 后, FSM 应已在 CAPTURE
            // 但由于我们还没 fire capture_done, 应保持 busy_capture
            axil_read(ADDR_STATUS, rd);
            check("STATUS.busy_capture == 1 after start", rd[1] == 1);
            check("STATUS.idle == 0 (mutex)",             rd[0] == 0);

            // 验证 capture_en 使能输出
            check("capture_en == 1 in CAPTURE state", capture_en == 1);
            check("shift_en == 0 in CAPTURE state",   shift_en == 0);

            // 验证明细: ctrl_start 来自 regs_top
            check("ctrl_start (combo from regs_top) is now 0 (self-cleared)",
                  ctrl_start == 0);

            // 清理: 用 sw_reset 回到 IDLE 为后续测试准备
            do_sw_reset();
            wait_cycles(2);
            axil_read(ADDR_STATUS, rd);
            check("Back to IDLE after sw_reset", rd[0] == 1);
        end

        // ==================================================================
        // TC03: capture_done -> SHIFT 转换
        // 验证: capture_done 脉冲后 FSM 从 CAPTURE 跳转到 SHIFT
        // ==================================================================
        test_id = 3;
        $display("--- TC%0d: capture_done -> SHIFT transition ---", test_id);
        begin
            reg [31:0] rd;

            // 进入 CAPTURE
            config_frame(4, 4, 1, 1, 0);
            start_capture();
            wait_cycles(2);
            check("In CAPTURE before capture_done", capture_en == 1);

            // 触发 capture_done
            fire_capture_done();
            wait_cycles(1);  // 等待状态机跳转

            // 验证 SHIFT
            check("shift_en == 1 after capture_done",  shift_en == 1);
            check("capture_en == 0 after capture_done", capture_en == 0);

            axil_read(ADDR_STATUS, rd);
            check("STATUS.busy_shift == 1 after capture_done", rd[2] == 1);
            check("STATUS.busy_capture == 0",                  rd[1] == 0);

            // 清理
            do_sw_reset();
            wait_cycles(2);
        end

        // ==================================================================
        // TC04: shift_done -> DONE -> IDLE 自动转换
        // 验证: shift_done 后 FSM 进入 DONE, 1 周期后自动返回 IDLE
        //       STATUS.done 锁存
        // ==================================================================
        test_id = 4;
        $display("--- TC%0d: shift_done -> DONE -> IDLE auto-return ---", test_id);
        begin
            reg [31:0] rd;

            // 进入 CAPTURE -> SHIFT
            config_frame(4, 4, 0, 0, 0);
            start_capture();
            wait_cycles(2);
            fire_capture_done();
            wait_cycles(1);

            // 现在在 SHIFT
            check("In SHIFT before shift_done", shift_en == 1);

            // 触发 shift_done
            fire_shift_done();
            wait_cycles(1);  // 进入 DONE

            // 在 DONE 状态: shift_en=0, capture_en=0, status_done=1
            // 注意: DONE 只保持 1 周期, 所以我们只有 1 拍窗口来检查
            // 这里检查 DONE 的副作用: status_done 被 regs_top 锁存

            // 再等 1 周期让 FSM 自动返回 IDLE
            wait_cycles(2);

            // 验证最终状态: STATUS.done 仍锁存, idle=0 (因为 done 有效)
            axil_read(ADDR_STATUS, rd);
            check("STATUS.done latched == 1 after auto-return", rd[3] == 1);
            check("STATUS.idle == 0 (done latched)",            rd[0] == 0);
            check("idle and done not both 1 (mutex)",           !(rd[0] && rd[3]));

            // 但现在 ctrl_fsm 已经在 IDLE 状态
            check("capture_en == 0 (FSM in IDLE)", capture_en == 0);
            check("shift_en == 0 (FSM in IDLE)",   shift_en == 0);
        end

        // ==================================================================
        // TC05: 完整流程 + STATUS 互斥
        // 验证: IDLE->CAPTURE->SHIFT->DONE->IDLE 全过程
        //       STATUS 比特在各个阶段的互斥性
        // ==================================================================
        test_id = 5;
        $display("--- TC%0d: Full flow with STATUS mutual exclusivity ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 TC04 的 done_latched: 写 CTRL.start 会清除
            // 这里不做 start, 而是直接检查 IDLE
            axil_read(ADDR_STATUS, rd);
            $display("  [DBG] Pre-clear STATUS = 0x%08h", rd);

            // 清除 done: 写 start (done_clear 条件满足)
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            axil_read(ADDR_STATUS, rd);
            check("STATUS.idle == 1 after done clear", rd[0] == 1);

            // --- 阶段 1: IDLE ---
            check("capture_en == 0 in IDLE", capture_en == 0);
            check("shift_en == 0 in IDLE",   shift_en == 0);

            config_frame(4, 4, 1, 1, 0);

            // --- 阶段 2: start -> CAPTURE ---
            start_capture();
            wait_cycles(2);  // 等待 FSM 跳转到 CAPTURE

            axil_read(ADDR_STATUS, rd);
            check("STATUS.busy_capture == 1",           rd[1] == 1);
            check("STATUS.idle == 0 (mutex)",            rd[0] == 0);
            check("STATUS.busy_shift == 0 (not SHIFT)",  rd[2] == 0);
            check("STATUS.done == 0 (not done)",         rd[3] == 0);
            check("capture_en == 1 in CAPTURE", capture_en == 1);
            check("shift_en == 0 in CAPTURE",   shift_en == 0);

            // --- 阶段 3: capture_done -> SHIFT ---
            fire_capture_done();
            wait_cycles(2);  // 等待 FSM 跳转到 SHIFT

            axil_read(ADDR_STATUS, rd);
            check("STATUS.busy_shift == 1",              rd[2] == 1);
            check("STATUS.busy_capture == 0 (mutex)",     rd[1] == 0);
            check("STATUS.idle == 0 (mutex)",             rd[0] == 0);
            check("STATUS.done == 0 (not done yet)",      rd[3] == 0);
            check("shift_en == 1 in SHIFT",   shift_en == 1);
            check("capture_en == 0 in SHIFT", capture_en == 0);

            // --- 阶段 4: shift_done -> DONE ---
            fire_shift_done();
            wait_cycles(1);  // 进入 DONE

            // DONE 状态只保持 1 周期, 在这 1 周期内 status_done=1
            // capture_en=0, shift_en=0
            axil_read(ADDR_STATUS, rd);
            // DONE 状态中, status_done 有效, 被 regs_top 锁存
            check("STATUS.done == 1 in DONE",             rd[3] == 1);

            // --- 阶段 5: 自动返回 IDLE ---
            wait_cycles(2);  // 自动返回 IDLE

            axil_read(ADDR_STATUS, rd);
            check("STATUS.done latched == 1", rd[3] == 1);
            check("STATUS.idle == 0 (done latched)", rd[0] == 0);
            // idle 不会被置 1, 因为 done_latched 有效时 status_idle_eff 被强制为 0
            // 互斥性在 regs_top 的 status_idle_eff 逻辑中保证
            check("done and idle mutually exclusive in STATUS read",
                  (rd[3] && rd[0]) == 0);

            check("capture_en == 0 final", capture_en == 0);
            check("shift_en == 0 final",   shift_en == 0);

            // 验证 FSM 确实在 IDLE (status_idle 来自 ctrl_fsm)
            // 注意: status_idle (来自 ctrl_fsm) 此时应为 1
            // 但 status_read 中的 status_idle_eff 因 done_latched 而被强制为 0
            // 这是 regs_top 的互斥逻辑, 是正确的设计行为
        end

        // ==================================================================
        // TC06: 连续 2 次 start (背靠背帧)
        // 验证: 第一次 done 后, 清除 done_latched, 第二次 start 正确重走流程
        // ==================================================================
        test_id = 6;
        $display("--- TC%0d: Consecutive 2-start (back-to-back frames) ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 TC05 的 done_latched
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            axil_read(ADDR_STATUS, rd);
            check("Clean IDLE before 2-start test", rd[0] == 1);

            // ---------- 帧 1 ----------
            config_frame(6, 5, 2, 1, 1);  // DOWN wrap step=1

            start_capture();
            wait_cycles(2);
            check("FRAME1: In CAPTURE", capture_en == 1);

            fire_capture_done();
            wait_cycles(2);
            check("FRAME1: In SHIFT", shift_en == 1);

            fire_shift_done();
            wait_cycles(3);  // DONE -> IDLE auto
            // 此时帧 1 完成, STATUS.done 锁存

            axil_read(ADDR_STATUS, rd);
            check("FRAME1: done latched == 1", rd[3] == 1);

            // ---------- 帧 2 (不同配置) ----------
            config_frame(3, 7, 3, 2, 0);  // LEFT zero-fill step=2

            // start_capture 会清除 done_latched (因为写 CTRL.start)
            start_capture();
            wait_cycles(2);

            // 验证 done_latched 已被清除
            axil_read(ADDR_STATUS, rd);
            check("FRAME2: done cleared after start", rd[3] == 0);
            check("FRAME2: busy_capture == 1",         rd[1] == 1);
            check("FRAME2: capture_en == 1", capture_en == 1);
            check("FRAME2: shift_en == 0",   shift_en == 0);
            check("FRAME2: cfg_dir unchanged", cfg_dir == 3);

            fire_capture_done();
            wait_cycles(2);
            check("FRAME2: In SHIFT", shift_en == 1);

            fire_shift_done();
            wait_cycles(3);
            check("FRAME2: done latched == 1", u_regs_top.done_latched == 1);

            $display("  [INFO] Both frames completed successfully");
        end

        // ==================================================================
        // TC07: SW_RESET from CAPTURE
        // 验证: sw_reset=1 在 CAPTURE 状态下回到 IDLE
        // ==================================================================
        test_id = 7;
        $display("--- TC%0d: SW_RESET from CAPTURE ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            // 进入 CAPTURE
            config_frame(4, 4, 0, 0, 0);
            start_capture();
            wait_cycles(2);

            // 确认在 CAPTURE
            check("TC07: In CAPTURE before sw_reset", capture_en == 1);
            axil_read(ADDR_STATUS, rd);
            check("TC07: STATUS.busy_capture == 1", rd[1] == 1);

            // 触发 sw_reset
            do_sw_reset();
            wait_cycles(2);

            // 验证回到 IDLE
            check("TC07: capture_en == 0 after sw_reset", capture_en == 0);
            check("TC07: shift_en == 0 after sw_reset",   shift_en == 0);
            axil_read(ADDR_STATUS, rd);
            check("TC07: STATUS.idle == 1 after sw_reset", rd[0] == 1);
            check("TC07: STATUS.busy_capture == 0",        rd[1] == 0);
        end

        // ==================================================================
        // TC08: SW_RESET from SHIFT
        // 验证: sw_reset=1 在 SHIFT 状态下回到 IDLE
        // ==================================================================
        test_id = 8;
        $display("--- TC%0d: SW_RESET from SHIFT ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            // 进入 CAPTURE -> SHIFT
            config_frame(4, 4, 0, 0, 0);
            start_capture();
            wait_cycles(2);
            fire_capture_done();
            wait_cycles(2);

            // 确认在 SHIFT
            check("TC08: In SHIFT before sw_reset", shift_en == 1);
            axil_read(ADDR_STATUS, rd);
            check("TC08: STATUS.busy_shift == 1", rd[2] == 1);

            // 触发 sw_reset
            do_sw_reset();
            wait_cycles(2);

            // 验证回到 IDLE
            check("TC08: shift_en == 0 after sw_reset",   shift_en == 0);
            check("TC08: capture_en == 0 after sw_reset", capture_en == 0);
            axil_read(ADDR_STATUS, rd);
            check("TC08: STATUS.idle == 1 after sw_reset", rd[0] == 1);
            check("TC08: STATUS.busy_shift == 0",          rd[2] == 0);
        end

        // ==================================================================
        // TC09: SW_RESET from DONE
        // 验证: sw_reset=1 在 DONE 状态下回到 IDLE, 不影响 done_latched
        // ==================================================================
        test_id = 9;
        $display("--- TC%0d: SW_RESET from DONE ---", test_id);
        begin
            reg [31:0] rd;

            // 清除之前残留的 done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            // 进入 CAPTURE -> SHIFT -> DONE
            config_frame(4, 4, 0, 0, 0);
            start_capture();
            wait_cycles(2);
            fire_capture_done();
            wait_cycles(2);
            fire_shift_done();
            wait_cycles(1);  // 现在在 DONE

            // 触发 sw_reset
            do_sw_reset();
            wait_cycles(2);

            // 验证: FSM 回到 IDLE
            check("TC09: capture_en == 0", capture_en == 0);
            check("TC09: shift_en == 0",   shift_en == 0);

            // STATUS: done_latched 在 DONE 时已锁存
            // sw_reset 不会清除 done_latched (只有 CTRL.start 写会清除)
            axil_read(ADDR_STATUS, rd);
            check("TC09: STATUS.done still latched after sw_reset", rd[3] == 1);
        end

        // ==================================================================
        // TC10: SW_RESET priority over ctrl_start
        // 验证: 当 ctrl_sw_reset 和 ctrl_start 同时有效时, sw_reset 优先
        // ==================================================================
        test_id = 10;
        $display("--- TC%0d: SW_RESET priority over ctrl_start ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            axil_read(ADDR_STATUS, rd);
            check("TC10: IDLE before test", rd[0] == 1);

            // 写 CTRL 同时置 start=1 和 sw_reset=1 (bit[0] and bit[1])
            // 数据 = 0x0000_0003 (bit0=start, bit1=sw_reset)
            // 在 FSM 中, sw_reset 优先于 ctrl_start
            axil_write(ADDR_CTRL, 32'h0000_0003, 4'hF);
            wait_cycles(3);

            // 由于 sw_reset 优先, FSM 应保持在/回到 IDLE
            // 注: 在同一拍中, regs_top 的 ctrl_r[1:0] <= wdata[1:0] = 2'b11
            // ctrl_sw_reset=1 且 ctrl_start=1
            // FSM 逻辑: if (ctrl_sw_reset) next = IDLE
            check("TC10: IDLE after sw_reset+start (sw_reset wins)",
                  u_ctrl_fsm.state == u_ctrl_fsm.IDLE);
            check("TC10: capture_en == 0", capture_en == 0);

            // 验证后续单独的 start 仍正常工作
            config_frame(4, 4, 0, 0, 0);
            start_capture();
            wait_cycles(2);
            check("TC10: capture_en == 1 after subsequent start", capture_en == 1);

            // 清理
            do_sw_reset();
            wait_cycles(2);
        end

        // ==================================================================
        // TC11: 配置信号在 CAPTURE/SHIFT 期间的稳定性
        // 验证: 操作期间配置寄存器不被写入干扰 (或至少不影响当前操作)
        //       注意: 架构文档规定 "CTRL.start 为 1 期间, CFG/IMG_ROWS/IMG_COLS
        //       的写入行为未定义", 但应验证至少不引起崩溃
        // ==================================================================
        test_id = 11;
        $display("--- TC%0d: Register stability during operation ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            // 配置并进入 CAPTURE
            config_frame(6, 5, 1, 2, 0);  // UP zero-fill
            start_capture();
            wait_cycles(2);

            check("TC11: capture_en == 1 in CAPTURE", capture_en == 1);

            // 在 CAPTURE 期间写入 CFG (操作期间配置不可靠, 但不应引起崩溃)
            axil_write(ADDR_CFG, 32'h0000_0000, 4'hF);  // 改为 NONE

            // 验证 capture_en 仍有效
            check("TC11: capture_en still 1 after CFG write", capture_en == 1);

            // 继续流程
            fire_capture_done();
            wait_cycles(2);
            check("TC11: shift_en == 1 in SHIFT", shift_en == 1);

            // 在 SHIFT 期间写入 IMG_ROWS, IMG_COLS
            axil_write(ADDR_IMG_ROWS, 32'h0000_0002, 4'hF);
            axil_write(ADDR_IMG_COLS, 32'h0000_0002, 4'hF);

            // 验证 shift_en 仍有效
            check("TC11: shift_en still 1 after IMG write", shift_en == 1);

            fire_shift_done();
            wait_cycles(3);

            // 验证 done 锁存
            axil_read(ADDR_STATUS, rd);
            check("TC11: done latched after operation", rd[3] == 1);

            $display("  [INFO] Register stability verified: no crash during operation");
        end

        // ==================================================================
        // TC12: 保留地址和无效地址访问
        // 验证: 对 0x14~0x3C 的读写行为正确, 无效地址返回 SLVERR
        // ==================================================================
        test_id = 12;
        $display("--- TC%0d: Reserved and invalid address access ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);

            // 写 CFG 为已知值
            config_frame(4, 4, 1, 2, 1);

            // 读保留地址 0x14
            axil_read(ADDR_RESERVED, rd);
            check("TC12: Reserved 0x14 read == 0", rd == 0);
            check("TC12: Reserved 0x14 BRESP OKAY", s_axil_rresp == 2'b00);
            // 注意: 0x14 在 mapped 范围内 (offset=5 < 16), 所以返回 OKAY+0

            // 写保留地址 0x14 (应被忽略, CFG 不变)
            axil_write(ADDR_RESERVED, 32'hDEAD_BEEF, 4'hF);
            axil_read(ADDR_CFG, rd);
            check("TC12: CFG unchanged after reserved write",
                  rd[2:0] == 1 && rd[7:3] == 2 && rd[8] == 1);

            // 无效地址 0x40 (offset=16, 超出范围)
            axil_write(32'h0000_0040, 32'h1234_5678, 4'hF);
            // 应返回 SLVERR
            check("TC12: Invalid write BRESP == SLVERR", s_axil_bresp == 2'b10);

            // 读无效地址: 在事务中捕获 rresp
            @(posedge clk);
            drive_delay();
            s_axil_araddr  = 32'h0000_0040;
            s_axil_arvalid = 1;
            s_axil_rready  = 1;
            wait(s_axil_arready);
            @(posedge clk);
            drive_delay();
            s_axil_arvalid = 0;
            wait(s_axil_rvalid);
            // 在事务有效期内检查 rresp (此时 rstate==R_ACTIVE)
            check("TC12: Invalid read RRESP == SLVERR", s_axil_rresp == 2'b10);
            // 读取 rdata 完成事务
            rd = s_axil_rdata;
            @(posedge clk);
            drive_delay();
            s_axil_rready  = 0;
            check("TC12: Invalid read data == 0", rd == 0);
        end

        // ==================================================================
        // TC13: 全流程 3 次连续操作 (验证多次 start 无状态泄漏)
        // ==================================================================
        test_id = 13;
        $display("--- TC%0d: Three consecutive full flows ---", test_id);
        begin
            reg [31:0] rd;

            // 清除 previous done
            start_capture();
            wait_cycles(1);
            do_sw_reset();
            wait_cycles(2);
            axil_read(ADDR_STATUS, rd);
            check("TC13: IDLE before 3x flow", rd[0] == 1);

            // --- 帧 1: 4x4 NONE ---
            config_frame(4, 4, 0, 0, 0);
            start_capture();
            wait_cycles(2);
            check("F1: CAPTURE", capture_en == 1);
            fire_capture_done();
            wait_cycles(2);
            check("F1: SHIFT", shift_en == 1);
            fire_shift_done();
            wait_cycles(3);
            axil_read(ADDR_STATUS, rd);
            check("F1: done latched", rd[3] == 1);

            // --- 帧 2: 6x4 UP wrap step=2 ---
            config_frame(6, 4, 1, 2, 1);
            start_capture();  // 清除 done_latched
            wait_cycles(2);
            check("F2: CAPTURE", capture_en == 1);
            fire_capture_done();
            wait_cycles(2);
            check("F2: SHIFT", shift_en == 1);
            fire_shift_done();
            wait_cycles(3);
            axil_read(ADDR_STATUS, rd);
            check("F2: done latched", rd[3] == 1);

            // --- 帧 3: 1x5 LEFT step=1 ---
            config_frame(1, 5, 3, 1, 1);
            start_capture();
            wait_cycles(2);
            check("F3: CAPTURE", capture_en == 1);
            fire_capture_done();
            wait_cycles(2);
            check("F3: SHIFT", shift_en == 1);
            fire_shift_done();
            wait_cycles(3);
            axil_read(ADDR_STATUS, rd);
            check("F3: done latched", rd[3] == 1);

            $display("  [INFO] 3 consecutive flows completed successfully");
        end

        // ==================================================================
        // 最终摘要
        // ==================================================================
        $display("");
        $display("============================================================");
        $display("  Simulation Summary");
        $display("============================================================");
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);
        $display("  Total : %0d", pass_count + fail_count);
        $display("------------------------------------------------------------");
        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED");
        end else begin
            $display("  SOME TESTS FAILED  <<<");
        end
        $display("============================================================");

        #100;
        $finish;
    end

    // -------------------------------------------------------------------------
    // VCD Dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_l1b_control_path.vcd");
        $dumpvars(0, tb_l1b_control_path);
    end

    // -------------------------------------------------------------------------
    // Timeout
    // -------------------------------------------------------------------------
    initial begin
        #5000000;  // 5 ms
        $display("[TIMEOUT] Simulation exceeded 5 ms without finishing.");
        $display("  Passed: %0d, Failed: %0d", pass_count, fail_count);
        $finish;
    end

endmodule

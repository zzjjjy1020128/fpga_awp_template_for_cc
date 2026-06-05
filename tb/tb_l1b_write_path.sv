//==============================================================================
// tb_l1b_write_path - L1b 集成 testbench: 写数据通路
//   axis_input -> frame_buf_mgr (port A)
//
// 验证功能:
//   1. AXI-Stream 输入握手 (tvalid/tready) 正确传递到 frame_buf_mgr 写端口
//   2. Raster-scan 写地址序列（行主序）与 axis_input 行列计数器一致
//   3. 帧边界 (tlast/tuser) 正确触发写使能复位
//   4. 连续多帧（>=3 帧）BRAM 数据一致性验证
//   5. Backpressure (tvalid=0 间隙) — 数据不丢失
//   6. capture_en 撤销/恢复 — 数据完整性
//   7. sw_reset (rstn) 在帧中途的行为
//   8. 边界情况: 1x1, 1xN, Nx1
//   9. 随机数据 + 大尺寸帧，全 BRAM 回读验证
//
// 时序约定:
//   - write_addr/write_en/write_data 均为 axis_input 的组合逻辑输出
//   - frame_buf_mgr 在 posedge clk 上 write_en=1 时写入 bram[write_addr] <= write_data
//   - frame_buf_mgr read_data 为寄存器输出（1 周期读延迟）
//   - 验证 read_data 在 read_addr 改变后 1 周期到达
//==============================================================================

`timescale 1ns/1ps

module tb_l1b_write_path;

    // -------------------------------------------------------------------------
    // 参数
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 8;
    localparam MAX_ROWS   = 64;
    localparam MAX_COLS   = 64;
    localparam ADDR_WIDTH = 12;            // $clog2(64*64)
    localparam real CLK_PERIOD = 10.0;     // 100 MHz

    // -------------------------------------------------------------------------
    // DUT 信号
    // -------------------------------------------------------------------------
    logic                    clk;
    logic                    rstn;

    // axis_input 激励侧
    logic [DATA_WIDTH-1:0]   s_axis_tdata;
    logic                    s_axis_tvalid;
    logic                    s_axis_tready;
    logic                    s_axis_tlast;
    logic                    s_axis_tuser;
    logic                    capture_en;
    logic [9:0]              img_rows;
    logic [9:0]              img_cols;

    // 内部连线: axis_input -> frame_buf_mgr
    logic [ADDR_WIDTH-1:0]   write_addr;
    logic [DATA_WIDTH-1:0]   write_data;
    logic                    write_en;
    logic                    capture_done;

    // frame_buf_mgr 端口 B (读回验证)
    logic [ADDR_WIDTH-1:0]   read_addr;
    logic [DATA_WIDTH-1:0]   read_data;

    // 在 posedge 采样组合逻辑/脉冲输出
    logic                    sample_write_en;
    logic                    sample_capture_done;

    // -------------------------------------------------------------------------
    // DUT 实例化
    // -------------------------------------------------------------------------
    axis_input #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_ROWS  (MAX_ROWS),
        .MAX_COLS  (MAX_COLS)
    ) u_axis_input (
        .clk           (clk),
        .rstn          (rstn),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tready (s_axis_tready),
        .s_axis_tlast  (s_axis_tlast),
        .s_axis_tuser  (s_axis_tuser),
        .capture_en    (capture_en),
        .img_rows      (img_rows),
        .img_cols      (img_cols),
        .write_addr    (write_addr),
        .write_data    (write_data),
        .write_en      (write_en),
        .capture_done  (capture_done)
    );

    frame_buf_mgr #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_ROWS  (MAX_ROWS),
        .MAX_COLS  (MAX_COLS)
    ) u_frame_buf_mgr (
        .clk        (clk),
        .rstn       (rstn),
        .write_addr (write_addr),
        .write_data (write_data),
        .write_en   (write_en),
        .read_addr  (read_addr),
        .read_data  (read_data)
    );

    // -------------------------------------------------------------------------
    // 在每个 posedge 采样组合逻辑 / 脉宽为 1 周期的输出
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        sample_write_en     <= write_en;
        sample_capture_done <= capture_done;
    end

    // -------------------------------------------------------------------------
    // 时钟生成
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // 测试基础架构
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;
    int test_id    = 0;

    task check(input string desc, input logic cond);
        if (cond) begin
            pass_count++;
            $display("  PASS [%0d] %s", test_id, desc);
        end else begin
            fail_count++;
            $display("  FAIL [%0d] %s", test_id, desc);
        end
    endtask

    task wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    task settle();
        #1;
    endtask

    // -------------------------------------------------------------------------
    // 激励辅助函数
    // -------------------------------------------------------------------------

    // 复位 DUT
    task reset_dut();
        rstn = 0;
        s_axis_tdata  = '0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        s_axis_tuser  = 0;
        capture_en    = 0;
        img_rows      = 4;
        img_cols      = 4;
        read_addr     = '0;
        wait_cycles(4);
        rstn = 1;
        @(posedge clk);
        settle();
    endtask

    // 驱动单个 AXI-Stream beat（在 @posedge 前调用）
    task send_beat(
        input [DATA_WIDTH-1:0] data,
        input logic            last,
        input logic            user
    );
        s_axis_tdata  = data;
        s_axis_tvalid = 1;
        s_axis_tlast  = last;
        s_axis_tuser  = user;
    endtask

    // 撤销 tvalid
    task idle_beat();
        s_axis_tdata  = '0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        s_axis_tuser  = 0;
    endtask

    // 通过端口 B 从 BRAM 读回一个字
    task read_bram(input logic [ADDR_WIDTH-1:0] addr,
                   output logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        read_addr = addr;
        @(posedge clk);
        settle();
        data = read_data;
        read_addr = '0;
    endtask

    // 连续读回一组地址并与期望值比较
    task verify_bram_range(
        input int          start_addr,
        input int          count,
        input logic [DATA_WIDTH-1:0] expected_base,
        input int          stride,
        output int         err_cnt
    );
        logic [DATA_WIDTH-1:0] rd;
        err_cnt = 0;
        for (int i = 0; i < count; i++) begin
            read_bram(start_addr + i, rd);
            if (rd !== (expected_base + i * stride)) begin
                err_cnt++;
                if (err_cnt <= 3) begin
                    $display("  FAIL [%0d] bram[%0d] = %0d (expected %0d)",
                             test_id, start_addr + i, rd, expected_base + i * stride);
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 主测试序列
    // -------------------------------------------------------------------------
    initial begin
        $display("============================================================");
        $display("  tb_l1b_write_path - Write Path Integration Simulation");
        $display("  axis_input -> frame_buf_mgr (port A)");
        $display("============================================================");
        $display("");

        reset_dut();

        // =====================================================================
        // TC01: 基础 4x4 采集 —— 写入后回读全部 16 个位置
        // 验证: AXI-Stream 握手正确传递到 frame_buf_mgr 写端口
        // =====================================================================
        test_id = 1;
        $display("--- TC%0d: Basic 4x4 capture and read-back ---", test_id);
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            capture_en = 1;
            img_rows   = 4;
            img_cols   = 4;
            @(posedge clk);
            settle();

            check("initial write_addr == 0", write_addr == 0);

            // 按行主序写入: addr(i) 得到 data(i+1)
            for (int i = 0; i < 16; i++) begin
                check($sformatf("beat %0d: write_addr == %0d before transfer",
                       i, i), write_addr == i);
                send_beat(i + 1, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();

            // 检查 capture_done
            @(posedge clk);
            settle();
            check("capture_done asserted after frame", sample_capture_done == 1);
            check("write_addr == 0 after frame done", write_addr == 0);
            @(posedge clk);
            settle();
            check("capture_done self-cleared", sample_capture_done == 0);

            // 回读全部 16 个位置并验证
            verify_bram_range(0, 16, 8'd1, 1, errs);
            check($sformatf("TC01: BRAM read-back errs=%0d/16", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC02: 多帧（3 帧）—— 验证数据覆盖
        //   帧 1: 3x4, data = addr+1
        //   帧 2: 3x4, data = addr+1 + 64（不同数据）
        //   帧 3: 3x4, data = addr+1 + 128（不同数据）
        //   回读确认只有帧 3 的数据存在
        // =====================================================================
        test_id = 2;
        $display("--- TC%0d: Multi-frame (3 frames) data overwrite ---", test_id);
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            // 帧 1: data = addr+1
            capture_en = 1;
            img_rows   = 3;
            img_cols   = 4;
            @(posedge clk);
            settle();

            for (int i = 0; i < 12; i++) begin
                send_beat(i + 1, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();
            @(posedge clk);
            settle();
            check("FRAME1: capture_done asserted", sample_capture_done == 1);

            // 帧 2: data = addr+1 + 64
            capture_en = 1;
            @(posedge clk);
            settle();

            for (int i = 0; i < 12; i++) begin
                send_beat(i + 1 + 64, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();
            @(posedge clk);
            settle();
            check("FRAME2: capture_done asserted", sample_capture_done == 1);

            // 帧 3: data = addr+1 + 128
            capture_en = 1;
            @(posedge clk);
            settle();

            for (int i = 0; i < 12; i++) begin
                send_beat(i + 1 + 128, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();
            @(posedge clk);
            settle();
            check("FRAME3: capture_done asserted", sample_capture_done == 1);

            // 回读 —— 应该只有帧 3 的数据
            verify_bram_range(0, 12, 8'd1 + 128, 1, errs);
            check($sformatf("TC02: multi-frame overwrite errs=%0d/12", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC03: Backpressure —— tvalid 间隙中帧
        //   发送 4x4 帧但在 beats 3, 8, 12 后插入 3 周期 tvalid=0 间隙
        //   验证全部数据正确写入 BRAM
        // =====================================================================
        test_id = 3;
        $display("--- TC%0d: Backpressure via tvalid gaps ---", test_id);
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            capture_en = 1;
            img_rows   = 4;
            img_cols   = 4;
            @(posedge clk);
            settle();

            check("TC03: initial write_addr == 0", write_addr == 0);

            for (int i = 0; i < 16; i++) begin
                send_beat(i + 1, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();

                // 在特定 beat 后插入间隙
                if (i == 3 || i == 8 || i == 12) begin
                    idle_beat();
                    wait_cycles(3);
                end
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC03: capture_done asserted after backpressure",
                  sample_capture_done == 1);
            @(posedge clk);
            settle();
            check("TC03: capture_done self-cleared", sample_capture_done == 0);

            // 回读全部 16 个 —— 验证无数据丢失
            verify_bram_range(0, 16, 8'd1, 1, errs);
            check($sformatf("TC03: backpressure errs=%0d/16", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC04: capture_en 中间撤销/恢复（系统级 backpressure）
        //   撤销 capture_en 5 周期，然后恢复并完成帧
        //   验证无数据丢失或损坏
        // =====================================================================
        test_id = 4;
        $display("--- TC%0d: capture_en toggle mid-frame ---", test_id);
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            capture_en = 1;
            img_rows   = 4;
            img_cols   = 4;
            @(posedge clk);
            settle();

            // 发送 5 个 beats
            for (int i = 0; i < 5; i++) begin
                send_beat(i + 1, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();
            end
            check("after 5 beats: write_addr == 5", write_addr == 5);

            // 撤销 capture_en —— axis_input 冻结
            capture_en = 0;
            idle_beat();
            @(posedge clk);
            settle();
            check("tready=0 after capture_en=0", s_axis_tready == 0);
            check("write_en=0 when paused", sample_write_en == 0);

            // 保持暂停 5 周期
            wait_cycles(5);

            // 恢复 capture_en
            capture_en = 1;
            @(posedge clk);
            settle();

            // 发送剩余 11 个 beats (5..15)
            for (int i = 5; i < 16; i++) begin
                send_beat(i + 1, (i % 4 == 3), 0);
                @(posedge clk);
                settle();
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC04: capture_done after resume", sample_capture_done == 1);

            // 回读全部 —— 验证无数据丢失或损坏
            verify_bram_range(0, 16, 8'd1, 1, errs);
            check($sformatf("TC04: capture_en toggle errs=%0d/16", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC05: rstn 在帧中途（仿真 sw_reset）
        //   启动采集、发送 6 个 beats、断言 rstn、释放、新采集
        //   验证: BRAM 内容在复位时被保留，新采集正确覆盖
        // =====================================================================
        test_id = 5;
        $display("--- TC%0d: rstn mid-frame ---", test_id);
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            // 步骤 1: 正常采集写入 4x4 帧的一部分
            capture_en = 1;
            img_rows   = 4;
            img_cols   = 4;
            @(posedge clk);
            settle();

            // 发送 6 个 beats —— 写入地址 0..5 数据 1..6
            for (int i = 0; i < 6; i++) begin
                send_beat(i + 1, (i % 4 == 3), (i == 0));
                @(posedge clk);
                settle();
            end

            // 断言复位
            rstn = 0;
            idle_beat();
            capture_en = 0;
            wait_cycles(4);
            @(posedge clk);
            settle();

            check("tready=0 during reset", s_axis_tready == 0);

            // 释放复位
            rstn = 1;
            @(posedge clk);
            settle();

            // 步骤 2: 新采集，不同帧大小和数据
            capture_en = 1;
            img_rows   = 2;
            img_cols   = 3;
            @(posedge clk);
            settle();

            check("after reset: write_addr == 0", write_addr == 0);

            for (int i = 0; i < 6; i++) begin
                send_beat(100 + i, (i % 3 == 2), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC05: capture_done after reset+new capture",
                  sample_capture_done == 1);

            // 步骤 3: 验证地址 0..5 有新数据
            verify_bram_range(0, 6, 8'd100, 1, errs);
            check($sformatf("TC05: reset+new data errs=%0d/6 (addrs 0..5)", errs),
                  errs == 0);

            // 地址 6..15 应保留 TC04 的数据（BRAM 在复位时未被清零）
            // 这些地址在 TC04 中写入了 7..16
            verify_bram_range(6, 10, 8'd7, 1, errs);
            check($sformatf("TC05: preserved data errs=%0d/10 (addrs 6..15)", errs),
                  errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC06: 边界情况 —— 1x1, 1x5, 5x1
        // =====================================================================
        test_id = 6;
        $display("--- TC%0d: Edge cases (1x1, 1x5, 5x1) ---", test_id);

        // 子测试 A: 1x1 单像素
        $display("  Subtest A: 1x1 single pixel");
        begin
            logic [DATA_WIDTH-1:0] rd;

            capture_en = 1;
            img_rows   = 1;
            img_cols   = 1;
            @(posedge clk);
            settle();

            send_beat(8'hAB, 1, 1);
            @(posedge clk);
            settle();
            idle_beat();

            @(posedge clk);
            settle();
            check("TC06-A: capture_done after 1x1", sample_capture_done == 1);

            read_bram(0, rd);
            check("TC06-A: bram[0] == 0xAB", rd == 8'hAB);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // 子测试 B: 1x5 单行
        $display("  Subtest B: 1x5 single row");
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            capture_en = 1;
            img_rows   = 1;
            img_cols   = 5;
            @(posedge clk);
            settle();

            for (int i = 0; i < 5; i++) begin
                send_beat(10 + i, (i == 4), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC06-B: capture_done after 1x5", sample_capture_done == 1);

            verify_bram_range(0, 5, 8'd10, 1, errs);
            check($sformatf("TC06-B: single row errs=%0d/5", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // 子测试 C: 5x1 单列
        $display("  Subtest C: 5x1 single column");
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;

            capture_en = 1;
            img_rows   = 5;
            img_cols   = 1;
            @(posedge clk);
            settle();

            for (int i = 0; i < 5; i++) begin
                send_beat(20 + i, 1, (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC06-C: capture_done after 5x1", sample_capture_done == 1);

            verify_bram_range(0, 5, 8'd20, 1, errs);
            check($sformatf("TC06-C: single column errs=%0d/5", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC07: 随机数据 + 较大帧验证
        //   10x8 帧（80 像素），随机数据，全回读验证
        // =====================================================================
        test_id = 7;
        $display("--- TC%0d: Random data 10x8 verification ---", test_id);
        begin
            logic [DATA_WIDTH-1:0] frame_data [0:79];
            logic [DATA_WIDTH-1:0] rd;
            int errs;
            int n_pixels;

            errs = 0;
            n_pixels = 80;

            // 生成随机数据
            for (int i = 0; i < n_pixels; i++) begin
                frame_data[i] = $urandom;
            end

            capture_en = 1;
            img_rows   = 10;
            img_cols   = 8;
            @(posedge clk);
            settle();

            for (int i = 0; i < n_pixels; i++) begin
                send_beat(
                    frame_data[i],
                    ((i % 8) == 7),     // tlast 在行末
                    (i == 0)            // tuser 在帧首
                );
                @(posedge clk);
                settle();
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC07: capture_done asserted", sample_capture_done == 1);

            // 回读并验证
            for (int i = 0; i < n_pixels; i++) begin
                read_bram(i, rd);
                if (rd !== frame_data[i]) begin
                    errs++;
                    if (errs <= 3) begin
                        $display("  FAIL [7] bram[%0d] = 0x%0h (expected 0x%0h)",
                                 i, rd, frame_data[i]);
                    end
                end
            end
            if (errs == 0) begin
                $display("  PASS [7] all %0d random data locations verified", n_pixels);
                pass_count++;
            end else begin
                fail_count++;
                $display("  FAIL [7] %0d mismatches in random data", errs);
            end

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // TC08: 全 BRAM 深度验证（64x64 = 4096 位置）
        //   顺序写入全部 4096 位置, 验证首尾各 256 位置
        // =====================================================================
        test_id = 8;
        $display("--- TC%0d: Full BRAM depth (64x64) sequential write+read ---",
                 test_id);
        begin
            logic [DATA_WIDTH-1:0] rd;
            int errs;
            int total;

            capture_en = 1;
            img_rows   = MAX_ROWS;
            img_cols   = MAX_COLS;
            @(posedge clk);
            settle();

            total = MAX_ROWS * MAX_COLS;
            $display("  TC08: writing %0d locations (may take a moment)...", total);

            for (int i = 0; i < total; i++) begin
                send_beat(
                    i[7:0],                                   // data = 索引低 8 位
                    ((i % MAX_COLS) == MAX_COLS - 1),            // tlast 在行末
                    (i == 0)
                );
                @(posedge clk);
                settle();
                if (i > 0 && i % 1024 == 0) begin
                    $display("  TC08: %0d/%0d beats sent...", i, total);
                end
            end
            idle_beat();

            @(posedge clk);
            settle();
            check("TC08: capture_done after full depth", sample_capture_done == 1);

            // 验证前 256 个位置
            $display("  TC08: verifying first 256 locations...");
            verify_bram_range(0, 256, 8'd0, 1, errs);
            check($sformatf("TC08: first 256 errs=%0d", errs), errs == 0);

            // 验证后 256 个位置
            $display("  TC08: verifying last 256 locations...");
            verify_bram_range(total - 256, 256, (total - 256), 1, errs);
            check($sformatf("TC08: last 256 errs=%0d", errs), errs == 0);

            capture_en = 0;
            @(posedge clk);
            settle();
        end

        // =====================================================================
        // 摘要
        // =====================================================================
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
        $dumpfile("tb_l1b_write_path.vcd");
        $dumpvars(0, tb_l1b_write_path);
    end

    // -------------------------------------------------------------------------
    // Timeout —— 防止仿真失控（全深度测试需要较多时间）
    // -------------------------------------------------------------------------
    initial begin
        #30000000;  // 30 ms
        $display("[TIMEOUT] Simulation exceeded 30 ms without finishing.");
        $display("  Passed: %0d, Failed: %0d", pass_count, fail_count);
        $finish;
    end

endmodule

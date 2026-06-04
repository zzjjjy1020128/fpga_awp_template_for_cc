// tb_axil_regs: Testbench for axil_slave_if + regs_top
//
// Implements AXI-Lite master BFM and runs 11 directed test cases.
// Drive-on-negedge strategy avoids clock-edge race conditions.
//
// Usage: iverilog -g2012 -o sim/simv -I rtl rtl/axil_slave_if.sv rtl/regs_top.sv tb/tb_axil_regs.sv
//        vvp sim/simv

`timescale 1ns/1ps

module tb_axil_regs;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_PERIOD = 10;  // 100 MHz

    // =========================================================================
    // Signals
    // =========================================================================
    reg clk;
    reg rstn;

    // AXI4-Lite Slave interface (driven by testbench BFM)
    reg  [31:0] s_axil_awaddr;
    reg         s_axil_awvalid;
    wire        s_axil_awready;
    reg  [31:0] s_axil_wdata;
    reg  [3:0]  s_axil_wstrb;
    reg         s_axil_wvalid;
    wire        s_axil_wready;
    wire [1:0]  s_axil_bresp;
    wire        s_axil_bvalid;
    reg         s_axil_bready;
    reg  [31:0] s_axil_araddr;
    reg         s_axil_arvalid;
    wire        s_axil_arready;
    wire [31:0] s_axil_rdata;
    wire [1:0]  s_axil_rresp;
    wire        s_axil_rvalid;
    reg         s_axil_rready;

    // Status inputs from ctrl_fsm (driven by testbench to simulate ctrl_fsm)
    reg         status_idle;
    reg         status_busy_capture;
    reg         status_busy_shift;
    reg         status_done;
    reg         status_error;

    // Internal interconnect between axil_slave_if and regs_top
    wire [15:0] wr_strobe;
    wire [15:0] rd_strobe;
    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire [31:0] regs_rdata;

    // =========================================================================
    // Clock generation
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // DUT: AXI-Lite Slave Interface
    // =========================================================================
    axil_slave_if #(
        .AXIL_ADDR_WIDTH(32),
        .AXIL_DATA_WIDTH(32)
    ) u_axil (
        .clk               (clk),
        .rstn              (rstn),
        .s_axil_awaddr     (s_axil_awaddr),
        .s_axil_awvalid    (s_axil_awvalid),
        .s_axil_awready    (s_axil_awready),
        .s_axil_wdata      (s_axil_wdata),
        .s_axil_wstrb      (s_axil_wstrb),
        .s_axil_wvalid     (s_axil_wvalid),
        .s_axil_wready     (s_axil_wready),
        .s_axil_bresp      (s_axil_bresp),
        .s_axil_bvalid     (s_axil_bvalid),
        .s_axil_bready     (s_axil_bready),
        .s_axil_araddr     (s_axil_araddr),
        .s_axil_arvalid    (s_axil_arvalid),
        .s_axil_arready    (s_axil_arready),
        .s_axil_rdata      (s_axil_rdata),
        .s_axil_rresp      (s_axil_rresp),
        .s_axil_rvalid     (s_axil_rvalid),
        .s_axil_rready     (s_axil_rready),
        .wr_strobe         (wr_strobe),
        .rd_strobe         (rd_strobe),
        .wdata             (wdata),
        .wstrb             (wstrb),
        .rdata             (regs_rdata)
    );

    // =========================================================================
    // DUT: Register File
    // =========================================================================
    regs_top u_regs (
        .clk                (clk),
        .rstn               (rstn),
        .wr_strobe          (wr_strobe),
        .rd_strobe          (rd_strobe),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .rdata              (regs_rdata),
        .ctrl_start         (),
        .ctrl_sw_reset      (),
        .cfg_dir            (),
        .cfg_step           (),
        .cfg_wrap_en        (),
        .img_rows           (),
        .img_cols           (),
        .status_idle        (status_idle),
        .status_busy_capture(status_busy_capture),
        .status_busy_shift  (status_busy_shift),
        .status_done        (status_done),
        .status_error       (status_error)
    );

    // =========================================================================
    // Test harness control
    // =========================================================================
    integer error_count;
    integer test_count;

    // ----- Initial block: reset, run tests, report, finish ------------------
    initial begin
        error_count = 0;
        test_count  = 0;

        // Defaults
        rstn                = 0;
        s_axil_awaddr       = 0;
        s_axil_awvalid      = 0;
        s_axil_wdata        = 0;
        s_axil_wstrb        = 4'h0;
        s_axil_wvalid       = 0;
        s_axil_bready       = 0;
        s_axil_araddr       = 0;
        s_axil_arvalid      = 0;
        s_axil_rready       = 0;
        status_idle         = 0;
        status_busy_capture = 0;
        status_busy_shift   = 0;
        status_done         = 0;
        status_error        = 0;

        // Let clock run a few cycles before deasserting reset
        repeat (3) @(posedge clk);

        // Deassert reset synchronously
        @(negedge clk);
        rstn = 1;

        // Wait for global stabilization
        repeat (3) @(posedge clk);

        // Execute all test cases
        run_all_tests();

        // Print final summary
        $display("");
        $display("============================================================");
        $display("  AXI-Lite Register Simulation Summary");
        $display("  Date:    %t", $time);
        $display("  Tests:   %0d", test_count);
        $display("  Passed:  %0d", test_count - error_count);
        $display("  Failed:  %0d", error_count);
        $display("============================================================");
        if (error_count == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED  <<<");
        $display("============================================================");

        repeat (10) @(posedge clk);
        $finish;
    end

    // =========================================================================
    // AXI-Lite Master BFM
    //
    // Drive on negedge, sample DUT combo outputs on the next negedge.
    // This avoids race conditions with DUT always_ff blocks that sample
    // at posedge.
    // =========================================================================

    // ----- axil_write: full AXI4-Lite write transaction --------------------
    //
    // Drives AW + W simultaneously on negedge.
    // Keeps bready high until the DUT returns to W_IDLE (on the negedge after
    // the transition posedge), avoiding race conditions with DUT always_ff.
    task axil_write(
        input  [31:0] addr,
        input  [31:0] data,
        input  [3:0]  strb,
        output [1:0]  resp
    );
    begin
        @(negedge clk);
        s_axil_awaddr  = addr;
        s_axil_awvalid = 1'b1;
        s_axil_wdata   = data;
        s_axil_wstrb   = strb;
        s_axil_wvalid  = 1'b1;
        s_axil_bready  = 1'b1;

        @(posedge clk);   // DUT samples AW + W, enters W_RESP
        @(negedge clk);   // DUT combo settled

        s_axil_awvalid = 1'b0;
        s_axil_wvalid  = 1'b0;

        if (s_axil_bvalid) begin
            resp            = s_axil_bresp;
            // Keep bready=1 so DUT transitions W_RESP -> W_IDLE at next posedge
        end else begin
            @(posedge clk);
            @(negedge clk);
            resp            = s_axil_bresp;
        end

        // Let DUT transition back on posedge, THEN deassert on negedge
        @(posedge clk);   // DUT transitions W_RESP -> W_IDLE (bready=1)
        @(negedge clk);   // Safe to deassert bready
        s_axil_bready   = 1'b0;
    end
    endtask

    // ----- axil_write_full: convenience wrapper (all byte strobes high) ------
    task axil_write_full(
        input [31:0] addr,
        input [31:0] data
    );
        reg [1:0] r;
    begin
        axil_write(addr, data, 4'hF, r);
        if (r !== 2'b00) begin
            $display("  FAIL: Write to addr 0x%08X returned BRESP=%b (expected OKAY=00)",
                     addr, r);
            error_count = error_count + 1;
        end
    end
    endtask

    // ----- axil_read: full AXI4-Lite read transaction -----------------------
    //
    // Drives AR on negedge.
    // Keeps rready high until the DUT returns to R_IDLE (on the negedge after
    // the transition posedge), avoiding race conditions with DUT always_ff.
    task axil_read(
        input  [31:0] addr,
        output [31:0] data,
        output [1:0]  resp
    );
    begin
        @(negedge clk);
        s_axil_araddr  = addr;
        s_axil_arvalid = 1'b1;
        s_axil_rready  = 1'b1;

        @(posedge clk);   // DUT samples AR, enters R_ACTIVE
        @(negedge clk);   // DUT combo settled

        s_axil_arvalid = 1'b0;

        if (s_axil_rvalid) begin
            data            = s_axil_rdata;
            resp            = s_axil_rresp;
            // Keep rready=1 so DUT transitions R_ACTIVE -> R_IDLE at next posedge
        end else begin
            @(posedge clk);
            @(negedge clk);
            data            = s_axil_rdata;
            resp            = s_axil_rresp;
        end

        // Let DUT transition back on posedge, THEN deassert on negedge
        @(posedge clk);   // DUT transitions R_ACTIVE -> R_IDLE (rready=1)
        @(negedge clk);   // Safe to deassert rready
        s_axil_rready   = 1'b0;
    end
    endtask

    // =========================================================================
    // Check helpers
    // =========================================================================

    // ----- check_eq: compare two 32-bit values -----
    task check_eq(
        input [31:0]   expected,
        input [31:0]   actual,
        input string   desc
    );
    begin
        if (expected !== actual) begin
            $display("  FAIL [%0d]: %s -- expected 0x%08X, got 0x%08X",
                     test_count, desc, expected, actual);
            error_count = error_count + 1;
        end else begin
            $display("  PASS [%0d]: %s (0x%08X)", test_count, desc, actual);
        end
    end
    endtask

    // ----- check_resp: compare AXI-Lite response code -----
    task check_resp(
        input [1:0]    expected,
        input [1:0]    actual,
        input string   desc
    );
    begin
        if (expected !== actual) begin
            $display("  FAIL [%0d]: %s -- expected response %b, got %b",
                     test_count, desc, expected, actual);
            error_count = error_count + 1;
        end else begin
            $display("  PASS [%0d]: %s (response %b)", test_count, desc, actual);
        end
    end
    endtask

    // =========================================================================
    // Test case runner
    // =========================================================================
    task run_all_tests();
    begin
        $display("");
        $display("=== Running all test cases ===");
        $display("");

        tc01_write_rows;
        tc02_write_cols;
        tc03_write_multiple_readback;
        tc04_cfg_bitfields;
        tc05_ctrl_start_self_clear;
        tc06_ctrl_sw_reset_self_clear;
        tc07_read_reserved;
        tc08_write_reserved_no_side_effect;
        tc09_invalid_addr_slverr;
        tc10_status_simulation;
        tc11_wstrb_partial_write;

        $display("");
        $display("=== All test cases completed ===");
    end
    endtask

    // =========================================================================
    // TC01: Write IMG_ROWS=0x40, read back verify
    // =========================================================================
    task tc01_write_rows();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC01: Write IMG_ROWS=0x40, read back");

        axil_write_full(32'h0C, 32'h00000040);
        axil_read(32'h0C, rd_data, rd_resp);

        check_resp(2'b00, rd_resp, "TC01: IMG_ROWS read response");
        check_eq(32'h00000040, rd_data, "TC01: IMG_ROWS read data");
    end
    endtask

    // =========================================================================
    // TC02: Write IMG_COLS=0x80, read back verify
    // =========================================================================
    task tc02_write_cols();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC02: Write IMG_COLS=0x80, read back");

        axil_write_full(32'h10, 32'h00000080);
        axil_read(32'h10, rd_data, rd_resp);

        check_resp(2'b00, rd_resp, "TC02: IMG_COLS read response");
        check_eq(32'h00000080, rd_data, "TC02: IMG_COLS read data");
    end
    endtask

    // =========================================================================
    // TC03: Sequential writes (CFG, IMG_ROWS, IMG_COLS), read back each
    // =========================================================================
    task tc03_write_multiple_readback();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC03: Write CTRL, CFG, IMG_ROWS, IMG_COLS, read back each");

        // Write all four registers
        axil_write_full(32'h00, 32'h00000003);  // CTRL = start+sw_reset (self-clearing)
        axil_write_full(32'h08, 32'h00000105);  // CFG = wrap_en=1, step=4, dir=UP(1)
        axil_write_full(32'h0C, 32'h00000040);  // IMG_ROWS = 0x40
        axil_write_full(32'h10, 32'h00000080);  // IMG_COLS = 0x80

        // Read back CTRL  -> should be 0 (WO, self-clearing)
        axil_read(32'h00, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC03: CTRL read response");
        check_eq(32'h00000000, rd_data, "TC03: CTRL read data (self-cleared)");

        // Read back CFG -> should be 0x105
        axil_read(32'h08, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC03: CFG read response");
        check_eq(32'h00000105, rd_data, "TC03: CFG read data");

        // Read back IMG_ROWS -> should be 0x40
        axil_read(32'h0C, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC03: IMG_ROWS read response");
        check_eq(32'h00000040, rd_data, "TC03: IMG_ROWS read data");

        // Read back IMG_COLS -> should be 0x80
        axil_read(32'h10, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC03: IMG_COLS read response");
        check_eq(32'h00000080, rd_data, "TC03: IMG_COLS read data");
    end
    endtask

    // =========================================================================
    // TC04: CFG bit-field test
    // =========================================================================
    task tc04_cfg_bitfields();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC04: Write CFG with dir/step/wrap_en, verify bit fields");

        // Write CFG: dir=UP(1), step=5, wrap_en=1
        // Binary: [8]=1, [7:3]=00101, [2:0]=001 -> 0x129
        axil_write_full(32'h08, 32'h00000129);
        axil_read(32'h08, rd_data, rd_resp);

        check_resp(2'b00, rd_resp, "TC04: CFG read response");
        check_eq(32'h00000129, rd_data, "TC04: CFG read data");

        // Verify individual bit fields
        if (rd_data[2:0] !== 3'b001)
            $display("  FAIL [%0d]: TC04 CFG.dir = %b (expected 001)", test_count, rd_data[2:0]);
        else
            $display("  PASS [%0d]: TC04 CFG.dir = %b", test_count, rd_data[2:0]);

        if (rd_data[7:3] !== 5'b00101)
            $display("  FAIL [%0d]: TC04 CFG.step = %b (expected 00101)", test_count, rd_data[7:3]);
        else
            $display("  PASS [%0d]: TC04 CFG.step = %b", test_count, rd_data[7:3]);

        if (rd_data[8] !== 1'b1)
            $display("  FAIL [%0d]: TC04 CFG.wrap_en = %b (expected 1)", test_count, rd_data[8]);
        else
            $display("  PASS [%0d]: TC04 CFG.wrap_en = %b", test_count, rd_data[8]);
    end
    endtask

    // =========================================================================
    // TC05: CTRL.start self-clearing
    // =========================================================================
    task tc05_ctrl_start_self_clear();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC05: Write CTRL.start=1, verify self-clearing on read");

        axil_write_full(32'h00, 32'h00000001);  // start=1
        axil_read(32'h00, rd_data, rd_resp);

        check_resp(2'b00, rd_resp, "TC05: CTRL read response");
        check_eq(32'h00000000, rd_data, "TC05: CTRL read (should be 0, self-cleared)");
    end
    endtask

    // =========================================================================
    // TC06: CTRL.sw_reset self-clearing
    // =========================================================================
    task tc06_ctrl_sw_reset_self_clear();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC06: Write CTRL.sw_reset=1, verify self-clearing on read");

        axil_write_full(32'h00, 32'h00000002);  // sw_reset=1
        axil_read(32'h00, rd_data, rd_resp);

        check_resp(2'b00, rd_resp, "TC06: CTRL read response");
        check_eq(32'h00000000, rd_data, "TC06: CTRL read (should be 0, self-cleared)");
    end
    endtask

    // =========================================================================
    // TC07: Read reserved addresses (0x14, 0x18) -> return 0
    // =========================================================================
    task tc07_read_reserved();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC07: Read reserved addresses 0x14, 0x18");

        axil_read(32'h14, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC07: Reserved 0x14 read response");
        check_eq(32'h00000000, rd_data, "TC07: Reserved 0x14 read data");

        axil_read(32'h18, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC07: Reserved 0x18 read response");
        check_eq(32'h00000000, rd_data, "TC07: Reserved 0x18 read data");
    end
    endtask

    // =========================================================================
    // TC08: Write reserved address, verify no side effect on other registers
    // =========================================================================
    task tc08_write_reserved_no_side_effect();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        test_count = test_count + 1;
        $display("TC08: Write reserved 0x14, verify CFG/IMG_ROWS unchanged");

        // First write a known pattern to CFG and IMG_ROWS
        axil_write_full(32'h08, 32'h00000123);
        axil_write_full(32'h0C, 32'h000000AA);

        // Write to reserved address 0x14
        axil_write_full(32'h14, 32'hDEADBEEF);

        // Read back CFG  -> should be unchanged
        axil_read(32'h08, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC08: CFG read response after reserved write");
        check_eq(32'h00000123, rd_data, "TC08: CFG unchanged after 0x14 write");

        // Read back IMG_ROWS -> should be unchanged
        axil_read(32'h0C, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC08: IMG_ROWS read response after reserved write");
        check_eq(32'h000000AA, rd_data, "TC08: IMG_ROWS unchanged after 0x14 write");
    end
    endtask

    // =========================================================================
    // TC09: Access invalid address (0x40) -> SLVERR
    // =========================================================================
    task tc09_invalid_addr_slverr();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        reg [1:0]  wr_resp;
        test_count = test_count + 1;
        $display("TC09: Read/Write invalid address 0x40, verify SLVERR");

        // Write to 0x40
        axil_write(32'h40, 32'hAABBCCDD, 4'hF, wr_resp);
        check_resp(2'b10, wr_resp, "TC09: Write 0x40 BRESP (SLVERR)");

        // Read from 0x40
        axil_read(32'h40, rd_data, rd_resp);
        check_resp(2'b10, rd_resp, "TC09: Read 0x40 RRESP (SLVERR)");
    end
    endtask

    // =========================================================================
    // TC10: STATUS simulation
    // =========================================================================
    task tc10_status_simulation();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;

        // ---- Phase A: idle -> busy_capture -> busy_shift ----
        test_count = test_count + 1;
        $display("TC10-A: STATUS idle=1");
        status_idle         = 1;
        status_busy_capture = 0;
        status_busy_shift   = 0;
        status_done         = 0;
        @(negedge clk);  // drive on negedge, stable for DUT at next posedge
        @(posedge clk);

        axil_read(32'h04, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC10-A: STATUS read response");
        check_eq(32'h00000001, rd_data, "TC10-A: STATUS idle active (bit 0)");

        test_count = test_count + 1;
        $display("TC10-B: STATUS busy_capture=1");
        status_idle         = 0;
        status_busy_capture = 1;
        @(negedge clk);
        @(posedge clk);

        axil_read(32'h04, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC10-B: STATUS read response");
        check_eq(32'h00000002, rd_data, "TC10-B: STATUS busy_capture (bit 1)");

        test_count = test_count + 1;
        $display("TC10-C: STATUS busy_shift=1");
        status_busy_capture = 0;
        status_busy_shift   = 1;
        @(negedge clk);
        @(posedge clk);

        axil_read(32'h04, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC10-C: STATUS read response");
        check_eq(32'h00000004, rd_data, "TC10-C: STATUS busy_shift (bit 2)");

        // ---- Phase D: done latched, idle cleared ----
        test_count = test_count + 1;
        $display("TC10-D: STATUS done=1 (pulse), check done latched + idle cleared");
        status_busy_shift = 0;
        status_done = 1;
        @(negedge clk);  // drive on negedge for safe DUT sampling at posedge
        @(posedge clk);  // DUT samples status_done=1, sets done_latched
        @(negedge clk);  // safe to change status signals
        status_done = 0;   // pulse done for 1 cycle, done_latched should stay
        @(posedge clk);

        // Now set idle=1 but done is latched, so idle_eff should be 0 (mutual exclusivity)
        @(negedge clk);
        status_idle = 1;
        @(posedge clk);

        axil_read(32'h04, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC10-D: STATUS read response");
        // Expected: done_latched=1, idle=0 (mutex), busy bits=0
        check_eq(32'h00000008, rd_data, "TC10-D: STATUS done latched (bit 3), idle=0");

        // ---- Phase E: Write CTRL.start to clear done ----
        test_count = test_count + 1;
        $display("TC10-E: Write CTRL.start=1 to clear done, check idle restored");
        axil_write_full(32'h00, 32'h00000001);  // start=1 clears done_latched

        // Wait for combo to settle
        @(posedge clk);

        axil_read(32'h04, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC10-E: STATUS read response");
        // done cleared, idle=1 (mutex satisfied since no other bits active)
        check_eq(32'h00000001, rd_data, "TC10-E: STATUS idle restored (bit 0), done cleared");

        // ---- Phase F: idle mutual exclusivity ----
        test_count = test_count + 1;
        $display("TC10-F: Verify mutual exclusivity: busy_capture+idle -> busy takes priority");
        @(negedge clk);
        status_idle         = 1;
        status_busy_capture = 1;
        status_busy_shift   = 0;
        status_done         = 0;
        @(posedge clk);

        axil_read(32'h04, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC10-F: STATUS read response");
        // idle_eff = status_idle && !busy_capture && !busy_shift && !done_latched = 1 && !1 && !0 && !0 = 0
        // So STATUS should show busy_capture=1, idle=0
        check_eq(32'h00000002, rd_data, "TC10-F: STATUS busy_capture (idle suppressed by mutex)");

        // Clean up
        @(negedge clk);
        status_idle         = 0;
        status_busy_capture = 0;
        @(posedge clk);
    end
    endtask

    // =========================================================================
    // TC11: WSTRB partial write
    // =========================================================================
    task tc11_wstrb_partial_write();
    begin
        reg [31:0] rd_data;
        reg [1:0]  rd_resp;
        reg [1:0]  wr_resp;
        test_count = test_count + 1;
        $display("TC11: WSTRB partial write to IMG_ROWS high byte");

        // Reset IMG_ROWS to known value: low byte = 0xFF, high byte = 0x00
        axil_write_full(32'h0C, 32'h000000FF);

        // Verify initial value
        axil_read(32'h0C, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC11: Initial IMG_ROWS read response");
        check_eq(32'h000000FF, rd_data, "TC11: Initial IMG_ROWS value");

        // Write to high byte only using wstrb=4'b0010
        // IMG_ROWS address 0x0C, write data = 0x00001000
        // wstrb[1]=1 means byte 1 (bits [15:8]) is written
        axil_write(32'h0C, 32'h00001000, 4'b0010, wr_resp);
        check_resp(2'b00, wr_resp, "TC11: Partial write BRESP (OKAY)");

        // Read back: low byte should still be 0xFF, high byte should be 0x10
        axil_read(32'h0C, rd_data, rd_resp);
        check_resp(2'b00, rd_resp, "TC11: IMG_ROWS read response after partial write");
        check_eq(32'h000010FF, rd_data, "TC11: IMG_ROWS after WSTRB partial write (low=FF, high=10)");
    end
    endtask

endmodule : tb_axil_regs

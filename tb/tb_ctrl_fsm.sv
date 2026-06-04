//==============================================================================
// tb_ctrl_fsm - Testbench for ctrl_fsm 4-state main controller
//
// Test cases:
//   TC01: After reset, state is IDLE (status_idle=1, all others=0)
//   TC02: start=1 triggers IDLE->CAPTURE, capture_en=1
//   TC03: capture_done=1 triggers CAPTURE->SHIFT, shift_en=1
//   TC04: shift_done=1 triggers SHIFT->DONE, status_done=1
//   TC05: DONE auto-transitions to IDLE after 1 cycle
//   TC06: sw_reset from CAPTURE returns to IDLE
//   TC07: sw_reset from SHIFT returns to IDLE
//   TC08: sw_reset from DONE returns to IDLE
//   TC09: Full normal flow (start->CAPTURE->SHIFT->DONE->IDLE)
//   TC10: Stay in IDLE when start=0 (no false trigger)
//   TC11: sw_reset priority over ctrl_start
//==============================================================================

`timescale 1ns/1ps

module tb_ctrl_fsm;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam real CLK_PERIOD = 10.0;  // 100 MHz

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    logic clk;
    logic rstn;
    logic ctrl_start;
    logic ctrl_sw_reset;
    logic capture_done;
    logic shift_done;
    logic status_idle;
    logic status_busy_capture;
    logic status_busy_shift;
    logic status_done;
    logic capture_en;
    logic shift_en;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    ctrl_fsm dut (
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

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2.0) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Test Infrastructure
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;
    int test_id    = 0;

    // Check a condition and count pass/fail
    task check(input string desc, input logic cond);
        if (cond) begin
            pass_count++;
            $display("  PASS [%0d] %s", test_id, desc);
        end else begin
            fail_count++;
            $display("  FAIL [%0d] %s", test_id, desc);
        end
    endtask

    // Wait N clock cycles
    task wait_cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    // -------------------------------------------------------------------------
    // Stimulus Helpers — use #(CLK_PERIOD/10) after posedge so combinational
    // outputs (status_*, capture_en, shift_en) have settled.
    // -------------------------------------------------------------------------
    task pulse_start();
        @(posedge clk); ctrl_start = 1;
        @(posedge clk); ctrl_start = 0;
    endtask

    task pulse_capture_done();
        @(posedge clk); capture_done = 1;
        @(posedge clk); capture_done = 0;
    endtask

    task pulse_shift_done();
        @(posedge clk); shift_done = 1;
        @(posedge clk); shift_done = 0;
    endtask

    task pulse_sw_reset();
        @(posedge clk); ctrl_sw_reset = 1;
        @(posedge clk); ctrl_sw_reset = 0;
    endtask

    // Assert both start and sw_reset at same time
    task assert_both_start_and_reset();
        @(posedge clk);
        ctrl_start    = 1;
        ctrl_sw_reset = 1;
        @(posedge clk);
        ctrl_start    = 0;
        ctrl_sw_reset = 0;
    endtask

    // Settle delay — #1 gives 1 ns for combinational logic settling
    task settle();
        #1;
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        // Initialize all inputs
        rstn         = 0;
        ctrl_start   = 0;
        ctrl_sw_reset = 0;
        capture_done = 0;
        shift_done   = 0;

        $display("============================================================");
        $display("  tb_ctrl_fsm - Starting Simulation");
        $display("============================================================");

        // Release reset: hold low for 4 cycles, then release
        wait_cycles(4);
        rstn = 1;
        @(posedge clk);
        settle();

        // =====================================================================
        // TC01: After reset, state=IDLE, status_idle=1, all others=0
        // =====================================================================
        test_id = 1;
        $display("--- TC%0d: Reset -> IDLE ---", test_id);
        check("status_idle=1 after reset",           status_idle == 1);
        check("status_busy_capture=0",               status_busy_capture == 0);
        check("status_busy_shift=0",                 status_busy_shift == 0);
        check("status_done=0",                       status_done == 0);
        check("capture_en=0",                        capture_en == 0);
        check("shift_en=0",                          shift_en == 0);

        // =====================================================================
        // TC10: Stay in IDLE when start=0 (no false trigger)
        // =====================================================================
        test_id = 10;
        $display("--- TC%0d: Stay in IDLE (start=0) ---", test_id);
        // Wait several cycles without any stimulus
        wait_cycles(5);
        settle();
        check("status_idle remains 1 (no false trigger)", status_idle == 1);
        check("capture_en remains 0",                     capture_en == 0);
        check("shift_en remains 0",                       shift_en == 0);

        // =====================================================================
        // TC02: start=1 triggers IDLE->CAPTURE, capture_en=1
        // =====================================================================
        test_id = 2;
        $display("--- TC%0d: start -> CAPTURE ---", test_id);
        pulse_start();
        settle();
        check("capture_en=1 after start",               capture_en == 1);
        check("status_busy_capture=1",                  status_busy_capture == 1);
        check("status_idle=0 (not IDLE)",               status_idle == 0);
        check("shift_en=0 (not SHIFT)",                 shift_en == 0);
        check("status_done=0 (not DONE)",               status_done == 0);

        // =====================================================================
        // TC06: sw_reset from CAPTURE returns to IDLE
        // =====================================================================
        test_id = 6;
        $display("--- TC%0d: sw_reset from CAPTURE -> IDLE ---", test_id);
        // Confirm we're in CAPTURE first
        wait_cycles(1);
        settle();
        check("still in CAPTURE before sw_reset",       capture_en == 1);
        // Assert sw_reset
        pulse_sw_reset();
        settle();
        check("back to IDLE after sw_reset",            status_idle == 1);
        check("capture_en=0 after sw_reset",            capture_en == 0);
        check("status_busy_capture=0",                  status_busy_capture == 0);

        // =====================================================================
        // TC03: capture_done=1 triggers CAPTURE->SHIFT, shift_en=1
        // =====================================================================
        test_id = 3;
        $display("--- TC%0d: capture_done -> SHIFT ---", test_id);
        pulse_start();
        settle();
        check("entered CAPTURE for TC03",               capture_en == 1);
        pulse_capture_done();
        settle();
        check("shift_en=1 after capture_done",          shift_en == 1);
        check("status_busy_shift=1",                    status_busy_shift == 1);
        check("capture_en=0 (left CAPTURE)",            capture_en == 0);
        check("status_idle=0",                          status_idle == 0);

        // =====================================================================
        // TC07: sw_reset from SHIFT returns to IDLE
        // =====================================================================
        test_id = 7;
        $display("--- TC%0d: sw_reset from SHIFT -> IDLE ---", test_id);
        wait_cycles(1);
        settle();
        check("still in SHIFT before sw_reset",         shift_en == 1);
        pulse_sw_reset();
        settle();
        check("back to IDLE from SHIFT",                status_idle == 1);
        check("shift_en=0 after sw_reset",              shift_en == 0);
        check("status_busy_shift=0",                    status_busy_shift == 0);

        // =====================================================================
        // TC04: shift_done=1 triggers SHIFT->DONE, status_done=1
        // =====================================================================
        test_id = 4;
        $display("--- TC%0d: shift_done -> DONE ---", test_id);
        pulse_start();
        pulse_capture_done();
        settle();
        check("entered SHIFT for TC04",                 shift_en == 1);
        pulse_shift_done();
        settle();
        check("status_done=1 after shift_done",         status_done == 1);
        check("shift_en=0 (left SHIFT)",                shift_en == 0);
        check("capture_en=0",                           capture_en == 0);
        check("status_idle=0 (not yet IDLE)",           status_idle == 0);

        // =====================================================================
        // TC05: DONE auto-transitions to IDLE after 1 cycle
        // =====================================================================
        test_id = 5;
        $display("--- TC%0d: DONE -> auto IDLE ---", test_id);
        // state should be DONE right now (checked above in TC04).
        // Wait one clock edge: DONE -> IDLE (auto, since next=IDLE always).
        @(posedge clk);
        settle();
        check("auto returned to IDLE from DONE",        status_idle == 1);
        check("status_done=0 (left DONE)",              status_done == 0);
        check("shift_en=0",                             shift_en == 0);
        check("capture_en=0",                           capture_en == 0);

        // =====================================================================
        // TC08: sw_reset from DONE returns to IDLE
        // =====================================================================
        test_id = 8;
        $display("--- TC%0d: sw_reset from DONE -> IDLE ---", test_id);
        // Re-enter DONE
        pulse_start();
        pulse_capture_done();
        pulse_shift_done();
        settle();
        check("reached DONE for TC08",                  status_done == 1);
        // Assert sw_reset while in DONE
        pulse_sw_reset();
        settle();
        check("IDLE after sw_reset from DONE",          status_idle == 1);
        check("status_done=0",                          status_done == 0);

        // =====================================================================
        // TC09: Full normal flow
        //        start -> CAPTURE -> SHIFT -> DONE -> IDLE
        //        Verify each stage's output signals
        // =====================================================================
        test_id = 9;
        $display("--- TC%0d: Full normal flow ---", test_id);

        // Stage 1: start -> CAPTURE
        pulse_start();
        settle();
        check("F09: capture_en=1",                      capture_en == 1);
        check("F09: status_busy_capture=1",             status_busy_capture == 1);
        check("F09: status_idle=0",                     status_idle == 0);

        // Stage 2: capture_done -> SHIFT
        pulse_capture_done();
        settle();
        check("F09: shift_en=1",                        shift_en == 1);
        check("F09: status_busy_shift=1",               status_busy_shift == 1);
        check("F09: capture_en=0",                      capture_en == 0);

        // Stage 3: shift_done -> DONE
        pulse_shift_done();
        settle();
        check("F09: status_done=1",                     status_done == 1);
        check("F09: shift_en=0",                        shift_en == 0);

        // Stage 4: DONE -> IDLE (auto, 1 cycle)
        @(posedge clk);
        settle();
        check("F09: status_idle=1 (auto return)",       status_idle == 1);
        check("F09: status_done=0",                     status_done == 0);

        // =====================================================================
        // TC11: sw_reset priority over ctrl_start
        //        When both are asserted simultaneously, state stays in IDLE
        // =====================================================================
        test_id = 11;
        $display("--- TC%0d: sw_reset priority over start ---", test_id);
        // Assert both at the same rising edge
        assert_both_start_and_reset();
        settle();
        check("TC11: still IDLE (sw_reset takes priority)", status_idle == 1);
        check("TC11: capture_en=0 (start blocked by reset)", capture_en == 0);

        // Verify that start alone still works normally after this
        pulse_start();
        settle();
        check("TC11: start still works normally after priority test", capture_en == 1);
        // Clean up the state machine
        pulse_sw_reset();
        settle();

        // =====================================================================
        // Summary
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

        // Finish after a short delay
        #100;
        $finish;
    end

    // -------------------------------------------------------------------------
    // VCD Dump (for waveform debugging)
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_ctrl_fsm.vcd");
        $dumpvars(0, tb_ctrl_fsm);
    end

    // -------------------------------------------------------------------------
    // Timeout — prevent runaway simulation
    // -------------------------------------------------------------------------
    initial begin
        #2000;
        $display("[TIMEOUT] Simulation exceeded 2000 ns without finishing.");
        $display("  Passed: %0d, Failed: %0d", pass_count, fail_count);
        $finish;
    end

endmodule

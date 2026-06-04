//==============================================================================
// tb_axis_input - Testbench for axis_input AXI4-Stream input interface
//
// Timing conventions:
//   write_addr is combinatorial: row_cnt * img_cols + col_cnt.
//   After @(posedge clk) + settle() (#1), NBA has committed and write_addr
//   reflects the counter state for the NEXT beat.
//
//   We check write_addr BEFORE each beat to verify the address for the
//   upcoming transfer.  After the posedge (where the beat is captured),
//   we check sample_write_en to confirm write_en was asserted during the
//   transfer, and sample_capture_done to detect the frame-end pulse.
//
// Test cases:
//   TC01: Basic capture 4x4 — verify write_addr sequence 0..15
//   TC02: tuser resets counters mid-frame
//   TC03: tlast row end — col resets, row+1
//   TC04: capture_done 1-cycle pulse at frame end
//   TC05: capture_en=0  -> tready=0, counters frozen
//   TC06: Single row (img_rows=1) — tlast triggers capture_done
//   TC07: Single column (img_cols=1) — tuser+tlast handling
//   TC08: Single pixel (1x1) — tuser+tlast both, capture_done
//   TC09: Dynamic img_rows/img_cols switching
//   TC10: capture_en mid-cancel and resume
//   TC11: Multiple frame sizes, verify write_addr in raster order
//==============================================================================

`timescale 1ns/1ps

module tb_axis_input;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 8;
    localparam MAX_ROWS   = 64;
    localparam MAX_COLS   = 64;
    localparam real CLK_PERIOD = 10.0;

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    logic                    clk;
    logic                    rstn;
    logic [DATA_WIDTH-1:0]   s_axis_tdata;
    logic                    s_axis_tvalid;
    logic                    s_axis_tready;
    logic                    s_axis_tlast;
    logic                    s_axis_tuser;
    logic                    capture_en;
    logic [9:0]              img_rows;
    logic [9:0]              img_cols;
    logic [11:0]             write_addr;
    logic [DATA_WIDTH-1:0]   write_data;
    logic                    write_en;
    logic                    capture_done;

    // Sampled at posedge — used to capture combinatorial values that hold
    // only during the clock edge (write_en, capture_done pulse).
    logic                    sample_write_en;
    logic                    sample_capture_done;

    // Module-level helpers for initial-block use
    logic [11:0]             frozen_addr;

    // TC11 sizes
    int                      t11_sizes[8];
    int                      t11_rr;
    int                      t11_cc;
    int                      t11_total;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    axis_input #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_ROWS  (MAX_ROWS),
        .MAX_COLS  (MAX_COLS)
    ) dut (
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

    // -------------------------------------------------------------------------
    // Sample combinatorial / pulse outputs at each posedge
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        sample_write_en     <= write_en;
        sample_capture_done <= capture_done;
    end

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
    // Stimulus Helpers
    // -------------------------------------------------------------------------
    task reset_dut();
        rstn = 0;
        wait_cycles(4);
        rstn = 1;
        @(posedge clk);
        settle();
    endtask

    task init_inputs();
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        s_axis_tuser  = 0;
        capture_en    = 0;
        img_rows      = 4;
        img_cols      = 4;
    endtask

    // Drive a single AXI-Stream beat (call before @(posedge clk))
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

    // Deassert valid
    task idle_beat();
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        s_axis_tuser  = 0;
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        init_inputs();

        $display("============================================================");
        $display("  tb_axis_input - Starting Simulation");
        $display("============================================================");

        reset_dut();

        // =====================================================================
        // TC01: Basic capture — 4x4 frame, verify write_addr 0..15
        // =====================================================================
        test_id = 1;
        $display("--- TC%0d: Basic capture 4x4 ---", test_id);

        capture_en = 1;
        img_rows   = 4;
        img_cols   = 4;
        @(posedge clk);
        settle();

        // Before any transfer: write_addr = 0 (address for first beat)
        check("initial write_addr == 0", write_addr == 0);

        for (int i = 0; i < 16; i++) begin
            // write_addr should be i before we send beat i
            check($sformatf("beat %0d: write_addr == %0d", i, i), write_addr == i);
            send_beat(i, (i % 4 == 3), (i == 0));
            @(posedge clk);
            settle();
            // After settle: write_addr shows address for next beat
        end
        // After beat 15: the frame is done; capture_done was scheduled.
        // Deassert valid immediately to prevent an extra transfer.
        idle_beat();

        // Check that write_en was 1 at the last beat's posedge
        check("last sample_write_en == 1", sample_write_en == 1);

        // Advance one more cycle.  Now sample_capture_done captures the
        // 1-cycle pulse that was set at the completing beat's NBA.
        @(posedge clk);
        settle();
        check("capture_done = 1 after frame", sample_capture_done == 1);
        // write_addr should be 0 after frame-end reset
        check("write_addr == 0 after frame end", write_addr == 0);

        // One more cycle: self-clear verified
        @(posedge clk);
        settle();
        check("capture_done self-cleared", sample_capture_done == 0);

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC02: tuser resets counters mid-frame
        // =====================================================================
        test_id = 2;
        $display("--- TC%0d: tuser frame-start reset ---", test_id);

        capture_en = 1;
        img_rows   = 4;
        img_cols   = 4;
        @(posedge clk);
        settle();

        // Send 3 beats of a "frame": row 0, beats 0..2
        for (int i = 0; i < 3; i++) begin
            send_beat(i, 0, (i == 0));
            @(posedge clk);
            settle();
        end
        // After 3 beats: row=0, col=3, write_addr = 0*4+3 = 3

        // Send a tuser=1 mid-frame — this should write to current addr (3)
        // then reset counters to (0, 1) for the next beat
        check("mid-frame tuser: write_addr == 3 before beat", write_addr == 3);
        send_beat(10, 0, 1);
        @(posedge clk);
        settle();
        // After NBA: row=0, col=1, write_addr = 1
        check("after tuser reset: write_addr == 1", write_addr == 1);

        // Next normal beat should go to addr 1
        check("next beat starts at addr 1", write_addr == 1);
        send_beat(11, 0, 0);
        @(posedge clk);
        settle();
        check("after beat at addr 1: write_addr == 2", write_addr == 2);

        idle_beat();
        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC03: tlast row end — col resets, row+1
        // =====================================================================
        test_id = 3;
        $display("--- TC%0d: tlast row-end ---", test_id);

        capture_en = 1;
        img_rows   = 4;
        img_cols   = 4;
        @(posedge clk);
        settle();

        // Send row 0: 4 beats, last one has tlast
        for (int i = 0; i < 4; i++) begin
            send_beat(i, (i == 3), (i == 0));
            @(posedge clk);
            settle();
        end
        // After row 0 tlast: col=0, row=1
        // write_addr = 1*4+0 = 4
        check("after tlast: write_addr == 4 (start row 1)", write_addr == 4);

        // Send first beat of row 1
        send_beat(4, 0, 0);
        @(posedge clk);
        settle();
        check("row 1 beat 0: write_addr == 5", write_addr == 5);

        idle_beat();
        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC04: capture_done 1-cycle pulse at frame end
        // =====================================================================
        test_id = 4;
        $display("--- TC%0d: capture_done pulse ---", test_id);

        capture_en = 1;
        img_rows   = 2;
        img_cols   = 3;
        @(posedge clk);
        settle();

        // Send row 0: 3 beats
        for (int i = 0; i < 3; i++) begin
            send_beat(i, (i == 2), (i == 0));
            @(posedge clk);
            settle();
            // No capture_done yet
            if (i < 2) begin
                check("no capture_done mid-frame", sample_capture_done == 0);
            end
        end

        // Send row 1: 3 beats
        for (int i = 0; i < 3; i++) begin
            send_beat(3 + i, (i == 2), 0);
            @(posedge clk);
            settle();
        end
        // After completing beat: deassert valid
        idle_beat();

        // Advance one cycle so sample captures the 1-cycle pulse
        @(posedge clk);
        settle();
        check("capture_done = 1 at frame end", sample_capture_done == 1);

        // Self-clear
        @(posedge clk);
        settle();
        check("capture_done cleared after 1 cycle", sample_capture_done == 0);

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC05: capture_en=0  -> tready=0, counters frozen
        // =====================================================================
        test_id = 5;
        $display("--- TC%0d: capture_en=0 pause ---", test_id);

        capture_en = 0;
        img_rows   = 4;
        img_cols   = 4;
        @(posedge clk);
        settle();

        // tready should be 0 when capture_en=0
        check("tready=0 when capture_en=0", s_axis_tready == 0);

        frozen_addr = write_addr;

        // Attempt a beat while capture_en=0
        send_beat(0, 0, 1);
        @(posedge clk);
        settle();

        // No transfer should happen
        check("write_en=0 during pause", sample_write_en == 0);
        check("write_addr unchanged during pause", write_addr == frozen_addr);

        // Now assert capture_en — the pending beat goes through
        capture_en = 1;
        @(posedge clk);
        settle();
        check("write_en=1 after capture_en re-asserted", sample_write_en == 1);
        check("write_addr=1 after first captured beat (col inc)", write_addr == 1);

        idle_beat();
        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC06: Single row (img_rows=1) — tlast triggers capture_done
        // =====================================================================
        test_id = 6;
        $display("--- TC%0d: Single row (img_rows=1) ---", test_id);

        capture_en = 1;
        img_rows   = 1;
        img_cols   = 5;
        @(posedge clk);
        settle();

        // Send row 0: 5 beats, tlast on 5th = frame complete
        for (int i = 0; i < 5; i++) begin
            send_beat(i, (i == 4), (i == 0));
            @(posedge clk);
            settle();
        end
        // Deassert valid after frame
        idle_beat();

        // Advance so sample captures the 1-cycle pulse
        @(posedge clk);
        settle();
        check("capture_done after single-row frame", sample_capture_done == 1);

        @(posedge clk);
        settle();
        check("capture_done self-cleared", sample_capture_done == 0);

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC07: Single column (img_cols=1) — tuser+tlast handling
        // =====================================================================
        test_id = 7;
        $display("--- TC%0d: Single column (img_cols=1) ---", test_id);

        capture_en = 1;
        img_rows   = 3;
        img_cols   = 1;
        @(posedge clk);
        settle();

        // Beat 0: tuser=1, tlast=1, img_rows>1 => row+1, col=0
        check("write_addr == 0 before beat 0 (single col)", write_addr == 0);
        send_beat(0, 1, 1);
        @(posedge clk);
        settle();
        // row=1, col=0 => write_addr = 1*1+0 = 1
        check("after beat 0: write_addr == 1", write_addr == 1);

        // Beat 1: tuser=0, tlast=1 => col=0, row+1 (=2)
        send_beat(1, 1, 0);
        @(posedge clk);
        settle();
        check("after beat 1: write_addr == 2", write_addr == 2);

        // Beat 2: tuser=0, tlast=1, row=img_rows-1 => capture_done, row=0
        send_beat(2, 1, 0);
        @(posedge clk);
        settle();
        // Deassert valid after frame
        idle_beat();

        // Advance so sample captures the 1-cycle pulse
        @(posedge clk);
        settle();
        check("capture_done after single-col frame", sample_capture_done == 1);
        check("write_addr = 0 after frame done", write_addr == 0);

        @(posedge clk);
        settle();
        check("capture_done self-cleared", sample_capture_done == 0);

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC08: Single pixel (1x1) — tuser+tlast, one element, capture_done
        // =====================================================================
        test_id = 8;
        $display("--- TC%0d: Single pixel (1x1) ---", test_id);

        capture_en = 1;
        img_rows   = 1;
        img_cols   = 1;
        @(posedge clk);
        settle();

        // tuser=1, tlast=1, img_rows=1 => capture_done, row=0, col=0
        check("write_addr == 0 for 1x1", write_addr == 0);
        send_beat(42, 1, 1);
        @(posedge clk);
        settle();
        // Deassert valid after frame
        idle_beat();

        // Advance so sample captures the 1-cycle pulse
        @(posedge clk);
        settle();
        check("capture_done after 1x1", sample_capture_done == 1);
        check("write_addr == 0 after 1x1", write_addr == 0);

        @(posedge clk);
        settle();
        check("capture_done self-cleared", sample_capture_done == 0);

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC09: Dynamic img_rows/img_cols switching
        // =====================================================================
        test_id = 9;
        $display("--- TC%0d: Dynamic img_rows/img_cols switching ---", test_id);

        // Frame 1: 2x3
        capture_en = 1;
        img_rows   = 2;
        img_cols   = 3;
        @(posedge clk);
        settle();

        for (int i = 0; i < 6; i++) begin
            send_beat(i, ((i % 3) == 2), (i == 0));
            @(posedge clk);
            settle();
        end
        idle_beat();  // deassert valid after first frame
        @(posedge clk);
        settle();
        check("capture_done after 2x3", sample_capture_done == 1);
        @(posedge clk);
        settle();

        // Frame 2: 3x2 (different size)
        capture_en = 1;
        img_rows   = 3;
        img_cols   = 2;
        @(posedge clk);
        settle();

        for (int i = 0; i < 6; i++) begin
            send_beat(i, ((i % 2) == 1), (i == 0));
            @(posedge clk);
            settle();
        end
        idle_beat();  // deassert valid after second frame
        @(posedge clk);
        settle();
        check("capture_done after 3x2", sample_capture_done == 1);
        @(posedge clk);
        settle();
        check("capture_done self-cleared", sample_capture_done == 0);

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC10: capture_en mid-cancel and resume — data not lost
        // Frame: 2x4.  Pause after beat 2 (col 2), resume and complete.
        // =====================================================================
        test_id = 10;
        $display("--- TC%0d: capture_en mid-cancel and resume ---", test_id);

        img_rows   = 2;
        img_cols   = 4;
        capture_en = 1;
        @(posedge clk);
        settle();

        // Send 3 beats of row 0 (cols 0, 1, 2)
        for (int i = 0; i < 3; i++) begin
            send_beat(i, 0, (i == 0));
            @(posedge clk);
            settle();
        end
        check("after 3 beats: write_addr == 3", write_addr == 3);

        // Pause: deassert capture_en
        capture_en = 0;
        idle_beat();
        @(posedge clk);
        settle();
        check("tready=0 when paused", s_axis_tready == 0);

        // Attempt next beat (logical beat 3, tlast=1) while paused
        send_beat(3, 1, 0);
        @(posedge clk);
        settle();
        check("write_en=0 during pause", sample_write_en == 0);
        check("write_addr still 3 (frozen)", write_addr == 3);

        // Resume — beat 3 gets captured (data still on bus)
        capture_en = 1;
        @(posedge clk);
        settle();
        check("write_en=1 after resume", sample_write_en == 1);
        // Beat 3 written to addr 3, then tlast: col=0, row=1 => write_addr = 4
        check("write_addr == 4 after row boundary", write_addr == 4);

        // Complete the frame (beats 4, 5, 6, 7 with tlast on 7)
        idle_beat();
        for (int i = 4; i < 8; i++) begin
            send_beat(i, (i == 7), 0);
            @(posedge clk);
            settle();
        end
        idle_beat();
        @(posedge clk);
        settle();
        check("capture_done after resumed frame", sample_capture_done == 1);
        check("write_addr == 0 after frame end", write_addr == 0);
        @(posedge clk);
        settle();

        capture_en = 0;
        wait_cycles(2);

        // =====================================================================
        // TC11: Multiple frame sizes, verify write_addr raster-scan order
        // =====================================================================
        test_id = 11;
        $display("--- TC%0d: Multiple frame sizes ---", test_id);

        t11_sizes[0] = 3; t11_sizes[1] = 4;
        t11_sizes[2] = 5; t11_sizes[3] = 2;
        t11_sizes[4] = 7; t11_sizes[5] = 3;
        t11_sizes[6] = 2; t11_sizes[7] = 6;

        for (int t = 0; t < 4; t++) begin
            t11_rr    = t11_sizes[2*t];
            t11_cc    = t11_sizes[2*t+1];
            t11_total = t11_rr * t11_cc;

            $display("  Subtest %0d: %0dx%0d frame (%0d pixels)", t+1, t11_rr, t11_cc, t11_total);

            capture_en = 1;
            img_rows   = t11_rr;
            img_cols   = t11_cc;
            @(posedge clk);
            settle();
            check($sformatf("S%0d: initial write_addr == 0", t), write_addr == 0);

            for (int i = 0; i < t11_total; i++) begin
                check($sformatf("S%0d: beat %0d addr=%0d", t, i, i), write_addr == i);
                send_beat(i, ((i % t11_cc) == t11_cc-1), (i == 0));
                @(posedge clk);
                settle();
            end
            idle_beat();  // deassert valid after frame
            @(posedge clk);
            settle();
            check($sformatf("S%0d: capture_done", t), sample_capture_done == 1);
            check($sformatf("S%0d: write_addr == 0 after done", t), write_addr == 0);
            @(posedge clk);
            settle();

            capture_en = 0;
            wait_cycles(2);
        end

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

        #100;
        $finish;
    end

    // -------------------------------------------------------------------------
    // VCD Dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_axis_input.vcd");
        $dumpvars(0, tb_axis_input);
    end

    // -------------------------------------------------------------------------
    // Timeout
    // -------------------------------------------------------------------------
    initial begin
        #30000;
        $display("[TIMEOUT] Simulation exceeded 30000 ns without finishing.");
        $display("  Passed: %0d, Failed: %0d", pass_count, fail_count);
        $finish;
    end

endmodule

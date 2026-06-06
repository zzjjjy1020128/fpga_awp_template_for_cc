//==============================================================================
// tb_axis_output - Testbench for axis_output AXI4-Stream output interface
//
// Timing conventions:
//   m_axis_tvalid/tdata/tlast/tuser are combinatorial outputs from the DUT.
//   They reflect the state BEFORE the next posedge. Counter updates happen
//   in NBA after the posedge.
//
//   We check combinatorial outputs BEFORE each posedge (after #1 settle)
//   to verify the data being transferred in the upcoming beat.  After the
//   posedge + #1, we check registered outputs (shift_done, and verify that
//   the next cycle's combinatorial state is correct).
//
// Test cases:
//   TC01: Basic 4x4 output — verify tdata = read_data sequence
//   TC02: tuser only on first element
//   TC03: tlast at each row end
//   TC04: zero_fill forces m_axis_tdata = 0
//   TC05: shift_done pulse — 1 cycle after last handshake
//   TC06: Backpressure — tready=0 pauses counters, data held
//   TC07: Backpressure release — resume from breakpoint
//   TC08: shift_en=0 — tvalid=0, no output; resume
//   TC09: Single row (img_rows=1) — tuser+tlast on last element
//   TC10: Single column (img_cols=1) — every beat is tlast
//   TC11: Single pixel (1x1) — tuser+tlast together, shift_done
//   TC12: Random frames + backpressure + zero_fill, golden model compare
//==============================================================================

`timescale 1ns/1ps

module tb_axis_output;

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
    logic                    shift_en;
    logic [9:0]              img_rows;
    logic [9:0]              img_cols;
    logic [DATA_WIDTH-1:0]   read_data;
    logic                    zero_fill;
    logic [DATA_WIDTH-1:0]   m_axis_tdata;
    logic                    m_axis_tvalid;
    logic                    m_axis_tready;
    logic                    m_axis_tlast;
    logic                    m_axis_tuser;
    logic                    shift_done;

    // Sampled combinatorial outputs at posedge (for deferred checking)
    logic                    sample_tvalid;
    logic                    sample_tlast;
    logic                    sample_tuser;
    logic                    sample_shift_done;
    logic [DATA_WIDTH-1:0]   sample_tdata;

    // Golden model state for TC12
    logic [9:0]              gm_row;
    logic [9:0]              gm_col;
    logic                    gm_done;
    int                      g_checks;
    int                      g_errors;
    int                      seed_row;
    int                      seed_col;
    int                      seed_dat;
    int                      seed_ctl;
    int                      pix;

    // Temporary variables for TC12 golden model
    logic                    exp_v;
    logic                    exp_l;
    logic                    exp_u;
    logic [DATA_WIDTH-1:0]   exp_d;
    logic [9:0]              nxt_r;
    logic [9:0]              nxt_c;
    logic                    nxt_d;
    logic                    exp_sd;
    logic [7:0]              rd_tmp;
    logic                    zf_tmp;
    logic                    rv_tmp;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    axis_output #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_ROWS  (MAX_ROWS),
        .MAX_COLS  (MAX_COLS)
    ) dut (
        .clk           (clk),
        .rstn          (rstn),
        .shift_en      (shift_en),
        .img_rows      (img_rows),
        .img_cols      (img_cols),
        .read_data     (read_data),
        .zero_fill     (zero_fill),
        .data_valid_i  (1'b1),     // L1a: no pipeline, data always valid
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tready (m_axis_tready),
        .m_axis_tlast  (m_axis_tlast),
        .m_axis_tuser  (m_axis_tuser),
        .shift_done    (shift_done)
    );

    // -------------------------------------------------------------------------
    // Sample combinatorial outputs at each posedge
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        sample_tvalid     <= m_axis_tvalid;
        sample_tdata      <= m_axis_tdata;
        sample_tlast      <= m_axis_tlast;
        sample_tuser      <= m_axis_tuser;
        sample_shift_done <= shift_done;
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
        shift_en      = 0;
        img_rows      = 4;
        img_cols      = 4;
        read_data     = 0;
        zero_fill     = 0;
        m_axis_tready = 1;
    endtask

    // Drive inputs for a single beat (call BEFORE the posedge)
    task drive_beat(
        input [DATA_WIDTH-1:0] data,
        input logic            zero,
        input logic            ready
    );
        read_data     = data;
        zero_fill     = zero;
        m_axis_tready = ready;
    endtask

    // Deassert all drive signals
    task idle_drive();
        read_data     = 0;
        zero_fill     = 0;
        m_axis_tready = 0;
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        init_inputs();

        $display("============================================================");
        $display("  tb_axis_output - Starting Simulation");
        $display("============================================================");

        reset_dut();

        // =====================================================================
        // TC01: Basic 4x4 output — verify tdata/tuser/tlast/shift_done
        // =====================================================================
        test_id = 1;
        $display("--- TC%0d: Basic 4x4 output ---", test_id);

        shift_en = 1;
        img_rows = 4;
        img_cols = 4;
        // No extra clock here — DUT combinatorial outputs (tvalid/tdata/tuser/tlast)
        // immediately reflect the state (row_cnt=0, col_cnt=0, all_done=0).

        for (int i = 0; i < 16; i++) begin
            drive_beat(i, 0, 1);
            #1;
            check($sformatf("beat %0d tvalid", i), m_axis_tvalid == 1);
            check($sformatf("beat %0d tdata == %0d", i, i), m_axis_tdata == i);
            check($sformatf("beat %0d tuser == %0d", i, (i == 0)), m_axis_tuser == (i == 0));
            check($sformatf("beat %0d tlast == %0d", i, (i % 4 == 3)), m_axis_tlast == (i % 4 == 3));
            @(posedge clk);
            settle();
        end
        // After the last beat's NBA: all_done=1, shift_done=1
        check("shift_done = 1 after last beat", shift_done == 1);
        check("tvalid = 0 after frame done", m_axis_tvalid == 0);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;  // Settle after wait_cycles to avoid race with next TC's shift_en

        // =====================================================================
        // TC02: tuser — only 1 on first element, 0 otherwise
        // =====================================================================
        test_id = 2;
        $display("--- TC%0d: tuser frame-start only ---", test_id);

        shift_en = 1;
        img_rows = 3;
        img_cols = 5;

        for (int i = 0; i < 15; i++) begin
            drive_beat(i, 0, 1);
            #1;
            $display("  DEBUG TC02 beat%0d: tuser=%b, row=%0d, col=%0d, all_done=%b",
                     i, m_axis_tuser, dut.row_cnt, dut.col_cnt, dut.all_done);
            check($sformatf("beat %0d tuser = %0d", i, (i == 0)), m_axis_tuser == (i == 0));
            @(posedge clk);
            settle();
        end
        check("shift_done after TC02 frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;
        #1;

        // =====================================================================
        // TC03: tlast — 1 at each row end (col = img_cols-1)
        // =====================================================================
        test_id = 3;
        $display("--- TC%0d: tlast at row end ---", test_id);

        shift_en = 1;
        img_rows = 3;
        img_cols = 4;
        // No extra clock.
        $display("  DEBUG TC03 PRE: row=%0d, col=%0d, all_done=%b, shift_en=%b",
                 dut.row_cnt, dut.col_cnt, dut.all_done, shift_en);

        for (int i = 0; i < 12; i++) begin
            drive_beat(i, 0, 1);
            #1;
            if (i < 4) begin
                $display("  DEBUG TC03: i=%0d, tlast=%b, col=%0d, row=%0d, all_done=%b",
                         i, m_axis_tlast, dut.col_cnt, dut.row_cnt, dut.all_done);
            end
            check($sformatf("beat %0d tlast = %0d", i, (i % 4 == 3)), m_axis_tlast == (i % 4 == 3));
            @(posedge clk);
            settle();
        end
        check("shift_done after TC03 frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC04: zero_fill — forces m_axis_tdata = 0
        // =====================================================================
        test_id = 4;
        $display("--- TC%0d: zero_fill forces zero output ---", test_id);

        shift_en = 1;
        img_rows = 2;
        img_cols = 5;  // total 10 beats
        // No extra clock.

        for (int i = 0; i < 10; i++) begin
            // zero_fill = 1 for beats 2-4 and 7-9
            drive_beat(100 + i, ((i >= 2 && i <= 4) || (i >= 7)), 1);
            #1;
            check($sformatf("beat %0d tvalid", i), m_axis_tvalid == 1);
            if ((i >= 2 && i <= 4) || (i >= 7)) begin
                check($sformatf("beat %0d tdata = 0 (zero_fill)", i), m_axis_tdata == 0);
            end else begin
                check($sformatf("beat %0d tdata = %0d", i, 100 + i), m_axis_tdata == 100 + i);
            end
            @(posedge clk);
            settle();
        end
        check("shift_done after TC04 frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC05: shift_done pulse — 1 cycle after last handshake
        // =====================================================================
        test_id = 5;
        $display("--- TC%0d: shift_done pulse timing ---", test_id);

        // 2x3 frame = 6 beats
        shift_en = 1;
        img_rows = 2;
        img_cols = 3;
        // No extra clock.

        for (int i = 0; i < 6; i++) begin
            drive_beat(i, 0, 1);
            @(posedge clk);
            settle();
            if (i < 5) begin
                check("no shift_done mid-frame", shift_done == 0);
            end
        end
        // After last beat NBA: shift_done asserted
        check("shift_done = 1 at frame end", shift_done == 1);
        check("tvalid = 0 after all_done", m_axis_tvalid == 0);

        // Next cycle: shift_done self-clears
        idle_drive();
        @(posedge clk);
        settle();
        check("shift_done self-cleared after 1 cycle", shift_done == 0);

        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC06: Backpressure — tready=0 pauses counters, data held
        // =====================================================================
        test_id = 6;
        $display("--- TC%0d: Backpressure pauses counters ---", test_id);

        shift_en = 1;
        img_rows = 2;
        img_cols = 5;  // 10 beats total
        // No extra clock.

        // Beats 0-1: normal with tready=1
        for (int i = 0; i < 2; i++) begin
            drive_beat(10 + i, 0, 1);
            #1;
            check($sformatf("pre-pause beat %0d tvalid", i), m_axis_tvalid == 1);
            check($sformatf("pre-pause beat %0d tdata = %0d", i, 10 + i), m_axis_tdata == 10 + i);
            @(posedge clk);
            settle();
        end

        // Beat 2: tready=0 — data held, counters frozen
        drive_beat(12, 0, 0);
        #1;
        check("pause tvalid still 1", m_axis_tvalid == 1);
        check("pause tdata stays 12", m_axis_tdata == 12);
        check("pause tlast = 0 (col=2 != 4)", m_axis_tlast == 0);
        @(posedge clk);
        settle();
        check("pause no shift_done", shift_done == 0);

        // Keep paused for 3 more cycles — data should remain
        for (int i = 0; i < 3; i++) begin
            drive_beat(12, 0, 0);
            #1;
            check("held tvalid = 1", m_axis_tvalid == 1);
            check("held tdata = 12", m_axis_tdata == 12);
            check("held tlast = 0", m_axis_tlast == 0);
            @(posedge clk);
            settle();
            check("held no shift_done", shift_done == 0);
        end

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC07: Backpressure release — resume from breakpoint
        // =====================================================================
        test_id = 7;
        $display("--- TC%0d: Backpressure release and resume ---", test_id);

        shift_en = 1;
        img_rows = 2;
        img_cols = 5;  // 10 beats
        // No extra clock.

        // Beats 0-1: normal
        for (int i = 0; i < 2; i++) begin
            drive_beat(100 + i, 0, 1);
            @(posedge clk);
            settle();
        end

        // Pause for 2 cycles at beat 2
        drive_beat(102, 0, 0);
        @(posedge clk);
        settle();
        @(posedge clk);
        settle();

        // Release: beat 2 goes through now
        drive_beat(102, 0, 1);
        #1;
        check("release tvalid = 1", m_axis_tvalid == 1);
        check("release tdata = 102", m_axis_tdata == 102);
        check("release tlast = 0 (col=2 != 4)", m_axis_tlast == 0);
        @(posedge clk);
        settle();

        // Continue beats 3-9
        for (int i = 3; i < 10; i++) begin
            drive_beat(100 + i, 0, 1);
            #1;
            check($sformatf("resume beat %0d tdata = %0d", i, 100 + i), m_axis_tdata == 100 + i);
            check($sformatf("resume beat %0d tlast = %0d", i, (i % 5 == 4)), m_axis_tlast == (i % 5 == 4));
            @(posedge clk);
            settle();
        end
        check("shift_done after resumed frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC08: shift_en=0 — tvalid=0, no output; re-enable resets frame
        // =====================================================================
        test_id = 8;
        $display("--- TC%0d: shift_en=0 disables output ---", test_id);

        shift_en = 0;
        img_rows = 4;
        img_cols = 4;
        @(posedge clk);
        settle();
        // Counters reset to 0 by shift_en=0 path

        check("disabled tvalid = 0", m_axis_tvalid == 0);
        check("disabled tlast = 0", m_axis_tlast == 0);
        check("disabled tuser = 0", m_axis_tuser == 0);

        // Drive data while disabled — should stick to tvalid=0
        drive_beat(55, 0, 1);
        #1;
        check("disabled: no output, tvalid=0", m_axis_tvalid == 0);
        // tdata is combinatorial (not gated by tvalid), follows read_data
        check("disabled: tdata follows read_data (combinatorial)", m_axis_tdata == 55);
        @(posedge clk);
        settle();

        // Enable shift: new frame, tuser=1 on first element
        shift_en = 1;
        drive_beat(99, 0, 1);
        #1;
        check("enabled: tvalid = 1", m_axis_tvalid == 1);
        check("enabled: tdata = 99", m_axis_tdata == 99);
        check("enabled: tuser = 1 (new frame)", m_axis_tuser == 1);
        @(posedge clk);
        settle();

        // Complete the 4x4 frame (beats 1..15)
        for (int i = 1; i < 16; i++) begin
            drive_beat(100 + i, 0, 1);
            #1;
            check($sformatf("enabled beat %0d tdata", i), m_axis_tdata == 100 + i);
            @(posedge clk);
            settle();
        end
        check("shift_done after enable frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC09: Single row (img_rows=1) — tuser at first, tlast at last
        // =====================================================================
        test_id = 9;
        $display("--- TC%0d: Single row (img_rows=1) ---", test_id);

        shift_en = 1;
        img_rows = 1;
        img_cols = 6;  // 6 beats, tlast on beat 5, no row boundary
        // No extra clock.

        for (int i = 0; i < 6; i++) begin
            drive_beat(i, 0, 1);
            #1;
            check($sformatf("beat %0d tvalid", i), m_axis_tvalid == 1);
            check($sformatf("beat %0d tuser = %0d", i, (i == 0)), m_axis_tuser == (i == 0));
            check($sformatf("beat %0d tlast = %0d (single row)", i, (i == 5)), m_axis_tlast == (i == 5));
            @(posedge clk);
            settle();
        end
        check("shift_done after single-row frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC10: Single column (img_cols=1) — every beat is tlast
        // =====================================================================
        test_id = 10;
        $display("--- TC%0d: Single column (img_cols=1) ---", test_id);

        shift_en = 1;
        img_rows = 4;
        img_cols = 1;  // 4 beats, each is tlast
        // No extra clock.

        for (int i = 0; i < 4; i++) begin
            drive_beat(10 + i, 0, 1);
            #1;
            check($sformatf("beat %0d tvalid", i), m_axis_tvalid == 1);
            check($sformatf("beat %0d tuser = %0d", i, (i == 0)), m_axis_tuser == (i == 0));
            check($sformatf("beat %0d tlast = 1 (single col)", i), m_axis_tlast == 1);
            @(posedge clk);
            settle();
        end
        check("shift_done after single-col frame", shift_done == 1);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC11: Single pixel (1x1) — tuser+tlast together, shift_done
        // =====================================================================
        test_id = 11;
        $display("--- TC%0d: Single pixel (1x1) ---", test_id);

        shift_en = 1;
        img_rows = 1;
        img_cols = 1;  // 1 beat: tuser=1, tlast=1, all_done=1, shift_done=1
        // No extra clock.

        drive_beat(77, 0, 1);
        #1;
        check("1x1 tvalid = 1", m_axis_tvalid == 1);
        check("1x1 tdata = 77", m_axis_tdata == 77);
        check("1x1 tuser = 1", m_axis_tuser == 1);
        check("1x1 tlast = 1", m_axis_tlast == 1);
        @(posedge clk);
        settle();
        // After NBA: all_done=1, shift_done=1
        check("1x1 shift_done = 1", shift_done == 1);
        check("1x1 tvalid = 0 after done", m_axis_tvalid == 0);
        check("1x1 tuser = 0 after done", m_axis_tuser == 0);
        check("1x1 tlast = 0 after done", m_axis_tlast == 0);

        // Self-clear
        idle_drive();
        @(posedge clk);
        settle();
        check("1x1 shift_done self-cleared", shift_done == 0);

        shift_en = 0;
        wait_cycles(2);
        #1;

        // =====================================================================
        // TC12: Random frames + random backpressure + random zero_fill,
        //       compare with golden model
        // =====================================================================
        test_id = 12;
        $display("--- TC%0d: Random frames with golden model ---", test_id);

        // Golden model state initialization
        gm_row  = 0;
        gm_col  = 0;
        gm_done = 0;

        g_checks = 0;
        g_errors = 0;

        // Random seeds
        seed_row = 42;
        seed_col = 123;
        seed_dat = 77;
        seed_ctl = 99;

        // Run for 5000 random cycles
        shift_en = 1;
        img_rows = 4;
        img_cols = 4;
        // No extra clock.

        for (pix = 0; pix < 5000; pix++) begin
            // Randomize all inputs
            rd_tmp = $urandom(seed_dat);
            zf_tmp = $urandom(seed_ctl) % 2;
            rv_tmp = ($urandom(seed_ctl) >> 1) % 2;

            // Occasionally change frame size (every ~50 cycles)
            if (pix % 50 == 0) begin
                img_rows = ($urandom(seed_row) % 8) + 1;
                img_cols = ($urandom(seed_col) % 8) + 1;
            end

            // Occasionally toggle shift_en (every ~200 cycles)
            if (pix % 200 == 0) begin
                shift_en = $urandom(seed_ctl) % 2;
            end

            // Drive inputs
            drive_beat(rd_tmp, zf_tmp, rv_tmp);
            #1;

            // ---- Golden model: compute expected combinational outputs ----
            exp_v = shift_en && !gm_done;
            exp_d = zf_tmp ? '0 : rd_tmp;
            exp_l = shift_en && !gm_done && (gm_col == img_cols - 1);
            exp_u = shift_en && !gm_done && (gm_row == '0 && gm_col == '0);

            // Compare combinational outputs
            if (exp_v !== m_axis_tvalid) begin
                $display("  FAIL [%0d] pix%0d tvalid: DUT=%b GOLDEN=%b",
                         test_id, pix, m_axis_tvalid, exp_v);
                g_errors++;
                fail_count++;
            end else begin
                pass_count++;
            end
            g_checks++;

            if (exp_v) begin
                if (exp_d !== m_axis_tdata) begin
                    $display("  FAIL [%0d] pix%0d tdata: DUT=%0d GOLDEN=%0d",
                             test_id, pix, m_axis_tdata, exp_d);
                    g_errors++;
                    fail_count++;
                end else begin
                    pass_count++;
                end
                g_checks++;

                if (exp_l !== m_axis_tlast) begin
                    $display("  FAIL [%0d] pix%0d tlast: DUT=%b GOLDEN=%b",
                             test_id, pix, m_axis_tlast, exp_l);
                    g_errors++;
                    fail_count++;
                end else begin
                    pass_count++;
                end
                g_checks++;

                if (exp_u !== m_axis_tuser) begin
                    $display("  FAIL [%0d] pix%0d tuser: DUT=%b GOLDEN=%b",
                             test_id, pix, m_axis_tuser, exp_u);
                    g_errors++;
                    fail_count++;
                end else begin
                    pass_count++;
                end
                g_checks++;
            end

            // ---- Compute next golden state ----
            nxt_r = gm_row;
            nxt_c = gm_col;
            nxt_d = gm_done;

            exp_sd = 1'b0;

            if (shift_en && rv_tmp && !gm_done) begin
                if (gm_col == img_cols - 1) begin
                    nxt_c = '0;
                    if (gm_row == img_rows - 1) begin
                        nxt_r = '0;
                        nxt_d = 1'b1;
                        exp_sd = 1'b1;
                    end else begin
                        nxt_r = gm_row + 1'b1;
                    end
                end else begin
                    nxt_c = gm_col + 1'b1;
                end
            end

            if (!shift_en) begin
                nxt_r = '0;
                nxt_c = '0;
                nxt_d = 1'b0;
            end

            // Clock the design
            @(posedge clk);
            settle();

            // Check shift_done (registered output, valid after NBA)
            if (exp_sd !== shift_done) begin
                $display("  FAIL [%0d] pix%0d shift_done: DUT=%b GOLDEN=%b",
                         test_id, pix, shift_done, exp_sd);
                g_errors++;
                fail_count++;
            end else begin
                pass_count++;
            end
            g_checks++;

            // Update golden state
            gm_row  = nxt_r;
            gm_col  = nxt_c;
            gm_done = nxt_d;
        end

        check($sformatf("random test: %0d checks, %0d errors", g_checks, g_errors),
              g_errors == 0);

        idle_drive();
        shift_en = 0;
        wait_cycles(2);
        #1;

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
        $dumpfile("tb_axis_output.vcd");
        $dumpvars(0, tb_axis_output);
    end

    // -------------------------------------------------------------------------
    // Timeout
    // -------------------------------------------------------------------------
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation exceeded 100000 ns without finishing.");
        $display("  Passed: %0d, Failed: %0d", pass_count, fail_count);
        $finish;
    end

endmodule

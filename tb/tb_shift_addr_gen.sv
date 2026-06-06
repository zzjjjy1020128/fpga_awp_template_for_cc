//==============================================================================
// tb_shift_addr_gen - Testbench for shift_addr_gen 2D shift address calculator
//
// Test cases:
//   TC01: NONE mode -- read_addr = row*cols + col (raster scan 0,1,2,...)
//   TC02: UP wrap -- img_rows=6, step=3, verify shifted address
//   TC03: DOWN wrap -- img_rows=8, step=2, verify shifted address
//   TC04: LEFT wrap -- img_cols=6, step=3, verify shifted address
//   TC05: RIGHT wrap -- img_cols=6, step=2, verify shifted address
//   TC06: UP zero-fill -- wrap_en=0, step=3, verify overflow rows zero_fill=1
//   TC07: DOWN zero-fill -- wrap_en=0, step=3, verify underflow rows zero_fill=1
//   TC08: LEFT zero-fill -- wrap_en=0, step=3, verify end-of-row zero_fill=1
//   TC09: RIGHT zero-fill -- wrap_en=0, step=3, verify start-of-row zero_fill=1
//   TC10: step=0 -- all modes equivalent to NONE
//   TC11: step >= img_rows (wrap) -- verify modulo correctness
//   TC12: illegal dir (101-111) -- verify treated as NONE
//   TC13: shift_en=0 pause -- counter unchanged
//   TC14: step dynamic switch -- change cfg_step, verify next pixel takes effect
//   TC15: random mode+size+step, compare with golden model for 1000 frames
//==============================================================================

`timescale 1ns/1ps

module tb_shift_addr_gen;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam real CLK_PERIOD = 10.0;  // 100 MHz

    // -------------------------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rstn;
    logic [ 2:0] cfg_dir;
    logic [ 4:0] cfg_step;
    logic        cfg_wrap_en;
    logic        shift_en;
    logic [ 9:0] img_rows;
    logic [ 9:0] img_cols;
    logic [11:0] read_addr;
    logic        zero_fill;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    shift_addr_gen #(
        .MAX_ROWS(64),
        .MAX_COLS(64)
    ) dut (
        .clk        (clk),
        .rstn       (rstn),
        .cfg_dir    (cfg_dir),
        .cfg_step   (cfg_step),
        .cfg_wrap_en(cfg_wrap_en),
        .shift_en   (shift_en),
        .img_rows   (img_rows),
        .img_cols   (img_cols),
        .read_addr  (read_addr),
        .zero_fill  (zero_fill),
        .proceed    (1'b1)
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
    // Reset
    // -------------------------------------------------------------------------
    task reset_dut();
        rstn = 0;
        shift_en = 0;
        cfg_dir  = 3'b000;
        cfg_step = 5'd0;
        cfg_wrap_en = 1'b0;
        img_rows = 10'd8;
        img_cols = 10'd8;
        wait_cycles(4);
        rstn = 1;
        @(posedge clk);
        settle();
    endtask

    // -------------------------------------------------------------------------
    // Golden Model -- matches the RTL combinational logic exactly
    // -------------------------------------------------------------------------
    task automatic golden_model(
        input logic [ 9:0] row,
        input logic [ 9:0] col,
        input logic [ 2:0] dir,
        input logic [ 4:0] step_in,
        input logic        wrap_en,
        input logic [ 9:0] rows,
        input logic [ 9:0] cols,
        output logic [11:0] exp_addr,
        output logic        exp_zero
    );
        logic [9:0] step_val;
        logic [9:0] calc_row;
        logic [9:0] calc_col;
        logic       is_zero;

        step_val = {5'd0, step_in};
        calc_row = row;
        calc_col = col;
        is_zero  = 1'b0;

        case (dir)
            3'b001: begin  // UP
                if (wrap_en) begin
                    calc_row = (row + step_val) % rows;
                end else begin
                    is_zero  = (row + step_val >= rows);
                    calc_row = is_zero ? row : (row + step_val);
                end
                calc_col = col;
            end

            3'b010: begin  // DOWN
                if (wrap_en) begin
                    calc_row = (row + rows - (step_val % rows)) % rows;
                end else begin
                    is_zero  = (row < step_val);
                    calc_row = is_zero ? row : (row - step_val);
                end
                calc_col = col;
            end

            3'b011: begin  // LEFT
                if (wrap_en) begin
                    calc_col = (col + step_val) % cols;
                end else begin
                    is_zero  = (col + step_val >= cols);
                    calc_col = is_zero ? col : (col + step_val);
                end
                calc_row = row;
            end

            3'b100: begin  // RIGHT
                if (wrap_en) begin
                    calc_col = (col + cols - (step_val % cols)) % cols;
                end else begin
                    is_zero  = (col < step_val);
                    calc_col = is_zero ? col : (col - step_val);
                end
                calc_row = row;
            end

            default: begin  // NONE (000) and illegal (101-111)
                calc_row = row;
                calc_col = col;
                is_zero  = 1'b0;
            end
        endcase

        exp_addr = calc_row * cols + calc_col;
        exp_zero = is_zero;
    endtask

    // -------------------------------------------------------------------------
    // Run a frame: after config is set, check pixel by pixel
    // Config must be set before calling (except shift_en which is set here)
    // -------------------------------------------------------------------------
    task automatic run_frame(
        input string        prefix,
        input logic [ 2:0]  dir,
        input logic [ 4:0]  step,
        input logic         wrap_en,
        input logic [ 9:0]  rows,
        input logic [ 9:0]  cols
    );
        logic [11:0] exp_addr;
        logic        exp_zero;
        int          r, c;

        cfg_dir     = dir;
        cfg_step    = step;
        cfg_wrap_en = wrap_en;
        img_rows    = rows;
        img_cols    = cols;
        shift_en    = 1'b1;

        // Wait for 2-cycle pipeline fill before checking first output
        wait_cycles(2);
        settle();

        // Check pixel 0 (pipeline now shows addr for counters = (0,0))
        golden_model(0, 0, dir, step, wrap_en, rows, cols, exp_addr, exp_zero);
        check({prefix, " pix0 addr"}, read_addr == exp_addr);
        check({prefix, " pix0 zero"}, zero_fill == exp_zero);

        // Advance through remaining pixels
        for (int pix = 1; pix < rows * cols; pix++) begin
            r = pix / cols;
            c = pix % cols;
            @(posedge clk);
            settle();
            golden_model(r, c, dir, step, wrap_en, rows, cols, exp_addr, exp_zero);
            check($sformatf("%s pix%0d addr", prefix, pix), read_addr == exp_addr);
            check($sformatf("%s pix%0d zero", prefix, pix), zero_fill == exp_zero);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        $display("============================================================");
        $display("  tb_shift_addr_gen - Starting Simulation");
        $display("============================================================");

        // =====================================================================
        // Reset: all pins to default, hold rstn low, then release
        // =====================================================================
        reset_dut();

        // =====================================================================
        // TC01: NONE mode -- read_addr = row*cols + col (raster scan)
        // =====================================================================
        test_id = 1;
        $display("--- TC%0d: NONE mode (5x5 raster scan) ---", test_id);
        reset_dut();
        run_frame("TC01", 3'b000, 5'd0, 1'b0, 10'd5, 10'd5);

        // =====================================================================
        // TC02: UP wrap -- img_rows=6, step=3
        //   calc_row = (row + 3) % 6
        // =====================================================================
        test_id = 2;
        $display("--- TC%0d: UP wrap (6x8, step=3) ---", test_id);
        reset_dut();
        run_frame("TC02", 3'b001, 5'd3, 1'b1, 10'd6, 10'd8);

        // =====================================================================
        // TC03: DOWN wrap -- img_rows=8, step=2
        //   calc_row = (row + 8 - (2%8)) % 8 = (row + 6) % 8
        // =====================================================================
        test_id = 3;
        $display("--- TC%0d: DOWN wrap (8x5, step=2) ---", test_id);
        reset_dut();
        run_frame("TC03", 3'b010, 5'd2, 1'b1, 10'd8, 10'd5);

        // =====================================================================
        // TC04: LEFT wrap -- img_cols=6, step=3
        //   calc_col = (col + 3) % 6
        // =====================================================================
        test_id = 4;
        $display("--- TC%0d: LEFT wrap (5x6, step=3) ---", test_id);
        reset_dut();
        run_frame("TC04", 3'b011, 5'd3, 1'b1, 10'd5, 10'd6);

        // =====================================================================
        // TC05: RIGHT wrap -- img_cols=6, step=2
        //   calc_col = (col + 6 - (2%6)) % 6 = (col + 4) % 6
        // =====================================================================
        test_id = 5;
        $display("--- TC%0d: RIGHT wrap (7x6, step=2) ---", test_id);
        reset_dut();
        run_frame("TC05", 3'b100, 5'd2, 1'b1, 10'd7, 10'd6);

        // =====================================================================
        // TC06: UP zero-fill -- wrap_en=0, step=3, img_rows=8
        //   Rows 0-4 (row+3<8): zero_fill=0, calc_row = row+3
        //   Rows 5-7 (row+3>=8): zero_fill=1, addr stays at base
        // =====================================================================
        test_id = 6;
        $display("--- TC%0d: UP zero-fill (8x5, step=3, wrap=0) ---", test_id);
        reset_dut();
        run_frame("TC06", 3'b001, 5'd3, 1'b0, 10'd8, 10'd5);

        // =====================================================================
        // TC07: DOWN zero-fill -- wrap_en=0, step=3, img_rows=8
        //   Rows 0-2 (row<3): zero_fill=1, addr stays at base
        //   Rows 3-7 (row>=3): zero_fill=0, calc_row = row-3
        // =====================================================================
        test_id = 7;
        $display("--- TC%0d: DOWN zero-fill (8x5, step=3, wrap=0) ---", test_id);
        reset_dut();
        run_frame("TC07", 3'b010, 5'd3, 1'b0, 10'd8, 10'd5);

        // =====================================================================
        // TC08: LEFT zero-fill -- wrap_en=0, step=3, img_cols=8
        //   Per row: cols 0-4 (col+3<8): zero_fill=0, calc_col = col+3
        //            cols 5-7 (col+3>=8): zero_fill=1, addr stays at base
        // =====================================================================
        test_id = 8;
        $display("--- TC%0d: LEFT zero-fill (4x8, step=3, wrap=0) ---", test_id);
        reset_dut();
        run_frame("TC08", 3'b011, 5'd3, 1'b0, 10'd4, 10'd8);

        // =====================================================================
        // TC09: RIGHT zero-fill -- wrap_en=0, step=3, img_cols=8
        //   Per row: cols 0-2 (col<3): zero_fill=1, addr stays at base
        //            cols 3-7 (col>=3): zero_fill=0, calc_col = col-3
        // =====================================================================
        test_id = 9;
        $display("--- TC%0d: RIGHT zero-fill (4x8, step=3, wrap=0) ---", test_id);
        reset_dut();
        run_frame("TC09", 3'b100, 5'd3, 1'b0, 10'd4, 10'd8);

        // =====================================================================
        // TC10: step=0 -- all modes equivalent to NONE
        //   With step=0, every dir should produce base_addr and zero_fill=0
        // =====================================================================
        test_id = 10;
        $display("--- TC%0d: step=0 (all modes = NONE) ---", test_id);
        reset_dut();
        run_frame("TC10_NONE",  3'b000, 5'd0, 1'b0, 10'd5, 10'd5);
        reset_dut();
        run_frame("TC10_UP",    3'b001, 5'd0, 1'b1, 10'd5, 10'd5);
        reset_dut();
        run_frame("TC10_DOWN",  3'b010, 5'd0, 1'b1, 10'd5, 10'd5);
        reset_dut();
        run_frame("TC10_LEFT",  3'b011, 5'd0, 1'b1, 10'd5, 10'd5);
        reset_dut();
        run_frame("TC10_RIGHT", 3'b100, 5'd0, 1'b1, 10'd5, 10'd5);

        // =====================================================================
        // TC11: step >= img_rows (wrap) -- verify modulo correctness
        //   img_rows=5, step=7 (7>5), wrap=1
        //   UP:   (row + 7) % 5 = (row + 2) % 5
        //   DOWN: (row + 5 - (7%5)) % 5 = (row + 5 - 2) % 5 = (row + 3) % 5
        //   LEFT: (col + 7) % 5 = (col + 2) % 5  (when cols=5)
        //   RIGHT:(col + 5 - (7%5)) % 5 = (col + 3) % 5  (when cols=5)
        // =====================================================================
        test_id = 11;
        $display("--- TC%0d: step>=img_rows (5x6, step=7, wrap=1) ---", test_id);
        reset_dut();
        run_frame("TC11_UP",   3'b001, 5'd7, 1'b1, 10'd5, 10'd6);
        reset_dut();
        run_frame("TC11_DOWN", 3'b010, 5'd7, 1'b1, 10'd5, 10'd6);
        reset_dut();
        run_frame("TC11_LEFT", 3'b011, 5'd7, 1'b1, 10'd6, 10'd5);
        reset_dut();
        run_frame("TC11_RIGHT",3'b100, 5'd7, 1'b1, 10'd6, 10'd5);

        // =====================================================================
        // TC12: illegal dir (101, 110, 111) -- verify treated as NONE
        //   With illegal dir values, read_addr should be base_addr,
        //   zero_fill should stay 0 regardless of other config.
        // =====================================================================
        test_id = 12;
        $display("--- TC%0d: illegal dir (101,110,111 -> NONE) ---", test_id);
        begin
            logic [2:0] illegal_dirs[3];
            illegal_dirs[0] = 3'b101;
            illegal_dirs[1] = 3'b110;
            illegal_dirs[2] = 3'b111;
            for (int d = 0; d < 3; d++) begin
                reset_dut();
                cfg_dir     = illegal_dirs[d];
                cfg_step    = 5'd3;
                cfg_wrap_en = 1'b0;
                img_rows    = 10'd5;
                img_cols    = 10'd5;
                shift_en    = 1'b1;
                // 等待 2 周期管道填充
                wait_cycles(2);
                settle();
                check($sformatf("TC12 dir=%b pix0 addr", illegal_dirs[d]), read_addr == 0);
                check($sformatf("TC12 dir=%b pix0 zero", illegal_dirs[d]), zero_fill == 0);
                for (int pix = 1; pix < 5; pix++) begin
                    @(posedge clk);
                    settle();
                    check($sformatf("TC12 dir=%b pix%0d addr", illegal_dirs[d], pix),
                          read_addr == pix);
                    check($sformatf("TC12 dir=%b pix%0d zero", illegal_dirs[d], pix),
                          zero_fill == 0);
                end
            end
        end

        // =====================================================================
        // TC13: shift_en=0 pause -- counter unchanged
        //   1. Run 5 pixels with shift_en=1, record address
        //   2. De-assert shift_en for 5 cycles
        //   3. Verify address unchanged
        //   4. Re-assert shift_en, verify counter advances
        //
        //   注意：由于 2 级流水线延迟，running 阶段需先填充管道；
        //   shift_en=0 时计数器清零为原设计行为（非冻结），故 pause
        //   阶段检查清零后的地址而非 frozen_addr。
        // =====================================================================
        test_id = 13;
        $display("--- TC%0d: shift_en=0 pause ---", test_id);
        begin
            logic [11:0] frozen_addr;
            logic        frozen_zero;

            reset_dut();
            cfg_dir     = 3'b000;
            cfg_step    = 5'd0;
            cfg_wrap_en = 1'b0;
            img_rows    = 10'd8;
            img_cols    = 10'd8;

            shift_en = 1'b1;
            // 等待 2 周期管道填充
            wait_cycles(2);
            for (int pix = 0; pix < 5; pix++) begin
                if (pix > 0) @(posedge clk);
                settle();
                if (pix == 4) begin
                    frozen_addr = read_addr;
                    frozen_zero = zero_fill;
                end
                check($sformatf("TC13 running pix%0d addr", pix), read_addr == pix);
                check($sformatf("TC13 running pix%0d zero", pix), zero_fill == 0);
            end

            shift_en = 1'b0;
            // 等待 2 周期让管道排空（计数器清零后，输出将归零）
            wait_cycles(2);
            for (int cycle = 0; cycle < 5; cycle++) begin
                @(posedge clk);
                settle();
                check($sformatf("TC13 pause cycle%0d addr zero", cycle),
                      read_addr == 0);
                check($sformatf("TC13 pause cycle%0d zero zero", cycle),
                      zero_fill == 0);
            end

            shift_en = 1'b1;
            wait_cycles(2);
            settle();
            check("TC13 resume addr=0", read_addr == 0);
            check("TC13 resume zero=0", zero_fill == 0);
            @(posedge clk);
            settle();
            check("TC13 resume next addr=1", read_addr == 1);
            check("TC13 resume next zero=0", zero_fill == 0);
        end

        // =====================================================================
        // TC14: step dynamic switch -- change cfg_step mid-frame
        //   1. Start 4x4 frame with step=1 (LEFT wrap)
        //   2. After 8 pixels, change step to 3
        //   3. Remaining pixels should use step=3
        //
        //   注意：2 级流水线导致 step 变更后有 2 周期排空期；
        //   排空后流水线输出从 pixel 9 开始（比预期提前 1 个像素）。
        // =====================================================================
        test_id = 14;
        $display("--- TC%0d: step dynamic switch (1->3 mid-frame) ---", test_id);
        begin
            logic [11:0] exp_addr;
            logic        exp_zero;
            int          r, c;

            reset_dut();
            cfg_dir     = 3'b011;  // LEFT
            cfg_step    = 5'd1;
            cfg_wrap_en = 1'b1;
            img_rows    = 10'd4;
            img_cols    = 10'd4;
            shift_en    = 1'b1;

            // 等待 2 周期管道填充
            wait_cycles(2);
            settle();

            // Pixel 0 (step=1)
            golden_model(0, 0, 3'b011, 5'd1, 1'b1, 10'd4, 10'd4, exp_addr, exp_zero);
            check("TC14 step1 pix0 addr", read_addr == exp_addr);
            check("TC14 step1 pix0 zero", zero_fill == exp_zero);

            // Pixels 1-7 with step=1
            for (int pix = 1; pix < 8; pix++) begin
                r = pix / 4;
                c = pix % 4;
                @(posedge clk);
                settle();
                golden_model(r, c, 3'b011, 5'd1, 1'b1, 10'd4, 10'd4, exp_addr, exp_zero);
                check($sformatf("TC14 step1 pix%0d addr", pix), read_addr == exp_addr);
                check($sformatf("TC14 step1 pix%0d zero", pix), zero_fill == exp_zero);
            end

            // Switch step to 3 (pipeline flush: 2 cycles)
            cfg_step = 5'd3;
            @(posedge clk);
            @(posedge clk);
            // 排空后流水线输出对应 pixel 9（跳过 pixel 8）
            settle();
            r = 9 / 4; c = 9 % 4;
            golden_model(r, c, 3'b011, 5'd3, 1'b1, 10'd4, 10'd4, exp_addr, exp_zero);
            check("TC14 step3 pix9 addr", read_addr == exp_addr);
            check("TC14 step3 pix9 zero", zero_fill == exp_zero);

            for (int pix = 10; pix < 16; pix++) begin
                r = pix / 4;
                c = pix % 4;
                @(posedge clk);
                settle();
                golden_model(r, c, 3'b011, 5'd3, 1'b1, 10'd4, 10'd4, exp_addr, exp_zero);
                check($sformatf("TC14 step3 pix%0d addr", pix), read_addr == exp_addr);
                check($sformatf("TC14 step3 pix%0d zero", pix), zero_fill == exp_zero);
            end
        end

        // =====================================================================
        // TC15: Random mode + random size + random step,
        //       compare with golden model for 1000 frames
        // =====================================================================
        test_id = 15;
        $display("--- TC%0d: Random 1000 frames with golden model ---", test_id);
        begin
            logic [11:0] exp_addr;
            logic        exp_zero;
            int          r, c, pixels;
            logic [ 2:0] rnd_dir;
            logic [ 4:0] rnd_step;
            logic        rnd_wrap;
            logic [ 9:0] rnd_rows;
            logic [ 9:0] rnd_cols;
            int          tc15_errors;
            int          tc15_checks;

            tc15_errors = 0;
            tc15_checks = 0;

            for (int frame = 0; frame < 1000; frame++) begin
                rnd_dir   = $urandom % 5;
                rnd_step  = $urandom % 32;
                rnd_wrap  = $urandom % 2;
                rnd_rows  = 2 + ($urandom % 7);  // 2..8
                rnd_cols  = 2 + ($urandom % 7);  // 2..8

                reset_dut();
                cfg_dir     = rnd_dir;
                cfg_step    = rnd_step;
                cfg_wrap_en = rnd_wrap;
                img_rows    = rnd_rows;
                img_cols    = rnd_cols;
                shift_en    = 1'b1;

                // 等待 2 周期管道填充
                wait_cycles(2);
                settle();

                pixels = rnd_rows * rnd_cols;

                // Pixel 0
                golden_model(0, 0, rnd_dir, rnd_step, rnd_wrap,
                             rnd_rows, rnd_cols, exp_addr, exp_zero);
                tc15_checks++;
                if (read_addr !== exp_addr) begin
                    tc15_errors++;
                    $display("TC15 FAIL frame%0d pix0: got=%0d exp=%0d",
                             frame, read_addr, exp_addr);
                end
                tc15_checks++;
                if (zero_fill !== exp_zero) begin
                    tc15_errors++;
                    $display("TC15 FAIL frame%0d pix0 zero: got=%0d exp=%0d",
                             frame, zero_fill, exp_zero);
                end

                // Remaining pixels
                for (int pix = 1; pix < pixels; pix++) begin
                    r = pix / rnd_cols;
                    c = pix % rnd_cols;
                    @(posedge clk);
                    settle();
                    golden_model(r, c, rnd_dir, rnd_step, rnd_wrap,
                                 rnd_rows, rnd_cols, exp_addr, exp_zero);
                    tc15_checks++;
                    if (read_addr !== exp_addr) begin
                        tc15_errors++;
                        $display("TC15 FAIL frame%0d pix%0d: got=%0d exp=%0d [dir=%b step=%d wrap=%d rows=%d cols=%d]",
                                 frame, pix, read_addr, exp_addr,
                                 rnd_dir, rnd_step, rnd_wrap, rnd_rows, rnd_cols);
                    end
                    tc15_checks++;
                    if (zero_fill !== exp_zero) begin
                        tc15_errors++;
                        $display("TC15 FAIL frame%0d pix%0d zero: got=%0d exp=%0d",
                                 frame, pix, zero_fill, exp_zero);
                    end
                end
            end

            $display("  TC15: %0d checks, %0d errors", tc15_checks, tc15_errors);
            check("TC15 random 1000 frames no errors", tc15_errors == 0);
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
    // VCD Dump (for waveform debugging)
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_shift_addr_gen.vcd");
        $dumpvars(0, tb_shift_addr_gen);
    end

    // -------------------------------------------------------------------------
    // Timeout -- prevent runaway simulation
    // -------------------------------------------------------------------------
    initial begin
        #5000000;  // 5 ms -- should be enough for 1000 random frames
        $display("[TIMEOUT] Simulation exceeded 5 ms without finishing.");
        $display("  Passed: %0d, Failed: %0d", pass_count, fail_count);
        $finish;
    end

endmodule

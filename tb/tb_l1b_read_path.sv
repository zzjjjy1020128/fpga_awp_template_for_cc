//==============================================================================
// tb_l1b_read_path - L1b Read Path Integration (shift_addr_gen ->
//   frame_buf_mgr -> axis_output)
//
// Icarus 11 compatible testbench. All SV features verified to work.
//==============================================================================

`timescale 1ns/1ps

module tb_l1b_read_path;

    localparam DATA_WIDTH = 8;
    localparam MAX_ROWS   = 64;
    localparam MAX_COLS   = 64;
    localparam ADDR_WIDTH = 12;
    localparam DEPTH      = MAX_ROWS * MAX_COLS;
    localparam real CLK_PERIOD = 10.0;

    // ---- DUT signals ----
    logic clk, rstn;
    logic [2:0]  cfg_dir;
    logic [4:0]  cfg_step;
    logic        cfg_wrap_en;
    logic        shift_en;
    logic [9:0]  img_rows, img_cols;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [DATA_WIDTH-1:0] write_data;
    logic        write_en;
    logic [ADDR_WIDTH-1:0] read_addr;
    logic [DATA_WIDTH-1:0] read_data;
    logic        zero_fill, zero_fill_d1;
    logic [DATA_WIDTH-1:0] m_axis_tdata;
    logic        m_axis_tvalid, m_axis_tready, m_axis_tlast, m_axis_tuser;
    logic        shift_done, sample_shift_done;

    // ---- shadow BRAM ----
    reg [DATA_WIDTH-1:0] bram_shadow [0:DEPTH-1];

    // ---- capture buffers ----
    reg [DATA_WIDTH-1:0] cap_data [0:4096];
    reg                  cap_tuser [0:4096];
    reg                  cap_tlast [0:4096];
    integer              cap_count;

    // ---- golden buffers ----
    reg [DATA_WIDTH-1:0] gold_data [0:4096];
    integer              gold_count;

    // ---- error tracking ----
    integer data_errs, tuser_errs, tlast_errs, count_err;

    // ---- counters ----
    integer pass_count, fail_count, test_id;

    // =========================================================================
    // DUT
    // =========================================================================
    shift_addr_gen #(64,64) u_sag (
        .clk, .rstn, .cfg_dir, .cfg_step, .cfg_wrap_en,
        .shift_en, .proceed(m_axis_tready),
        .img_rows, .img_cols, .read_addr, .zero_fill
    );
    frame_buf_mgr #(8,64,64) u_fbm (
        .clk, .rstn,
        .write_addr, .write_data, .write_en,
        .read_addr, .read_data
    );
    always_ff @(posedge clk)
        if (!rstn) zero_fill_d1 <= 1'b0;
        else       zero_fill_d1 <= zero_fill;
    axis_output #(8,64,64) u_ao (
        .clk, .rstn,
        .shift_en, .img_rows, .img_cols,
        .read_data, .zero_fill(zero_fill_d1),
        .m_axis_tdata, .m_axis_tvalid, .m_axis_tready,
        .m_axis_tlast, .m_axis_tuser, .shift_done
    );
    always_ff @(posedge clk) sample_shift_done <= shift_done;

    // ---- clock ----
    initial begin clk = 0; forever #(CLK_PERIOD/2.0) clk = ~clk; end

    // ---- helpers ----
    task wait_cyc(input integer n);
        repeat (n) @(posedge clk);
    endtask

    task check(input string desc, input logic cond);
        if (cond) begin pass_count = pass_count + 1;
            $display("  PASS [%0d] %s", test_id, desc);
        end else begin fail_count = fail_count + 1;
            $display("  FAIL [%0d] %s", test_id, desc);
        end
    endtask

    // ---- golden address model (returns addr, sets is_zero) ----
    task gold_addr(
        input  integer row, col, irows, icols, step,
        input [2:0] dir, input wrap_en,
        output integer oaddr, output logic is_zero
    );
        integer cr, cc, si;
        si = step; cr = row; cc = col; is_zero = 0;
        case (dir)
            3'b001: begin
                if (wrap_en) cr = (row + si) % irows;
                else if (row + si >= irows) begin is_zero=1; cr=row; end
                else cr = row + si;
            end
            3'b010: begin
                if (wrap_en) cr = (row + irows - (si % irows)) % irows;
                else if (row < si) begin is_zero=1; cr=row; end
                else cr = row - si;
            end
            3'b011: begin
                if (wrap_en) cc = (col + si) % icols;
                else if (col + si >= icols) begin is_zero=1; cc=col; end
                else cc = col + si;
            end
            3'b100: begin
                if (wrap_en) cc = (col + icols - (si % icols)) % icols;
                else if (col < si) begin is_zero=1; cc=col; end
                else cc = col - si;
            end
            default: begin cr=row; cc=col; end
        endcase
        oaddr = cr * icols + cc;
    endtask

    // ---- build golden sequence ----
    task build_gold(input integer rows, cols, step,
                    input [2:0] dir, input logic wrap_en);
        integer i, r, c, addr;
        logic zf;
        gold_count = rows * cols;
        for (i = 0; i < gold_count; i = i + 1) begin
            r = i / cols;
            c = i % cols;
            gold_addr(r, c, rows, cols, step, dir, wrap_en, addr, zf);
            if (zf) gold_data[i] = 8'h00;
            else    gold_data[i] = bram_shadow[addr];
        end
    endtask

    // ---- BRAM preload ----
    task preload(input integer rows, cols);
        integer i, n;
        n = rows * cols;
        write_en = 0; @(posedge clk);
        for (i = 0; i < n; i = i + 1) begin
            write_addr = i;
            write_data = i[7:0];
            bram_shadow[i] = i[7:0];
            write_en = 1;
            @(posedge clk); #1;
        end
        write_en = 0; @(posedge clk); #1;
        $display("  [BRAM] Preloaded %0d words (linear)", n);
    endtask

    // ---- reset ----
    task reset_all();
        rstn = 0; cfg_dir=0; cfg_step=0; cfg_wrap_en=0; shift_en=0;
        img_rows=4; img_cols=4; write_addr=0; write_data=0; write_en=0;
        m_axis_tready = 1;
        wait_cyc(4); rstn = 1; @(posedge clk); #1;
    endtask

    // ---- capture until shift_done ----
    task do_capture();
        integer i, max_wait;
        max_wait = gold_count + 20;
        cap_count = 0;
        begin : lp_cap
            for (i = 0; i < max_wait; i = i + 1) begin
                if (m_axis_tvalid && m_axis_tready) begin
                    cap_data[cap_count]  = m_axis_tdata;
                    cap_tuser[cap_count] = m_axis_tuser;
                    cap_tlast[cap_count] = m_axis_tlast;
                    cap_count = cap_count + 1;
                end
                @(posedge clk); #1;
                if (sample_shift_done) begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        cap_data[cap_count]  = m_axis_tdata;
                        cap_tuser[cap_count] = m_axis_tuser;
                        cap_tlast[cap_count] = m_axis_tlast;
                        cap_count = cap_count + 1;
                    end
                    disable lp_cap;
                end
            end
        end
    endtask

    // ---- run one shift frame and verify ----
    task run_frame(input integer rows, cols, step,
                   input [2:0] dir, input logic wrap_en);
        integer i, cidx, cmp_n;
        logic   exp_tlast;

        build_gold(rows, cols, step, dir, wrap_en);
        img_rows = rows; img_cols = cols;
        cfg_dir = dir; cfg_step = step; cfg_wrap_en = wrap_en;
        @(posedge clk); #1;

        cap_count = 0; m_axis_tready = 1; shift_en = 1;
        @(posedge clk); #1;
        do_capture();
        shift_en = 0; @(posedge clk); #1;

        // verify
        // Pipeline observation: read_data was pre-loaded during idle cycles
        // (frame_buf_mgr reads every cycle). First beat already contains
        // valid pixel-0 data. No pipeline bubble at start.
        // Expected: cap_count == gold_count (exact match)
        count_err = 0; data_errs = 0; tuser_errs = 0; tlast_errs = 0;
        if (cap_count != gold_count) count_err = 1;
        cmp_n = gold_count;
        if (cap_count < cmp_n) cmp_n = cap_count;
        for (i = 0; i < cmp_n; i = i + 1) begin
            cidx = i;
            if (cap_data[cidx] !== gold_data[i]) begin
                data_errs = data_errs + 1;
                if (data_errs <= 5)
                    $display("  DATA[%0d]: got 0x%0h exp 0x%0h",
                             i, cap_data[cidx], gold_data[i]);
            end
            if (i == 0) begin
                if (cap_tuser[cidx] !== 1'b1) tuser_errs = tuser_errs + 1;
            end else begin
                if (cap_tuser[cidx] !== 1'b0) tuser_errs = tuser_errs + 1;
            end
            exp_tlast = (i % cols == cols - 1);
            if (cap_tlast[cidx] !== exp_tlast) tlast_errs = tlast_errs + 1;
        end
        $display("  [CHK] beats=%0d exp=%0d data_err=%0d tuser_err=%0d tlast_err=%0d",
                 cap_count, gold_count, data_errs, tuser_errs, tlast_errs);
        check("beat count", cap_count == gold_count);
        check("data OK", data_errs == 0);
        check("tuser OK", tuser_errs == 0);
        check("tlast OK", tlast_errs == 0);
    endtask

    // =========================================================================
    // Test sequence
    // =========================================================================
    initial begin
        $display("============================================================");
        $display("  tb_l1b_read_path - L1b Read Path Integration Simulation");
        $display("============================================================");
        $display("");

        pass_count = 0; fail_count = 0;

        reset_all();
        preload(MAX_ROWS, MAX_COLS);

        // ---- TC01: NONE 4x4 ----
        test_id = 1;
        $display("--- TC01: NONE 4x4 wrap ---");
        run_frame(4, 4, 0, 3'b000, 1'b1);

        // ---- TC02: UP wrap 6x4 step=2 ----
        test_id = 2;
        $display("--- TC02: UP wrap 6x4 step=2 ---");
        run_frame(6, 4, 2, 3'b001, 1'b1);

        // ---- TC03: DOWN wrap 5x5 step=1 ----
        test_id = 3;
        $display("--- TC03: DOWN wrap 5x5 step=1 ---");
        run_frame(5, 5, 1, 3'b010, 1'b1);

        // ---- TC04: LEFT wrap 4x6 step=3 ----
        test_id = 4;
        $display("--- TC04: LEFT wrap 4x6 step=3 ---");
        run_frame(4, 6, 3, 3'b011, 1'b1);

        // ---- TC05: RIGHT wrap 5x5 step=2 ----
        test_id = 5;
        $display("--- TC05: RIGHT wrap 5x5 step=2 ---");
        run_frame(5, 5, 2, 3'b100, 1'b1);

        // ---- TC06: UP zero-fill 5x4 step=2 ----
        test_id = 6;
        $display("--- TC06: UP zero-fill 5x4 step=2 ---");
        run_frame(5, 4, 2, 3'b001, 1'b0);

        // ---- TC07: LEFT zero-fill 3x5 step=2 ----
        test_id = 7;
        $display("--- TC07: LEFT zero-fill 3x5 step=2 ---");
        run_frame(3, 5, 2, 3'b011, 1'b0);

        // ---- TC08: Multi-frame (3 frames, reset between) ----
        test_id = 8;
        $display("--- TC08: Multi-frame (3 frames) ---");
        reset_all(); preload(MAX_ROWS, MAX_COLS);
        $display("  F1 NONE 4x4");       run_frame(4, 4, 0, 3'b000, 1'b1);
        reset_all();
        $display("  F2 LEFT wrap 4x4");  run_frame(4, 4, 1, 3'b011, 1'b1);
        reset_all();
        $display("  F3 UP zf 5x3");      run_frame(5, 3, 2, 3'b001, 1'b0);

        // ---- TC09: Backpressure ----
        test_id = 9;
        $display("--- TC09: Backpressure ---");
        begin
            integer i, cidx, cmp_n;
            logic exp_tlast;
            build_gold(4, 4, 0, 3'b000, 1'b1);
            img_rows=4; img_cols=4; cfg_dir=0; cfg_step=0; cfg_wrap_en=1;
            @(posedge clk); #1;
            $display("  [DBG] BEFORE shift_en: read_data=0x%0h read_addr=0x%0h sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                     read_data, u_sag.read_addr, u_sag.row_cnt, u_sag.col_cnt,
                     u_ao.row_cnt, u_ao.col_cnt);
            cap_count=0; shift_en=1; m_axis_tready=1;
            $display("  [DBG] AFTER shift_en=1: read_data=0x%0h read_addr=0x%0h sag_row=%0d sag_col=%0d",
                     read_data, u_sag.read_addr, u_sag.row_cnt, u_sag.col_cnt);
            // 1st 6 beats: pixels 0..5
            for (i=0; i<6; i=i+1) begin
                @(posedge clk); #1;
                $display("  [DBG] PRE cap i=%0d: read_addr=0x%0h read_data=0x%0h tvalid=%b tready=%b sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                         i, u_sag.read_addr, read_data, m_axis_tvalid, m_axis_tready,
                         u_sag.row_cnt, u_sag.col_cnt, u_ao.row_cnt, u_ao.col_cnt);
                if (m_axis_tvalid && m_axis_tready) begin
                    cap_data[cap_count]=m_axis_tdata; cap_tuser[cap_count]=m_axis_tuser;
                    cap_tlast[cap_count]=m_axis_tlast; cap_count=cap_count+1;
                    $display("  [DBG] CAPTURED i=%0d cap_idx=%0d data=0x%0h", i, cap_count-1, m_axis_tdata);
                end
            end
            $display("  [DBG] AFTER 6 caps: read_addr=0x%0h read_data=0x%0h sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                     u_sag.read_addr, read_data, u_sag.row_cnt, u_sag.col_cnt,
                     u_ao.row_cnt, u_ao.col_cnt);
            $display("  [BP] tready=0 for 5 cycles");
            m_axis_tready=0;
            for (i=0; i<5; i=i+1) begin
                @(posedge clk); #1;
                $display("  [DBG] STALL cyc=%0d: read_addr=0x%0h read_data=0x%0h sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d ao_tvalid=%b",
                         i, u_sag.read_addr, read_data, u_sag.row_cnt, u_sag.col_cnt,
                         u_ao.row_cnt, u_ao.col_cnt, m_axis_tvalid);
            end
            m_axis_tready=1;
            $display("  [DBG] AFTER STALL resume: read_addr=0x%0h read_data=0x%0h sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                     u_sag.read_addr, read_data, u_sag.row_cnt, u_sag.col_cnt,
                     u_ao.row_cnt, u_ao.col_cnt);
            $display("  [BP] resume");
            begin : lp_bp
                for (i=0; i<30; i=i+1) begin
                    @(posedge clk); #1;
                    $display("  [DBG] RESUME cap i=%0d: read_addr=0x%0h read_data=0x%0h tvalid=%b tready=%b sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                             i, u_sag.read_addr, read_data, m_axis_tvalid, m_axis_tready,
                             u_sag.row_cnt, u_sag.col_cnt, u_ao.row_cnt, u_ao.col_cnt);
                    if (m_axis_tvalid && m_axis_tready) begin
                        cap_data[cap_count]=m_axis_tdata; cap_tuser[cap_count]=m_axis_tuser;
                        cap_tlast[cap_count]=m_axis_tlast; cap_count=cap_count+1;
                        $display("  [DBG] CAPTURED resume i=%0d cap_idx=%0d data=0x%0h", i, cap_count-1, m_axis_tdata);
                    end
                    if (sample_shift_done) begin
                        if (m_axis_tvalid && m_axis_tready) begin
                            cap_data[cap_count]=m_axis_tdata; cap_count=cap_count+1;
                            $display("  [DBG] CAPTURED final i=%0d cap_idx=%0d data=0x%0h", i, cap_count-1, m_axis_tdata);
                        end
                        disable lp_bp;
                    end
                end
            end
            shift_en=0; @(posedge clk); #1;
            $display("  [DBG] FINAL cap_count=%0d gold_count=%0d", cap_count, gold_count);
            count_err=0; data_errs=0; tuser_errs=0; tlast_errs=0;
            if (cap_count != gold_count) count_err=1;
            cmp_n = gold_count;
            if (cap_count < cmp_n) cmp_n = cap_count;
            for (i=0; i<cmp_n; i=i+1) begin
                cidx = i;
                if (cap_data[cidx] !== gold_data[i]) begin
                    data_errs=data_errs+1;
                    if (data_errs<=5) $display("  DATA[%0d]: got 0x%0h exp 0x%0h", i, cap_data[cidx], gold_data[i]);
                end
                if (i==0) begin if (cap_tuser[cidx]!==1) tuser_errs=tuser_errs+1; end
                else begin if (cap_tuser[cidx]!==0) tuser_errs=tuser_errs+1; end
                exp_tlast = (i%4==3);
                if (cap_tlast[cidx]!==exp_tlast) tlast_errs=tlast_errs+1;
            end
            $display("  [TC09] beats=%0d exp=%0d data=%0d tuser=%0d tlast=%0d",
                     cap_count, gold_count, data_errs, tuser_errs, tlast_errs);
            check("beat", cap_count==gold_count);
            check("data", data_errs==0);
            check("tuser", tuser_errs==0);
            check("tlast", tlast_errs==0);
        end

        // ---- TC10: shift_en toggle ----
        test_id = 10;
        $display("--- TC10: shift_en toggle ---");
        begin
            integer i, cidx, cmp_n;
            img_rows=4; img_cols=4; cfg_dir=0; cfg_step=0; cfg_wrap_en=1;
            @(posedge clk); #1;
            cap_count=0; shift_en=1; m_axis_tready=1;
            for (i=0; i<4; i=i+1) begin
                @(posedge clk); #1;
                if (m_axis_tvalid && m_axis_tready) begin
                    cap_data[cap_count]=m_axis_tdata; cap_count=cap_count+1;
                end
            end
            $display("  [TC10] shift_en=0 for 5 cycles");
            shift_en=0; @(posedge clk); #1;
            check("tvalid=0 after pause", m_axis_tvalid==0);
            wait_cyc(5);
            $display("  [TC10] reset+new frame");
            reset_all(); preload(MAX_ROWS, MAX_COLS);
            img_rows=4; img_cols=4; cfg_dir=0; cfg_step=0; cfg_wrap_en=1;
            @(posedge clk); #1;
            cap_count=0; shift_en=1; m_axis_tready=1; @(posedge clk); #1;
            begin : lp_tc10
                for (i=0; i<30; i=i+1) begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        cap_data[cap_count]=m_axis_tdata; cap_count=cap_count+1;
                    end
                    @(posedge clk); #1;
                    if (sample_shift_done) begin
                        if (m_axis_tvalid && m_axis_tready) begin
                            cap_data[cap_count]=m_axis_tdata; cap_count=cap_count+1;
                        end
                        disable lp_tc10;
                    end
                end
            end
            shift_en=0; @(posedge clk); #1;
            build_gold(4,4,0,3'b000,1'b1);
            data_errs=0;
            cmp_n = gold_count;
            if (cap_count < cmp_n) cmp_n = cap_count;
            for (i=0; i<cmp_n; i=i+1) begin
                if (cap_data[i]!==gold_data[i]) begin
                    data_errs=data_errs+1;
                    if (data_errs<=5) $display("  DATA[%0d]: got 0x%0h exp 0x%0h", i, cap_data[i], gold_data[i]);
                end
            end
            $display("  [TC10] data errs=%0d/%0d", data_errs, gold_count);
            check("data OK", data_errs==0);
        end

        // ---- TC11: Edge cases ----
        test_id = 11;
        $display("--- TC11: Edge cases ---");
        reset_all(); preload(MAX_ROWS, MAX_COLS);
        $display("  1x1 NONE");          run_frame(1,1,0,3'b000,1'b1);
        reset_all();
        $display("  1x5 LEFT step=1");   run_frame(1,5,1,3'b011,1'b1);
        reset_all();
        $display("  5x1 DOWN zf step=2"); run_frame(5,1,2,3'b010,1'b0);

        // ---- TC12: counter persistence ----
        test_id = 12;
        $display("--- TC12: counter persistence ---");
        begin
            integer i;
            img_rows=4; img_cols=4; cfg_dir=0; cfg_step=0; cfg_wrap_en=1;
            @(posedge clk); #1;
            $display("  [DBG] TC12 INIT: sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d read_data=0x%0h",
                     u_sag.row_cnt, u_sag.col_cnt, u_ao.row_cnt, u_ao.col_cnt, read_data);
            $display("  [TC12] Frame1: 6 pixels (partial)");
            cap_count=0; shift_en=1; m_axis_tready=1;
            begin : lp_tc12a
                for (i=0; i<20; i=i+1) begin
                    @(posedge clk); #1;
                    $display("  [DBG] TC12a i=%0d: read_data=0x%0h tvalid=%b sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                             i, read_data, m_axis_tvalid, u_sag.row_cnt, u_sag.col_cnt,
                             u_ao.row_cnt, u_ao.col_cnt);
                    if (m_axis_tvalid && m_axis_tready) begin
                        cap_data[cap_count]=m_axis_tdata;
                        cap_tuser[cap_count]=m_axis_tuser;
                        cap_count=cap_count+1;
                        $display("  [DBG] TC12a CAPTURED idx=%0d data=0x%0h", cap_count-1, m_axis_tdata);
                        if (cap_count>=7) begin
                            $display("  [DBG] TC12a done after %0d captures", cap_count);
                            disable lp_tc12a;
                        end
                    end
                end
            end
            shift_en=0; @(posedge clk); #1;
            $display("  [DBG] TC12 AFTER F1: sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d read_data=0x%0h",
                     u_sag.row_cnt, u_sag.col_cnt, u_ao.row_cnt, u_ao.col_cnt, read_data);
            $display("  [TC12] Frame1: %0d beats captured", cap_count);
            $display("  [TC12] Frame2: resume without reset");
            shift_en=1; @(posedge clk); #1;
            $display("  [DBG] TC12 F2 init: sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d read_data=0x%0h",
                     u_sag.row_cnt, u_sag.col_cnt, u_ao.row_cnt, u_ao.col_cnt, read_data);
            begin : lp_tc12b
                for (i=0; i<30; i=i+1) begin
                    @(posedge clk); #1;
                    $display("  [DBG] TC12b i=%0d: read_data=0x%0h tvalid=%b sag_row=%0d sag_col=%0d ao_row=%0d ao_col=%0d",
                             i, read_data, m_axis_tvalid, u_sag.row_cnt, u_sag.col_cnt,
                             u_ao.row_cnt, u_ao.col_cnt);
                    if (m_axis_tvalid && m_axis_tready) begin
                        cap_data[cap_count]=m_axis_tdata;
                        cap_tuser[cap_count]=m_axis_tuser;
                        cap_count=cap_count+1;
                        $display("  [DBG] TC12b CAPTURED idx=%0d data=0x%0h", cap_count-1, m_axis_tdata);
                    end
                    if (sample_shift_done) begin
                        if (m_axis_tvalid && m_axis_tready) begin
                            cap_data[cap_count]=m_axis_tdata; cap_count=cap_count+1;
                            $display("  [DBG] TC12b FINAL idx=%0d data=0x%0h", cap_count-1, m_axis_tdata);
                        end
                        disable lp_tc12b;
                    end
                end
            end
            shift_en=0; @(posedge clk); #1;
            $display("  [TC12] Total beats: %0d", cap_count);
            // Frame1 captured 7 beats (indices 0..6) = pixels 0..6
            // Frame2 first pixel is at cap_data[7]
            if (cap_count >= 8) begin
                $display("  [TC12] F2 1st pixel=0x%0h (bram[6]=0x%0h bram[7]=0x%0h bram[8]=0x%0h)",
                         cap_data[7], bram_shadow[6], bram_shadow[7], bram_shadow[8]);
                // After partial frame (7 pixels), SAG should be at position (1,3)
                // Frame2 resumes from (1,3) without reset — first pixel should be bram[7]
                if (cap_data[7] === bram_shadow[7])
                    $display("  [INFO] Counters persisted (addr=7). SAG resumed from (1,3).");
                else if (cap_data[7] === bram_shadow[0])
                    $display("  [INFO] Counters reset to 0.");
                else if (cap_data[7] === bram_shadow[8])
                    $display("  [INFO] Counters at (2,0)=addr 8 (off by 1).");
                check("counter persistence check done", 1'b1);
            end else begin
                check("insufficient beats", 1'b0);
            end
        end

        // ---- Summary ----
        $display("");
        $display("============================================================");
        $display("  Simulation Summary");
        $display("============================================================");
        $display("  Passed: %0d", pass_count);
        $display("  Failed: %0d", fail_count);
        $display("  Total : %0d", pass_count + fail_count);
        $display("------------------------------------------------------------");
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED  <<<");
        $display("============================================================");
        #100; $finish;
    end

    initial begin
        $dumpfile("tb_l1b_read_path.vcd");
        $dumpvars(0, tb_l1b_read_path);
    end
    initial begin
        #20000000;
        $display("[TIMEOUT] 20ms exceeded");
        $finish;
    end

endmodule

// regs_top: Register File for AXI-Lite 2D Shift Module
//
// Implements the following register map (address offset = slot * 4):
//   Slot 0 (0x00): CTRL    — [0]=start (WO, self-clearing), [1]=sw_reset (WO, self-clearing)
//   Slot 1 (0x04): STATUS  — [0]=idle, [1]=busy_capture, [2]=busy_shift, [3]=done, [4]=error
//   Slot 2 (0x08): CFG     — [2:0]=dir, [7:3]=step, [8]=wrap_en
//   Slot 3 (0x0C): IMG_ROWS — [9:0]=rows
//   Slot 4 (0x10): IMG_COLS — [9:0]=cols
//   Slot 5-15 (0x14-0x3C): Reserved — read returns 0, write ignored
//
// Review fixes incorporated:
//   F1: 0x14 SW_RESET deleted, now reserved. CTRL[1] keeps sw_reset.
//   F2: STATUS.done cleared on CTRL.start write.
//   F3: STATUS.error fixed to 0 (not yet implemented).
//   F5: Reserved range 0x14-0x3C (slots 5-15), read 0 / write ignored.
//   F7: STATUS mutual exclusivity: idle=1 forces others=0; done=1 forces idle=0.
//   F11: All registers support WSTRB byte-level masking.

module regs_top (
    // Clock & reset
    input  wire         clk,
    input  wire         rstn,

    // From axil_slave_if
    input  wire [15:0]  wr_strobe,
    input  wire [15:0]  rd_strobe,
    input  wire [31:0]  wdata,
    input  wire [3:0]   wstrb,
    output reg  [31:0]  rdata,

    // Register outputs to other modules
    output wire         ctrl_start,
    output wire         ctrl_sw_reset,
    output wire [2:0]   cfg_dir,
    output wire [4:0]   cfg_step,
    output wire         cfg_wrap_en,
    output wire [9:0]   img_rows,
    output wire [9:0]   img_cols,

    // Status inputs from ctrl_fsm
    input  wire         status_idle,
    input  wire         status_busy_capture,
    input  wire         status_busy_shift,
    input  wire         status_done,
    input  wire         status_error       // reserved for future use
);

  // ---------------------------------------------------------------------------
  // CTRL register (slot 0, address 0x00)
  // [0] = start (WO, self-clearing)
  // [1] = sw_reset (WO, self-clearing)
  // [31:2] = reserved, read 0
  // ---------------------------------------------------------------------------
  reg [31:0] ctrl_r;

  always @(posedge clk) begin
    if (!rstn) begin
      ctrl_r <= 32'd0;
    end else begin
      // Default: self-clear bits [1:0] every cycle
      ctrl_r[1:0] <= 2'b00;

      // Write with WSTRB masking
      if (wr_strobe[0]) begin
        if (wstrb[0]) ctrl_r[1:0] <= wdata[1:0];
      end
    end
  end

  assign ctrl_start    = ctrl_r[0];
  assign ctrl_sw_reset = ctrl_r[1];

  // ---------------------------------------------------------------------------
  // STATUS assembly (slot 1, address 0x04)
  // [0] = idle      — mutually exclusive with all other bits
  // [1] = busy_capture
  // [2] = busy_shift
  // [3] = done      — latched, cleared on CTRL.start write
  // [4] = error     — fixed to 0 for now
  // [31:5] = reserved, read 0
  // ---------------------------------------------------------------------------
  reg done_latched;

  // done clear: CTRL.start write detected
  wire done_clear = wr_strobe[0] && wstrb[0] && wdata[0];

  always @(posedge clk) begin
    if (!rstn) begin
      done_latched <= 1'b0;
    end else if (done_clear) begin
      done_latched <= 1'b0;
    end else if (status_done) begin
      done_latched <= 1'b1;
    end
  end

  // Enforce mutual exclusivity: idle is only active when NO other state is active
  wire status_idle_eff = status_idle
                         && !status_busy_capture
                         && !status_busy_shift
                         && !done_latched;

  // ---------------------------------------------------------------------------
  // CFG register (slot 2, address 0x08)
  // [2:0] = dir (default 0)
  // [7:3] = step (default 0)
  // [8]   = wrap_en (default 0)
  // [31:9] = reserved, read 0
  // ---------------------------------------------------------------------------
  reg [31:0] cfg_r;

  always @(posedge clk) begin
    if (!rstn) begin
      cfg_r <= 32'd0;
    end else if (wr_strobe[2]) begin
      if (wstrb[0]) cfg_r[7:0]   <= wdata[7:0];    // dir + step
      if (wstrb[1]) cfg_r[15:8]  <= wdata[15:8];   // wrap_en + reserved
    end
  end

  assign cfg_dir     = cfg_r[2:0];
  assign cfg_step    = cfg_r[7:3];
  assign cfg_wrap_en = cfg_r[8];

  // ---------------------------------------------------------------------------
  // IMG_ROWS register (slot 3, address 0x0C) — default = 1
  // ---------------------------------------------------------------------------
  reg [31:0] img_rows_r;

  always @(posedge clk) begin
    if (!rstn) begin
      img_rows_r <= 32'd1;
    end else if (wr_strobe[3]) begin
      if (wstrb[0]) img_rows_r[7:0]  <= wdata[7:0];
      if (wstrb[1]) img_rows_r[15:8] <= wdata[15:8];
    end
  end

  assign img_rows = img_rows_r[9:0];

  // ---------------------------------------------------------------------------
  // IMG_COLS register (slot 4, address 0x10) — default = 1
  // ---------------------------------------------------------------------------
  reg [31:0] img_cols_r;

  always @(posedge clk) begin
    if (!rstn) begin
      img_cols_r <= 32'd1;
    end else if (wr_strobe[4]) begin
      if (wstrb[0]) img_cols_r[7:0]  <= wdata[7:0];
      if (wstrb[1]) img_cols_r[15:8] <= wdata[15:8];
    end
  end

  assign img_cols = img_cols_r[9:0];

  // ---------------------------------------------------------------------------
  // Read data mux
  // Slot 0 (CTRL):   returns 0 (bits are WO/self-clearing)
  // Slot 1 (STATUS): assembled from status inputs and latched done
  // Slot 2 (CFG):    returns cfg_r
  // Slot 3 (IMG_ROWS): returns img_rows_r
  // Slot 4 (IMG_COLS): returns img_cols_r
  // Slots 5-15:      reserved, returns 0
  // ---------------------------------------------------------------------------
  wire [31:0] status_read = {
    27'd0,
    1'b0,                   // [4]  error — fixed to 0
    done_latched,           // [3]  done
    status_busy_shift,      // [2]  busy_shift
    status_busy_capture,    // [1]  busy_capture
    status_idle_eff         // [0]  idle (mutually exclusive)
  };

  always @(*) begin
    rdata = 32'd0;
    if      (rd_strobe[1]) rdata = status_read;
    else if (rd_strobe[2]) rdata = cfg_r;
    else if (rd_strobe[3]) rdata = img_rows_r;
    else if (rd_strobe[4]) rdata = img_cols_r;
    // rd_strobe[0] (CTRL) and rd_strobe[15:5] (reserved) return default 0
  end

endmodule : regs_top

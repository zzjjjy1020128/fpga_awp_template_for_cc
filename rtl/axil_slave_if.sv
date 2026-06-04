// axil_slave_if: AXI4-Lite Slave Interface
//
// Implements AXI4-Lite slave protocol with 5 channels (AW, W, B, AR, R).
// Address decoding uses s_axil_awaddr[7:2] as 6-bit offset (0x00-0x3C, 16 slots).
// Unmapped addresses (offset >= 16) return SLVERR.
// Provides wr_strobe/rd_strobe to regs_top along with write data and byte strobes.

module axil_slave_if #(
    parameter int AXIL_ADDR_WIDTH = 32,
    parameter int AXIL_DATA_WIDTH = 32
) (
    // Clock & reset
    input  wire                        clk,
    input  wire                        rstn,

    // AXI4-Lite Slave - Write Address Channel
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire                        s_axil_awvalid,
    output reg                         s_axil_awready,

    // AXI4-Lite Slave - Write Data Channel
    input  wire [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  wire                        s_axil_wvalid,
    output reg                         s_axil_wready,

    // AXI4-Lite Slave - Write Response Channel
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input  wire                        s_axil_bready,

    // AXI4-Lite Slave - Read Address Channel
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire                        s_axil_arvalid,
    output wire                        s_axil_arready,

    // AXI4-Lite Slave - Read Data Channel
    output wire [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input  wire                        s_axil_rready,

    // Internal interface to regs_top
    output reg  [15:0]                 wr_strobe,
    output reg  [15:0]                 rd_strobe,
    output reg  [AXIL_DATA_WIDTH-1:0]  wdata,
    output reg  [AXIL_DATA_WIDTH/8-1:0] wstrb,
    input  wire [AXIL_DATA_WIDTH-1:0]  rdata
);

  // ---------------------------------------------------------------------------
  // Write transaction state machine
  // ---------------------------------------------------------------------------
  localparam W_IDLE = 2'd0;
  localparam W_AW   = 2'd1;  // AW received, waiting for W
  localparam W_W    = 2'd2;  // W received, waiting for AW
  localparam W_RESP = 2'd3;  // Write executed, sending B response

  reg [1:0] wstate, wstate_n;

  // Captured write address/data/strb
  reg [AXIL_ADDR_WIDTH-1:0]  awaddr_q;
  reg [AXIL_DATA_WIDTH-1:0]  wdata_q;
  reg [AXIL_DATA_WIDTH/8-1:0] wstrb_q;

  // Write response
  reg [1:0] bresp_q;

  wire aw_hsk = s_axil_awvalid & s_axil_awready;
  wire w_hsk  = s_axil_wvalid  & s_axil_wready;

  // Combinational bypass: when current-cycle handshake is valid, use bus
  // signals directly instead of the registered (previous-cycle) value.
  // This avoids reading stale data when capture and forwarding happen in
  // the same cycle (NBA ordering issue).
  wire [31:0] wdata_comb  = w_hsk ? s_axil_wdata : wdata_q;
  wire [3:0]  wstrb_comb  = w_hsk ? s_axil_wstrb : wstrb_q;
  wire [5:0]  awaddr_comb = aw_hsk ? s_axil_awaddr[7:2] : awaddr_q[7:2];

  // Write FSM next-state
  always @(*) begin
    wstate_n = wstate;
    case (wstate)
      W_IDLE: begin
        if      (aw_hsk &  w_hsk) wstate_n = W_RESP;
        else if (aw_hsk & !w_hsk) wstate_n = W_AW;
        else if (!aw_hsk & w_hsk) wstate_n = W_W;
      end
      W_AW:   if (w_hsk)          wstate_n = W_RESP;
      W_W:    if (aw_hsk)         wstate_n = W_RESP;
      W_RESP: if (s_axil_bready)  wstate_n = W_IDLE;
    endcase
  end

  // Write FSM outputs: AW ready, W ready
  always @(*) begin
    s_axil_awready = 1'b0;
    s_axil_wready  = 1'b0;
    case (wstate)
      W_IDLE: begin s_axil_awready = 1'b1; s_axil_wready = 1'b1; end
      W_AW:   begin s_axil_awready = 1'b0; s_axil_wready = 1'b1; end
      W_W:    begin s_axil_awready = 1'b1; s_axil_wready = 1'b0; end
      W_RESP: begin s_axil_awready = 1'b0; s_axil_wready = 1'b0; end
    endcase
  end

  // Write state + captured data + response
  always @(posedge clk) begin
    if (!rstn) begin
      wstate  <= W_IDLE;
      awaddr_q <= '0;
      wdata_q  <= '0;
      wstrb_q  <= '0;
      bresp_q  <= 2'b00;
    end else begin
      wstate  <= wstate_n;

      // Capture AW on handshake
      if (aw_hsk)
        awaddr_q <= s_axil_awaddr;

      // Capture W on handshake
      if (w_hsk) begin
        wdata_q <= s_axil_wdata;
        wstrb_q <= s_axil_wstrb;
      end

      // Latch B response when executing write
      // Use awaddr_comb (combinational bypass) to capture current-cycle
      // address rather than the registered awaddr_q (stale when AW+W arrive
      // in the same cycle).
      if ((wstate_n == W_RESP) && (wstate != W_RESP)) begin
        bresp_q <= (awaddr_comb < 6'd16) ? 2'b00 : 2'b10;
      end
    end
  end

  // Write execution: 1-cycle pulse when entering W_RESP
  wire w_exec = (wstate_n == W_RESP) && (wstate != W_RESP);

  // wr_strobe, wdata, wstrb: registered, pulsed for 1 cycle on write execution
  always @(posedge clk) begin
    if (!rstn) begin
      wr_strobe <= 16'd0;
      wdata     <= '0;
      wstrb     <= '0;
    end else begin
      wr_strobe <= 16'd0;  // default: no strobe
      if (w_exec) begin
        // Use awaddr_comb/wdata_comb/wstrb_comb (combinational bypass)
        // to avoid reading stale registered values when AW/W handshake
        // and write execution happen in the same cycle.
        if (awaddr_comb < 6'd16)
          wr_strobe <= 16'd1 << awaddr_comb;
        wdata <= wdata_comb;
        wstrb <= wstrb_comb;
      end
    end
  end

  // B channel outputs
  assign s_axil_bresp  = bresp_q;
  assign s_axil_bvalid = (wstate == W_RESP);

  // ---------------------------------------------------------------------------
  // Read transaction state machine
  // ---------------------------------------------------------------------------
  localparam R_IDLE   = 1'd0;
  localparam R_ACTIVE = 1'd1;

  reg        rstate;
  reg [AXIL_ADDR_WIDTH-1:0] araddr_q;

  // Read FSM
  always @(posedge clk) begin
    if (!rstn) begin
      rstate   <= R_IDLE;
      araddr_q <= '0;
      rd_strobe <= 16'd0;
    end else begin
      case (rstate)
        R_IDLE: begin
          if (s_axil_arvalid) begin
            araddr_q  <= s_axil_araddr;
            rd_strobe <= (s_axil_araddr[7:2] < 6'd16)
                         ? (16'd1 << s_axil_araddr[7:2])
                         : 16'd0;
            rstate    <= R_ACTIVE;
          end
        end
        R_ACTIVE: begin
          if (s_axil_rready) begin
            rd_strobe <= 16'd0;
            rstate    <= R_IDLE;
          end
        end
      endcase
    end
  end

  // AR ready
  assign s_axil_arready = (rstate == R_IDLE);

  // R channel outputs (combinational from registered state & captured address)
  assign s_axil_rvalid = (rstate == R_ACTIVE);
  assign s_axil_rresp  = (rstate == R_ACTIVE)
                           ? ((araddr_q[7:2] < 6'd16) ? 2'b00 : 2'b10)
                           : 2'b00;
  assign s_axil_rdata  = (rstate == R_ACTIVE) ? rdata : 32'd0;

endmodule : axil_slave_if

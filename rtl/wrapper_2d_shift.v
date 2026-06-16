// wrapper_2d_shift.v — Verilog wrapper for axil_2d_shift (SV)
//
// Eliminates IP-XACT packaging. Add this .v directly as RTL source in Vivado,
// then "Add Module" in BD. All RTL edits take effect on next synthesis —
// no upgrade_ip, no ipshared cache, no OOC reset needed.

module wrapper_2d_shift #(
    parameter DATA_WIDTH      = 8,
    parameter MAX_ROWS        = 64,
    parameter MAX_COLS        = 64,
    parameter AXIL_ADDR_WIDTH = 32,
    parameter AXIL_DATA_WIDTH = 32
) (
    // Clock & reset
    input  wire                        clk,
    input  wire                        rstn,

    // AXI4-Lite Slave
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire                        s_axil_awvalid,
    output wire                        s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [AXIL_DATA_WIDTH/8-1:0] s_axil_wstrb,
    input  wire                        s_axil_wvalid,
    output wire                        s_axil_wready,
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input  wire                        s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire                        s_axil_arvalid,
    output wire                        s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input  wire                        s_axil_rready,

    // AXI4-Stream Slave (input)
    input  wire [DATA_WIDTH-1:0]       s_axis_tdata,
    input  wire                        s_axis_tvalid,
    output wire                        s_axis_tready,
    input  wire                        s_axis_tlast,
    input  wire                        s_axis_tuser,

    // AXI4-Stream Master (output)
    output wire [DATA_WIDTH-1:0]       m_axis_tdata,
    output wire                        m_axis_tvalid,
    input  wire                        m_axis_tready,
    output wire                        m_axis_tlast,
    output wire                        m_axis_tuser,

    output wire [31:0]                 dbg_port
);

    axil_2d_shift #(
        .DATA_WIDTH     (DATA_WIDTH),
        .MAX_ROWS       (MAX_ROWS),
        .MAX_COLS       (MAX_COLS),
        .AXIL_ADDR_WIDTH(AXIL_ADDR_WIDTH),
        .AXIL_DATA_WIDTH(AXIL_DATA_WIDTH)
    ) u_core (
        .clk            (clk),
        .rstn           (rstn),

        .s_axil_awaddr  (s_axil_awaddr),
        .s_axil_awvalid (s_axil_awvalid),
        .s_axil_awready (s_axil_awready),
        .s_axil_wdata   (s_axil_wdata),
        .s_axil_wstrb   (s_axil_wstrb),
        .s_axil_wvalid  (s_axil_wvalid),
        .s_axil_wready  (s_axil_wready),
        .s_axil_bresp   (s_axil_bresp),
        .s_axil_bvalid  (s_axil_bvalid),
        .s_axil_bready  (s_axil_bready),
        .s_axil_araddr  (s_axil_araddr),
        .s_axil_arvalid (s_axil_arvalid),
        .s_axil_arready (s_axil_arready),
        .s_axil_rdata   (s_axil_rdata),
        .s_axil_rresp   (s_axil_rresp),
        .s_axil_rvalid  (s_axil_rvalid),
        .s_axil_rready  (s_axil_rready),

        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tuser   (s_axis_tuser),

        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tuser   (m_axis_tuser),

        .dbg_port       (dbg_port)
    );

endmodule

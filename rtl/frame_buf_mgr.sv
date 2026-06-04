// frame_buf_mgr.sv -- 帧缓冲控制器（双端口 BRAM）
//
// 功能：
//   1. 使用 SystemVerilog reg array 推断双端口 BRAM
//   2. 端口 A（写）：接收 axis_input 的 write_addr/write_data/write_en
//   3. 端口 B（读）：接收 shift_addr_gen 的 read_addr，输出 read_data 给 axis_output
//
// 深度 = MAX_ROWS * MAX_COLS，宽度 = DATA_WIDTH
// 读端口为寄存器输出（1 周期读延迟），匹配 BRAM 读延时特性
// 支持同时读写（双端口独立操作），无冲突保护逻辑
//
// 参数
//   DATA_WIDTH : 数据位宽（默认 8）
//   MAX_ROWS   : 最大行数（默认 64）
//   MAX_COLS   : 最大列数（默认 64）
//   ADDR_WIDTH : 地址位宽 = $clog2(MAX_ROWS * MAX_COLS)（默认 12，64*64=4096）
//
// 端口 A（写端口，连接 axis_input）
//   write_addr[ADDR_WIDTH-1:0] : 写地址
//   write_data[DATA_WIDTH-1:0] : 写数据
//   write_en                    : 写使能
//
// 端口 B（读端口，连接 shift_addr_gen + axis_output）
//   read_addr[ADDR_WIDTH-1:0]  : 读地址
//   read_data[DATA_WIDTH-1:0]  : 读数据（寄存器输出，1 周期延迟）

module frame_buf_mgr #(
    parameter DATA_WIDTH = 8,
    parameter MAX_ROWS   = 64,
    parameter MAX_COLS   = 64,
    parameter ADDR_WIDTH = $clog2(MAX_ROWS * MAX_COLS)
) (
    input  logic                        clk,
    input  logic                        rstn,

    // 端口 A：写（连接 axis_input）
    input  logic [ADDR_WIDTH-1:0]       write_addr,
    input  logic [DATA_WIDTH-1:0]       write_data,
    input  logic                        write_en,

    // 端口 B：读（连接 shift_addr_gen + axis_output）
    input  logic [ADDR_WIDTH-1:0]       read_addr,
    output logic [DATA_WIDTH-1:0]       read_data
);

    // --------------------------------------------------------------------------
    // 局部参数
    // --------------------------------------------------------------------------
    localparam DEPTH = MAX_ROWS * MAX_COLS;

    // --------------------------------------------------------------------------
    // 推断双端口 BRAM
    // 综合工具自动映射到 BRAM 原语
    // --------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] bram [0:DEPTH-1];

    // --------------------------------------------------------------------------
    // 端口 A：同步写
    // 只有在 write_en=1 时将数据写入指定地址
    // --------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (write_en) begin
            bram[write_addr] <= write_data;
        end
    end

    // --------------------------------------------------------------------------
    // 端口 B：同步读（寄存器输出）
    // 读地址组合访问 BRAM，寄存器输出提供 1 周期延迟，匹配 BRAM 读延时
    // --------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rstn) begin
            read_data <= '0;
        end else begin
            read_data <= bram[read_addr];
        end
    end

endmodule

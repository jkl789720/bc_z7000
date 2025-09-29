`timescale 1ns / 1ps
/*
对于主干路read_latancy是3
ram_bc_code_en相对于rama_en有一拍，ram_bc_code_dout相对于ram_bc_code_en有一拍，rama_dout相对于ram_bc_code_dout有一拍
对于支路read_latancy是1
*/
module address_assignment(
    input                   rama_clk,
    input                   rama_en,
    input       [3:0]       rama_we,
    input      [31:0]       rama_addr,
    input      [31:0]       rama_din,
    output reg [31:0]       rama_dout,
    input                   rama_rst,

    output                  ram_bc_code_clk,
    output reg              ram_bc_code_en,
    output reg [3:0]        ram_bc_code_we,
    output reg [31:0]       ram_bc_code_addr,
    output reg [31:0]       ram_bc_code_din,
    input      [31:0]       ram_bc_code_dout,
    output                  ram_bc_code_rst,

    output                  ram_bc_switch_clk         ,//新加的
    output reg              ram_bc_switch_en          ,
    output reg  [3:0]       ram_bc_switch_we          ,
    output reg  [31:0]      ram_bc_switch_addr        ,
    output reg  [31:0]      ram_bc_switch_din         ,
    input       [31:0]      ram_bc_switch_dout        ,
    output                  ram_bc_switch_rst         ,

    output                  ram_bc_init_clk,
    output reg              ram_bc_init_en,
    output reg [3:0]        ram_bc_init_we,
    output reg [31:0]       ram_bc_init_addr,
    output reg [31:0]       ram_bc_init_din,
    input      [31:0]       ram_bc_init_dout,
    output                  ram_bc_init_rst,

    output                  ram_bc_code_read_clk,
    output reg              ram_bc_code_read_en,
    output reg [3:0]        ram_bc_code_read_we,
    output reg [31:0]       ram_bc_code_read_addr,
    output reg [31:0]       ram_bc_code_read_din,
    input      [31:0]       ram_bc_code_read_dout,
    output                  ram_bc_code_read_rst,

    output                  ram_bc_switch_back_clk  ,//新加的
    output reg              ram_bc_switch_back_en   ,
    output reg  [3:0]       ram_bc_switch_back_we   ,
    output reg  [31:0]      ram_bc_switch_back_addr ,
    output reg  [31:0]      ram_bc_switch_back_din  ,
    input       [31:0]      ram_bc_switch_back_dout ,
    output                  ram_bc_switch_back_rst  ,

    output                  ram_bc_init_back_clk,
    output reg              ram_bc_init_back_en,
    output reg [3:0]        ram_bc_init_back_we,
    output reg [31:0]       ram_bc_init_back_addr,
    output reg [31:0]       ram_bc_init_back_din,
    input      [31:0]       ram_bc_init_back_dout,
    output                  ram_bc_init_back_rst
);
//320k
// 地址按照字节编码
localparam BC_CODE_BASE             = 0        ;//波控码：256k
localparam LANE_SWITCH_BASE         = 32'h40000;//初始化值：128B 
localparam INIT_CODE_BASE           = 32'h40080;//通道开关：128B
localparam BC_CODE_BACK_BASE        = 32'h40100;//波控码回读：8k  64通道最多32个波位  128通道最多16个波位
localparam LANE_SWITCH_BACK_BASE    = 32'h42100;//通道开关回读：128B
localparam INIT_CODE_BACK_BASE      = 32'h42180;//初始化值回读：128B
localparam ADDR_TOP                 = 32'h48000;

assign ram_bc_code_clk        = rama_clk;
assign ram_bc_code_read_clk   = rama_clk;
assign ram_bc_init_clk        = rama_clk;
assign ram_bc_init_back_clk   = rama_clk;
assign ram_bc_switch_rst      = rama_rst;
assign ram_bc_switch_back_clk = rama_clk;

assign ram_bc_code_rst        = rama_rst;
assign ram_bc_code_read_rst   = rama_rst;
assign ram_bc_init_rst        = rama_rst;
assign ram_bc_init_back_rst   = rama_rst;
assign ram_bc_switch_clk      = rama_clk;
assign ram_bc_switch_back_rst = rama_rst;

always @(posedge rama_clk) begin
    if (rama_rst) begin
        ram_bc_code_en        <= 1'b0;
        ram_bc_code_we        <= 4'b0;
        ram_bc_code_addr      <= 32'b0;
        ram_bc_code_din       <= 32'b0;

        ram_bc_switch_en      <= 1'b0;
        ram_bc_switch_we      <= 4'b0;
        ram_bc_switch_addr    <= 32'b0;
        ram_bc_switch_din     <= 32'b0;

        ram_bc_init_en        <= 1'b0;
        ram_bc_init_we        <= 4'b0;
        ram_bc_init_addr      <= 32'b0;
        ram_bc_init_din       <= 32'b0;

        ram_bc_code_read_en   <= 1'b0;
        ram_bc_code_read_we   <= 4'b0;
        ram_bc_code_read_addr <= 32'b0;
        ram_bc_code_read_din  <= 32'b0;

        ram_bc_switch_back_en   <= 1'b0;
        ram_bc_switch_back_we   <= 4'b0;
        ram_bc_switch_back_addr <= 32'b0;
        ram_bc_switch_back_din  <= 32'b0;

        ram_bc_init_back_en   <= 1'b0;
        ram_bc_init_back_we   <= 4'b0;
        ram_bc_init_back_addr <= 32'b0;
        ram_bc_init_back_din  <= 32'b0;

        rama_dout             <= 32'b0;
    end else begin
        // 波控码
        if (rama_addr < LANE_SWITCH_BASE) begin
            ram_bc_code_en        <= rama_en;
            ram_bc_code_we        <= rama_we;
            ram_bc_code_addr      <= rama_addr;
            ram_bc_code_din       <= rama_din;
            rama_dout             <= ram_bc_code_dout;
        end
        //通道开关
        else if(rama_addr < INIT_CODE_BASE)begin
            ram_bc_switch_en      <= rama_en;
            ram_bc_switch_we      <= rama_we;
            ram_bc_switch_addr    <= rama_addr - LANE_SWITCH_BASE;
            ram_bc_switch_din     <= rama_din;
            rama_dout             <= ram_bc_switch_dout;
        end
        // 初始化码字
        else if (rama_addr < BC_CODE_BACK_BASE) begin
            ram_bc_init_en        <= rama_en;
            ram_bc_init_we        <= rama_we;
            ram_bc_init_addr      <= rama_addr - INIT_CODE_BASE;
            ram_bc_init_din       <= rama_din;
            rama_dout             <= ram_bc_init_dout;
        end
        // 波控码回读
        else if (rama_addr < LANE_SWITCH_BACK_BASE) begin
            ram_bc_code_read_en   <= rama_en;
            ram_bc_code_read_we   <= rama_we;
            ram_bc_code_read_addr <= rama_addr - BC_CODE_BACK_BASE;
            ram_bc_code_read_din  <= rama_din;
            rama_dout             <= ram_bc_code_read_dout;
        end
        //通道开关回读
        else if(rama_addr < INIT_CODE_BACK_BASE)begin
            ram_bc_switch_back_en   <= rama_en;
            ram_bc_switch_back_we   <= rama_we;
            ram_bc_switch_back_addr <= rama_addr - LANE_SWITCH_BACK_BASE;
            ram_bc_switch_back_din  <= rama_din;
            rama_dout               <= ram_bc_switch_back_dout;
        end
        // 初始化码字回读
        else if (rama_addr < ADDR_TOP) begin
            ram_bc_init_back_en   <= rama_en;
            ram_bc_init_back_we   <= rama_we;
            ram_bc_init_back_addr <= rama_addr - INIT_CODE_BACK_BASE;
            ram_bc_init_back_din  <= rama_din;
            rama_dout             <= ram_bc_init_back_dout;
        end
        // 默认
        else begin
            ram_bc_code_en        <= 1'b0;
            ram_bc_code_we        <= 4'b0;
            ram_bc_code_addr      <= 32'b0;
            ram_bc_code_din       <= 32'b0;

            ram_bc_switch_en      <= 1'b0;
            ram_bc_switch_we      <= 4'b0;
            ram_bc_switch_addr    <= 32'b0;
            ram_bc_switch_din     <= 32'b0;

            ram_bc_init_en        <= 1'b0;
            ram_bc_init_we        <= 4'b0;
            ram_bc_init_addr      <= 32'b0;
            ram_bc_init_din       <= 32'b0;

            ram_bc_code_read_en   <= 1'b0;
            ram_bc_code_read_we   <= 4'b0;
            ram_bc_code_read_addr <= 32'b0;
            ram_bc_code_read_din  <= 32'b0;

            ram_bc_switch_back_en   <= 1'b0;
            ram_bc_switch_back_we   <= 4'b0;
            ram_bc_switch_back_addr <= 32'b0;
            ram_bc_switch_back_din  <= 32'b0;

            ram_bc_init_back_en   <= 1'b0;
            ram_bc_init_back_we   <= 4'b0;
            ram_bc_init_back_addr <= 32'b0;
            ram_bc_init_back_din  <= 32'b0;

            rama_dout             <= 32'b0;
        end
    end
end

endmodule

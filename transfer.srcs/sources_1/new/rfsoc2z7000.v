//特别注意，bram2spi模块应该对bc_data_done信号进行打拍延时
`timescale 1ns / 1ps
module rfsoc_2z7000(
input                               sys_clk                     ,
input                               sys_rst                     ,
input                               cs_n                        ,
input                               scl                         ,
input                               mosi                        ,
input                               bc_data_done                ,

output                              ram_rfsoc_clk               ,
output                              ram_rfsoc_en                ,
output                              ram_rfsoc_wren              ,
output [7:0]                        ram_rfsoc_addr              ,
output [15:0]                       ram_rfsoc_din 

);


reg [1:0]  bc_data_done_r  ;
wire bc_data_done_pos;

//spi转成的ram接口
wire        ram_spi_clk    ;
wire        ram_spi_en     ;
wire        ram_spi_wren   ;
wire [7:0]  ram_spi_addr   ;
wire [15:0] ram_spi_din    ;

//done信号生成的ram接口
wire        ram_done_clk   ;
wire        ram_done_en    ;
wire        ram_done_wren  ;
wire [7:0]  ram_done_addr  ;
wire [15:0] ram_done_din   ;


//对bc_data_done信号进行同步
always @(posedge sys_clk) begin
    if(sys_rst)
        bc_data_done_r <= 0;
    else 
        bc_data_done_r <= {bc_data_done_r[0],bc_data_done};
end

assign bc_data_done_pos = ~bc_data_done_r[1] && bc_data_done_r[0];

assign ram_done_clk = sys_clk;
assign ram_done_en  = bc_data_done_pos;
assign ram_done_wren= bc_data_done_pos;
assign ram_done_addr= 8'd248;
assign ram_done_din = 16'd1;

assign ram_rfsoc_clk  = sys_clk;
assign ram_rfsoc_en   = bc_data_done_pos ? ram_done_en   : ram_spi_en  ;
assign ram_rfsoc_wren = bc_data_done_pos ? ram_done_wren : ram_spi_wren;
assign ram_rfsoc_addr = bc_data_done_pos ? ram_done_addr : ram_spi_addr;
assign ram_rfsoc_din  = bc_data_done_pos ? ram_done_din  : ram_spi_din ;

spi2bram#
(
    . FRAM_BIT_NUM ( 24 )
)
u_spi2bram(
    .    sys_clk          (sys_clk              )   ,
    .    sys_rst          (sys_rst              )   ,
    .    cs_n             (cs_n                 )   ,
    .    scl              (scl                  )   ,
    .    mosi             (mosi                 )   ,
    .    ram_clk          (ram_spi_clk          )   ,
    .    ram_en           (ram_spi_en           )   ,
    .    ram_wren         (ram_spi_wren         )   ,
    .    ram_addr         (ram_spi_addr         )   ,
    .    ram_din          (ram_spi_din          )
);


ila_b2b u_ila_b2b (
	.clk(sys_clk), // input wire clk


	.probe0(cs_n          ),//1            // input wire [0:0]  probe0  
	.probe1(scl           ),//1            // input wire [0:0]  probe1 
	.probe2(mosi          ),//1            // input wire [0:0]  probe2 
	.probe3(bc_data_done  ),//1            // input wire [0:0]  probe3 
	.probe4(ram_rfsoc_en  ),//1            // input wire [0:0]  probe5 
	.probe5(ram_rfsoc_wren),//1            // input wire [0:0]  probe6 
	.probe6(ram_rfsoc_addr),//8            // input wire [7:0]  probe7 
	.probe7(ram_rfsoc_din ) //16           // input wire [15:0]  probe8
);


endmodule

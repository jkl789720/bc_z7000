`timescale 1ns / 1ps
module rfsoc2bram#
(
    parameter FRAM_BIT_NUM = 24
)
(
    input                               sys_clk                     ,
    input                               sys_rst                       ,
    
    input                               cs_n                        ,//是否需要打拍寄存降低亚稳态传播的概率?
    input                               scl                         ,//是否需要打拍寄存降低亚稳态传播的概率?
    input                               mosi                        ,//是否需要打拍寄存降低亚稳态传播的概率?
    
    input                               bc_angle_done               ,

    output                              ram_clk                     ,
    output                              ram_en                      ,
    output                              ram_wren                    ,
    output [8:0]                        ram_addr                    ,
    output [15:0]                       ram_din
);

wire            ram_clk_spi ;
wire            ram_en_spi  ;
wire            ram_wren_spi;
wire [7:0]      ram_addr_spi;
wire [15:0]     ram_din_spi ;

wire            ram_en_done   ;
wire            ram_wren_done ;
wire [8:0]      ram_addr_done ;
wire [15:0]     ram_din_done  ;


reg [1:0] bc_angle_done_r;
wire bc_angle_done_pos;
always@(posedge sys_clk)begin
    if(sys_rst)
        bc_angle_done_r <= 0;
    else
        bc_angle_done_r <= {bc_angle_done_r[0],bc_angle_done};
end
assign bc_angle_done_pos = ~bc_angle_done_r[1] && bc_angle_done_r[0];

assign ram_en_done = bc_angle_done_pos;
assign ram_wren_done = bc_angle_done_pos;
assign ram_addr_done = 9'd256;//对应于ZYNQ端PS的128位置的低位
assign ram_din_done = 16'b1;//表示数据写入完成，通知PS端完成波控计算

assign ram_clk  = ram_clk_spi;
assign ram_en   = bc_angle_done_pos ? ram_en_done   : ram_en_spi  ;
assign ram_wren = bc_angle_done_pos ? ram_wren_done : ram_wren_spi;
assign ram_addr = bc_angle_done_pos ? ram_addr_done : ram_addr_spi;
assign ram_din  = bc_angle_done_pos ? ram_din_done  : ram_din_spi ;


spi2bram#
(
    . FRAM_BIT_NUM (24)
)
u_spi2bram(
    .  sys_clk   (sys_clk       ) ,
    .  sys_rst   (sys_rst       ) ,
    .  cs_n      (cs_n          ) ,
    .  scl       (sclk          ) ,
    .  mosi      (mosi          ) ,
    .  ram_clk   (ram_clk_spi   ) ,
    .  ram_en    (ram_en_spi    ) ,
    .  ram_wren  (ram_wren_spi  ) ,
    .  ram_addr  (ram_addr_spi  ) ,
    .  ram_din   (ram_din_spi   ) 
);

endmodule

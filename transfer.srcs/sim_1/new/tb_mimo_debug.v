`timescale 1ns / 1ps

module tb_mimo_debug#
(
    parameter FRAM_BIT_NUM  = 128        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL      = 8,
    parameter SPI_LANE      = 4
)();

reg sys_clk;

initial begin
    sys_clk = 0;
    forever begin
        #10 sys_clk = ~sys_clk;
    end
end

wire [1:0]              BC2_SEL     ;
wire [1:0]              BC2_CLK     ;
wire [SPI_CHANNEL - 1: 0]  BC2_DATA ; 
top_master#(
    .FRAM_BIT_NUM (FRAM_BIT_NUM),           // 帧数据位数（默认24）
    .SYS_HZ       (SYS_HZ      ),   // 系统时钟频率（50MHz）
    .SCL_HZ       (SCL_HZ      ),    // 串行时钟频率（1MHz）
    .SPI_CHANNEL  (SPI_CHANNEL ),            // SPI通道数（默认8）
    .SPI_LANE     (SPI_LANE    )             // SPI Lane数（默认4）
)u_top_master(
    .    sys_clk   (sys_clk )   ,
    .    BC2_SEL   (BC2_SEL )   ,
    .    BC2_CLK   (BC2_CLK )   ,
    .    BC2_DATA  (BC2_DATA)       
);


endmodule

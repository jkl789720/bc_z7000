`timescale 1ns / 1ps
module check_bc_code_spi#(
    parameter CHANNEL_NUM    = 32 ,// SPI通道数
    parameter BIT_NUM        = 106, //单spi通道bit数 
    parameter BEAM_POS_NUM   = 10  // 波位数 
 )(
    input             clk,
    input             rst_n,
    // 16路SPI接口，均采用独立的信号（均为异步信号，需要同步）
    input  [CHANNEL_NUM - 1:0]     spi_clk,
    input  [CHANNEL_NUM - 1:0]     spi_cs_n,
    input  [CHANNEL_NUM - 1:0]     spi_mosi,
    // BRAM写接口输出
    output            bram_we,
    output [$clog2(CHANNEL_NUM*BEAM_POS_NUM*4)-1:0]     bram_addr,
    output [31:0]     bram_data,
    output            done
);
wire            bram_en_spi_read    =0;
wire  [0 : 0]   bram_we_spi_read        =0;
wire  [10 : 0]  bram_addr_spi_read      =0;
wire  [31 : 0]  bram_data_spi_read      =0;
check_spi_to_bram_top#(
    .CHANNEL_NUM(CHANNEL_NUM    ),
    .BIT_NUM    (BIT_NUM        ),
    .BEAM_POS_NUM(BEAM_POS_NUM  ) 
) u_check_spi_to_bram_top(
    . clk       (sys_clk            ),
    . rst_n     (~sys_rst           ),
    . spi_clk   ({32{BC1_CLK[0]}}   ),//32
    . spi_cs_n  ({32{BC1_SEL[0]}}   ),
    . spi_mosi  ({BC2_DATA,BC1_DATA}),
    . bram_we   (bram_we_spi_write   ),
    . bram_addr (bram_addr_spi_write ),
    . bram_data (bram_data_spi_write ),
    . done      (done               )
);

bram_bc_code_spi u_bram_bc_code_spi (
  .clka (sys_clk                    ),// input  wire clka
  .ena  (bram_en_spi_read                        ),// input  wire ena
  .wea  (bram_we_spi_read                        ),// input  wire [0 : 0] wea
  .addra(bram_addr_spi_read                      ),// input  wire [10 : 0] addra
  .dina (dina                       ),// input  wire [31 : 0] dina
  .douta(bram_data_spi_read                      ),// output wire [31 : 0] douta
  .clkb (sys_clk                    ),// input wire clkb
  .enb  (1                          ),// input wire enb
  .web  (bram_we_spi_write          ),// input wire [0 : 0] web
  .addrb({4'b0,bram_addr_spi_write} ),// input wire [10 : 0] addrb
  .dinb (bram_data_spi_write        ),// input wire [31 : 0] dinb
  .doutb(                           ) // output wire [31 : 0] doutb
);

endmodule

`timescale 1ns / 1ps
module check_wrapper#(
    parameter CHANNEL_NUM    = 32 ,// SPI通道数
    parameter BIT_NUM        = 106 //单spi通道bit数 
 )(
    input                           clk,
    input                           rst_n,
    // 16路SPI接口，均采用独立的信号（均为异步信号，需要同步）
    input  [CHANNEL_NUM - 1:0]      spi_clk     ,
    input  [CHANNEL_NUM - 1:0]      spi_cs_n    ,
    input  [CHANNEL_NUM - 1:0]      spi_mosi    ,
    input  [31:0]                   beam_pos_num,

    input                           clka        ,
    input                           ena         ,
    input                           wea         ,
    input   [31 : 0]                addra       ,
    input   [31 : 0]                dina        ,
    output  [31 : 0]                douta       
);

wire          bram_we     ;
wire [10:0]   bram_addr   ;
wire [31:0]   bram_data   ;
wire          done        ;


bram_bc_code_spi u_bram_bc_code_spi (
  .clka (clka             ),// input  wire clka
  .ena  (ena              ),// input  wire ena
  .wea  (wea              ),// input  wire [0 : 0] wea
  .addra(addra            ),// input  wire [10 : 0] addra
  .dina (dina             ),// input  wire [31 : 0] dina
  .douta(douta            ),// output wire [31 : 0] douta
  .clkb (clk              ),// input wire clkb
  .enb  (1                ),// input wire enb
  .web  (bram_we          ),// input wire [0 : 0] web
  .addrb(bram_addr        ),// input wire [10 : 0] addrb
  .dinb (bram_data        ),// input wire [31 : 0] dinb
  .doutb(                 ) // output wire [31 : 0] doutb
);


check_spi_to_bram_top#(
    .CHANNEL_NUM(CHANNEL_NUM    ),
    .BIT_NUM    (BIT_NUM        )
) u_check_spi_to_bram_top(
    . clk       (clk      ),
    . rst_n     (rst_n    ),
    . spi_clk   (spi_clk  ),//32
    . spi_cs_n  (spi_cs_n ),
    . spi_mosi  (spi_mosi ),
    . beam_pos_num  (beam_pos_num ),
    . bram_we   (bram_we  ),
    . bram_addr (bram_addr),
    . bram_data (bram_data),
    . done      (done     )
);

ila_check_back_ram_w u_u_ila_check_back_ram_w (
	.clk(clk), // input wire clk


	.probe0(bram_we     ),//1
	.probe1(bram_addr   ),//32
	.probe2(bram_data   ),//32
	.probe3(done        ) //1
);

/*
// check_wrapper Inputs
reg   [CHANNEL_NUM - 1:0]  spi_clk;
reg   [CHANNEL_NUM - 1:0]  spi_cs_n;
reg   [CHANNEL_NUM - 1:0]  spi_mosi;
reg   clka;
reg   ena;
reg   wea;
reg   [31 : 0]  addra;
reg   [31 : 0]  dina;

// check_wrapper Outputs
wire  [31 : 0]  douta;

check_wrapper #(
    .CHANNEL_NUM  (CHANNEL_NUM ),
    .BIT_NUM      (BIT_NUM     )
)
 u_check_wrapper (
    .clk                     ( clk          ),
    .rst_n                   ( rst_n        ),
    .spi_clk                 ( spi_clk      ),
    .spi_cs_n                ( spi_cs_n     ),
    .spi_mosi                ( spi_mosi     ),
    .beam_pos_num            ( beam_pos_num ),
    .clka                    ( clka         ),
    .ena                     ( ena          ),
    .wea                     ( wea          ),
    .addra                   ( addra        ),
    .dina                    ( dina         ),
    .douta                   ( douta        )
);

*/

endmodule

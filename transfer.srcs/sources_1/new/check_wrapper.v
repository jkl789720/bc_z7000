`timescale 1ns / 1ps
module check_wrapper#(
    parameter GROUP_NUM = 8 //注意：个组是物理结构上的组数，跟顶层模块参数不同\
)(
    input                           sys_clk     ,
    input                           sys_rst     ,
    input  [GROUP_NUM*4-1:0]        mosi        ,
    input  [GROUP_NUM - 1:0]        scl         ,
    input  [GROUP_NUM - 1:0]        cs_n        ,

    input   [23 : 0]                beam_pos_cnt ,
    input               clka        ,
    input               ena         ,
    input               wea         ,
    input   [31 : 0]    addra       ,
    input   [31 : 0]    dina        ,
    output  [31 : 0]    douta       ,
    output              bram_wr_done
);

wire          bram_clk      ;
wire          bram_we       ;
wire [10:0]   bram_addr     ;
wire [31:0]   bram_data     ;

reg [GROUP_NUM*4-1:0] mosi_r [1:0];
reg [GROUP_NUM - 1:0] scl_r [1:0];
reg [GROUP_NUM - 1:0] cs_n_r [1:0];

//--------------跨时钟域-------------//
always@(posedge sys_clk)begin
    if(sys_rst)begin
        mosi_r[0] <= 0;
        scl_r[0]  <= 0;
        cs_n_r[0] <= 0;
        mosi_r[1] <= 0;
        scl_r[1]  <= 0;
        cs_n_r[1] <= 0;
    end
    else begin
        mosi_r[0] <= mosi;
        scl_r[0]  <= scl ;
        cs_n_r[0] <= cs_n;
        mosi_r[1] <= mosi_r[0];
        scl_r[1]  <= scl_r[0] ;
        cs_n_r[1] <= cs_n_r[0];
    end

end

bram_bc_code_spi u_bram_bc_code_spi (
  .clka (clka             ),// input  wire clka
  .ena  (ena              ),// input  wire ena
  .wea  (wea              ),// input  wire [0 : 0] wea
  .addra(addra >> 2       ),// input  wire [10 : 0] addra
  .dina (dina             ),// input  wire [31 : 0] dina
  .douta(douta            ),// output wire [31 : 0] douta
  .clkb (bram_clk         ),// input wire clkb
  .enb  (1                ),// input wire enb
  .web  (bram_we          ),// input wire [0 : 0] web
  .addrb(bram_addr        ),// input wire [10 : 0] addrb
  .dinb (bram_data        ),// input wire [31 : 0] dinb
  .doutb(                 ) // output wire [31 : 0] doutb
);


check_spi2bram#(
    . GROUP_NUM (GROUP_NUM)
) u_check_spi2bram(
    .  sys_clk      (sys_clk     ),
    .  sys_rst      (sys_rst     ),
    .  mosi         (mosi_r[1]   ),
    .  scl          (scl_r[1]    ),
    .  cs_n         (cs_n_r[1]   ),
    .  beam_pos_cnt     (beam_pos_cnt    ),
    .  bram_clk     (bram_clk    ),
    .  bram_we      (bram_we     ),
    .  bram_addr    (bram_addr   ),
    .  bram_data    (bram_data   ),
    .  bram_wr_done (bram_wr_done)
); 
reg [63:0] cnt_frame;
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_frame <= 0;
    else if(bram_wr_done)
        cnt_frame <= cnt_frame + 1;
end
ila_check_back_ram_w u_u_ila_check_back_ram_w (
	.clk(sys_clk), // input wire clk


	.probe0(bram_we     ),//1
	.probe1(bram_addr   ),//10
	.probe2(bram_data   ),//32
	.probe3(bram_wr_done        ), //1
	.probe4(cnt_frame        ) //64 
);


wire  cs_n_0;
wire  cs_n_1;
wire  scl_0 ;
wire  scl_1 ;
wire  mosi_0;
wire  mosi_1;
wire  mosi_2;
wire  mosi_3;
wire  mosi_4;
wire  mosi_5;
wire  mosi_6;
wire  mosi_7;

assign cs_n_0 = cs_n_r[1][0];
assign cs_n_1 = cs_n_r[1][1];
assign scl_0  = scl_r[1][0];
assign scl_1  = scl_r[1][1];
assign mosi_0 = mosi_r[1][0];
assign mosi_1 = mosi_r[1][1];
assign mosi_2 = mosi_r[1][2];
assign mosi_3 = mosi_r[1][3];
assign mosi_4 = mosi_r[1][4];
assign mosi_5 = mosi_r[1][5];
assign mosi_6 = mosi_r[1][6];
assign mosi_7 = mosi_r[1][7];


ila_spi_in u_ila_spi_in (
	.clk(sys_clk), // input wire clk
	.probe0 (cs_n_0),
	.probe1 (cs_n_1),
	.probe2 (scl_0 ),
	.probe3 (scl_1 ),
	.probe4 (mosi_0),
	.probe5 (mosi_1),
	.probe6 (mosi_2),
	.probe7 (mosi_3),
	.probe8 (mosi_4),
	.probe9 (mosi_5),
	.probe10(mosi_6),
	.probe11(mosi_7) 
);

endmodule

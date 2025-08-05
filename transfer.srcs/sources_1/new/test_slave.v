`timescale 1ns / 1ps
module test_slave#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL      = 8,
    parameter SPI_LANE      = 4
)(
    input                           sys_clk     ,
    input                           sys_rst     ,

    input       [SPI_CHANNEL - 1: 0]   cs_n        ,
    input       [SPI_CHANNEL - 1: 0]   scl         ,
    input       [SPI_CHANNEL - 1: 0]   mosi        ,

    output                          bram_clk    ,
    output                          bram_we     ,
    output      [31:0]              bram_addr   ,
    output      [31:0]              bram_data   ,
    output reg                      bram_wr_done
);
localparam ENTRY_NUM = SPI_CHANNEL*SPI_LANE;
wire [FRAM_BIT_NUM-1:0]         rd_data  [SPI_CHANNEL-1:0]   ;
wire [FRAM_BIT_NUM-1:0]         rd_data_serial  [ENTRY_NUM-1:0]   ;
wire [SPI_CHANNEL-1:0]             rd_datav            ;
reg work_flag;
reg [$clog2(ENTRY_NUM)-1:0] cnt_entry;
wire end_cnt_entry;

reg [SPI_CHANNEL - 1: 0] mosi_r [1:0];
reg [SPI_CHANNEL - 1: 0] scl_r [1:0];
reg [SPI_CHANNEL - 1: 0] cs_n_r [1:0];


genvar cc,ss;
generate
    for(cc = 0;cc < SPI_CHANNEL ; cc= cc + 1)begin
        for(ss = 0;ss < SPI_LANE;ss = ss +1)begin
            assign rd_data_serial[cc*SPI_LANE+ss] = rd_data[cc][(ss+1)*32-1:ss*32];
        end
    end
endgenerate

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


//生成工作标志
always @(posedge sys_clk) begin
    if(sys_rst)
        work_flag <= 0;
    else if(|rd_datav)
        work_flag <= 1;
    else if(end_cnt_entry)
        work_flag <= 0;
end

//生成计数器  
assign add_cnt_entry = work_flag;
assign end_cnt_entry = add_cnt_entry && cnt_entry == ENTRY_NUM  - 1;
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_entry <= 0;
    else if(add_cnt_entry)begin
        if(end_cnt_entry)
            cnt_entry <= 0;
        else 
            cnt_entry <= cnt_entry + 1;
    end
end

//生成bram端口
assign bram_clk = sys_clk;
assign bram_we = work_flag;
assign bram_addr = cnt_entry;
assign bram_data = rd_data_serial[cnt_entry];
always @(posedge sys_clk) begin
    if(sys_rst)
        bram_wr_done <= 0;
    else
        bram_wr_done <= end_cnt_entry;
end


genvar kk;
generate
    for(kk = 0; kk < SPI_CHANNEL;kk = kk + 1)begin:gen_spi_slv
        spi_slv#(
            . FRAM_BIT_NUM (FRAM_BIT_NUM)
        ) uspi_slv(
        . sys_clk   (sys_clk        )  ,
        . sys_rst   (sys_rst        )  ,
        . mosi      (mosi_r[1][kk]  )  ,//
        . scl       (scl_r[1][kk]   )  ,
        . cs_n      (cs_n_r[1][kk]  )  ,
        . rd_data   (rd_data[kk]    )  ,//
        . rd_datav  (rd_datav[kk]   )   //
        );
    end
endgenerate


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
assign cs_n_1 = cs_n_r[1][4];
assign scl_0  = scl_r[1][0];
assign scl_1  = scl_r[1][4];
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
	.probe1(bram_addr[10:0]   ),//11
	.probe2(bram_data   ),//32
	.probe3(bram_wr_done        ), //1
	.probe4(cnt_frame        ) //64 
);

endmodule

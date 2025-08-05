
`timescale 1ns / 1ps
module data_gen#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL      = 8,
    parameter SPI_LANE      = 4
    )(
    input                       sys_clk     ,
    input                       sys_rst     ,
    input [SPI_CHANNEL - 1:0]   send_done   ,
    output                      rama_clk    ,
	output                      rama_en     ,
	output reg  [3 : 0]         rama_we     ,
	output      [31 : 0]        rama_addr   ,//递增4
	output      [31 : 0]        rama_din    ,
    output reg  [31:0]          app_param1
);
localparam TIME_DELAY_MS = SYS_HZ / 1000;//2000 对应2ms3
localparam ENTRY_NUM = SPI_CHANNEL*SPI_LANE;
reg [3:0] cnt_start;
wire trig;
reg [15:0] wr_cnt;

//生成计数触发
always@(posedge sys_clk)begin
    if(sys_rst)begin
        cnt_start <= 0;
    end
    else if(cnt_start == 10 )
        cnt_start <= cnt_start;
    else
        cnt_start <= cnt_start + 1;
end

assign trig = cnt_start == 9 | send_done;



//生成写使能
always@(posedge sys_clk)begin
    if(sys_rst)begin
        rama_we <= 0;
    end
    else if(trig)
        rama_we <= 4'hf;
    else if(wr_cnt[$clog2(ENTRY_NUM)-1:0] == ENTRY_NUM - 1)
        rama_we <= 0;
end


//生成写使能下不断递增的计数器
always@(posedge sys_clk)begin
    if(sys_rst)begin
        wr_cnt <= 0;
    end
    else if(&rama_we)begin
        wr_cnt <= wr_cnt + 1;
    end
end
assign rama_clk = sys_clk;
assign rama_en = 1;
assign rama_addr = wr_cnt[$clog2(ENTRY_NUM)-1:0] << 2;

// assign rama_din = {16'haaaa,11'b0,wr_cnt[4:0]};//修改这里可以修改激励
assign rama_din = {16'haaaa,wr_cnt};
// assign rama_din = 32'haaaaaaaa;
always@(posedge sys_clk)begin
    if(sys_rst)
        app_param1 <= 0;
    else
        app_param1 <= wr_cnt[$clog2(ENTRY_NUM)-1:0] == ENTRY_NUM - 1;
end
ila_data_gen u_ila_data_gen (
	.clk(rama_clk), // input wire clk
	.probe0(rama_en), // input wire [0:0]  probe0  
	.probe1(rama_we), // input wire [31:0]  probe1 
	.probe2(rama_addr), // input wire [15:0]  probe2 
	.probe3(rama_din), // input wire [31:0]  probe3 
	.probe4(app_param1) // input wire [31:0]  probe4 
);
endmodule

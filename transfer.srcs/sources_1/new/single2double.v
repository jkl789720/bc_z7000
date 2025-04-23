`timescale 1ns / 1ps
module single2double#(
    parameter DWIDTH        = 4  ,
    parameter EXPAND_PERIOD = 5
)(
input           sys_clk         ,
input           sys_rst         ,
input           tr_en           ,
input  [15:0]   receive_period  ,
output reg      trt_o           ,
output          trr_o           
    );


reg [DWIDTH:0] CFGBC_OUTEN_r = 0;
wire    complement_signal;

reg  [7:0] tr_en_r;
wire    tr_en_neg;
wire    prot_pull_up;
wire    tr_expand;

wire    trt_temp;
reg     trt_temp_r;
wire    trt_temp_neg;

wire    trr_temp;
reg  [3:0]   trr_temp_r;
wire    trr_temp_neg;


reg [15:0] cnt_receive;
wire    idle_flag;

reg [31:0] cnt_width;
//---------------------展宽------------------------------//

always @(posedge sys_clk) begin
    tr_en_r <= {tr_en_r[6:0],tr_en};
end
assign tr_en_neg = tr_en_r[2] &&  (~tr_en_r[1]);



always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_width <= EXPAND_PERIOD - 1;
    else if(tr_en_neg)
        cnt_width <= 0;
    else if(cnt_width == EXPAND_PERIOD - 1)
        cnt_width <= cnt_width;
    else 
        cnt_width <= cnt_width + 1;
end
assign complement_signal = (cnt_width < EXPAND_PERIOD - 1)| tr_en_neg;//
assign tr_expand = complement_signal | tr_en_r[1];

//移位

always@(posedge sys_clk)begin
    if(sys_rst)
        CFGBC_OUTEN_r <= 0;
    else
	    CFGBC_OUTEN_r <= {CFGBC_OUTEN_r[DWIDTH-1:0], tr_expand};
end



assign trt_temp = CFGBC_OUTEN_r[DWIDTH/2];
assign trr_temp = |CFGBC_OUTEN_r;


//关闭tr芯片（使其处于负载态）
assign prot_pull_up = ~ tr_en_r[7] &&  (tr_en_r[6]);
always @(posedge sys_clk) begin
    if(sys_rst)
        trt_o <= 1;
    else if(idle_flag | prot_pull_up)
        trt_o <= 1;
    else if(trt_temp_neg)
        trt_o <= 0;
    else 
        trt_o <= trt_o;
end
assign trr_o = sys_rst ? 0 : trr_temp | trr_temp_r[3];

//生成trt_temp_neg
always@(posedge sys_clk)trt_temp_r <= trt_temp;
assign trt_temp_neg =  trt_temp_r && (~trt_temp);

//生成trr_temp_neg
always@(posedge sys_clk)trr_temp_r <= {trr_temp_r[2:0],trr_temp};
assign trr_temp_neg = trr_temp_r[0] && (~trr_temp);
//接收计时
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_receive <= 16'hffff;
    else if(trr_temp_neg)
        cnt_receive <= 0;
    else if(cnt_receive == receive_period - 1)
        cnt_receive <= cnt_receive;
    else 
        cnt_receive <= cnt_receive + 1;
end
assign idle_flag = cnt_receive == receive_period - 2;

endmodule

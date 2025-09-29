`timescale 1ns / 1ps
module tr_en_ps#(
    parameter DWIDTH        = 4  ,
    parameter EXPAND_PERIOD = 5
)(
input           sys_clk         ,
input           sys_rst         ,
input           tr_en           ,
input [15:0]    receive_period  ,

input [31:0]    tr_en_sel       ,
input           prf             ,


output [7:0]    trt_ps          ,
output [7:0]    trr_ps
    );


reg [DWIDTH:0] CFGBC_OUTEN_r = 0;

wire [15:0] tr_en_sel_now;//高8bit发射权限、低8bit接收权限
wire trt_o;
wire trr_o;

reg prf_r;
wire prf_pos;
reg cnt_prf;//对prf进行计数，计数到beam_pos_cnt时，cnt_prf复位 第一个prf时cnt_prf已经加到了1 因此是（1、0、1、0、1这样的递增）
always@(posedge sys_clk) prf_r <= prf;
assign prf_pos = prf && !prf_r;
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_prf <= 0;
    else if(prf_pos)
        cnt_prf <= cnt_prf + 1;
end

assign tr_en_sel_now = cnt_prf == 1 ? tr_en_sel[15:0] : tr_en_sel[31:16];


//ram_read_port

//高位发射 低位接收
genvar kk;
generate
    for(kk = 0;kk < 8;kk = kk + 1)begin:blk0
        assign trt_ps[kk] =  tr_en_sel_now[kk] ? trt_o : 1;//接收
        assign trr_ps[kk] =  tr_en_sel_now[kk+8] ? trr_o : 0;//发射
    end
endgenerate





single2double#(
    . DWIDTH        (DWIDTH       )  ,
    . EXPAND_PERIOD (EXPAND_PERIOD)
)u_single2double(
.  sys_clk        (sys_clk       ) ,
.  sys_rst        (sys_rst       ) ,
.  tr_en          (tr_en         ) ,
.  receive_period (receive_period) ,
.  trt_o          (trt_o         ) ,
.  trr_o          (trr_o         ) 
);

ila_trt_ps u_ila_trt_ps (
	.clk(sys_clk                 ), 
	.probe0(tr_en                ), //1
	.probe1(prf                  ), //1
	.probe2(cnt_prf              ), //1
	.probe3(tr_en_sel            ), //32
	.probe4(tr_en_sel_now        ), //16
	.probe5(trt_ps               ), //8
	.probe6(trr_ps               )  //8
);

endmodule

`timescale 1ns / 1ps
`include "configure.vh"
module wave_ctrl_sig_gen#(
    parameter LANE_BIT         = 20                              ,
    parameter FRAME_DATA_BIT   = 80                              ,
    parameter GROUP_CHIP_NUM   = 4                               ,
    parameter GROUP_NUM        = 16                              ,
    parameter DATA_BIT         = FRAME_DATA_BIT * GROUP_CHIP_NUM ,
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 1_875_000                       ,
    parameter READ_PORT_BYTES  = 16                              ,                
    parameter WRITE_PORT_BYTES = 4                               ,                
    parameter BEAM_BYTES       = GROUP_CHIP_NUM * GROUP_NUM * 16 ,
    parameter CMD_BIT          = 10                              ,
    parameter BEAM_NUM         = 1024
)
(
input  sys_clk       		,
input  reset       		    ,
input  prf          		,
input  ld_o					,
input  single_lane			,
input  tr_mode				,
input  tr_en				,
output tr_en_merge					
// output tr_in          //根据prf信号内部自己产生
    );

//-----------------检测prf信号上升沿------------------//
reg [2:0] prf_r;//打两拍再检测上升沿
wire prf_pos;
always@(posedge sys_clk)begin
    if(reset)
        prf_r <= 0;
    else 
        prf_r <= {prf_r[1:0],prf};
end
assign prf_pos = ~prf_r[2] && prf_r[1];


//-----------------------------生成tr信号-----------------------
//----tr_other
wire tr_other;
wire [63:0] period0,cnt_tr_num0;//延迟时间
assign period0 = 900; 
// assign cnt_tr_num0 = (period0 * SYSHZ) / 1000_000;


wire [63:0] period1,cnt_tr_num1;//使能时间
assign period1 = 100;
// assign cnt_tr_num1 = (period1 * SYSHZ) / 1000_000;
assign cnt_tr_num0 = 6500; // 150_000 3ms
                          // 900 18us
                          // 2800 56us
                          // 13000 260us
                          // 25000 500us
                          // 50000 1ms
                          // 100000 2ms
                          // 200000 4ms
                          //6500 // 130us
assign cnt_tr_num1 = 5000;//100us

wire [31:0] cnt_tr_num;
assign cnt_tr_num = cnt_tr_num0 + cnt_tr_num1;

reg [31:0] cnt_tr;
always@(posedge sys_clk)begin
	if(reset)
		cnt_tr <= cnt_tr_num - 1;
	else if(prf_pos)
		cnt_tr <= 0;
	else if(cnt_tr == cnt_tr_num - 1)
		cnt_tr <= cnt_tr;
	else
		cnt_tr <= cnt_tr + 1;
end
assign tr_other = (cnt_tr >= cnt_tr_num0) && (cnt_tr < cnt_tr_num - 1);

//配置过tr芯片才能有使能信号
reg data_valid;
always@(posedge sys_clk)begin
    if(reset)
        data_valid <= 0;
    else if(ld_o)
        data_valid <= 1;
end

wire tr_o_local;
assign tr_o_local = data_valid && tr_other;


//从外部输入的信号需要限位
reg [2:0] tr_en_r;
wire tr_en_pos;
always@(posedge sys_clk)begin
    if(reset)
        tr_en_r <= 0;
    else
        tr_en_r <= {tr_en_r[1:0],tr_en};
end
assign tr_en_pos =  ~tr_en_r[2] && tr_en_r[1];

reg [31:0] cnt_close;
always@(posedge sys_clk)begin
    if(reset)
        cnt_close <= 5000;
    else if(tr_en_pos)
        cnt_close <= 0;
    else if(cnt_close == 5000)
        cnt_close <= cnt_close;
    else
        cnt_close <= cnt_close + 1;
end

wire tr_input;
wire tr_max;
assign tr_max = (cnt_close <= 5000 - 1);
assign tr_o_input = tr_max && tr_en_r[1];

assign tr_en_merge = tr_mode ? tr_o_input: tr_o_local;

ila_test u_ila_test(
.clk(sys_clk), // input wire clk
.probe0 (1),   
.probe1 (tr_en),   
.probe2 (tr_en_merge),   
.probe3 (tr_mode), 
.probe4 (tr_o_input), 
.probe5 (tr_o_local), 
.probe6 (tr_max), 
.probe7 (single_lane),
.probe8 (cnt_close),
.probe9 (reset)
);




endmodule

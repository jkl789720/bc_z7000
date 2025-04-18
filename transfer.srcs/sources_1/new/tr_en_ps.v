`timescale 1ns / 1ps
module tr_en_ps(
input           sys_clk         ,
input           sys_rst         ,
input           tr_en           ,
input           prf             ,
input           beam_pos_num    ,
input [15:0]    receive_period    ,
//权限
input           bram_tx_sel_clk ,
input           bram_tx_sel_en  ,
input  [3:0]    bram_tx_sel_we  ,
input  [31:0]   bram_tx_sel_addr,
input  [31:0]   bram_tx_sel_din ,
output [31:0]   bram_tx_sel_dout,
output          bram_tx_sel_rst ,

output [7:0]    trt_ps          ,
output [7:0]    trr_ps
    );
    
localparam DWIDTH = 20;

reg [1:0] prf_r;
wire prf_pos;
reg [7:0] cnt_prf;


wire [7:0] tx_sel;//选择对应bit作为发射通道，为1作为发射，发射使能来了就发射，否则作为接收

wire    trt_temp;
reg     trt_temp_r;
wire    trt_temp_neg;

wire    trr_temp;
reg     trr_temp_r;
wire    trr_temp_neg;

reg trt_o;
wire trr_o;

reg [15:0] cnt_receive;
wire    idle_flag;

wire [23:0] beam_pos_cnt;



//ram_read_port

wire                bram_tx_sel_en_read   ;   
wire [3 : 0]        bram_tx_sel_addr_read ;  
wire [15 : 0]       bram_tx_sel_dout_read ;  

assign tx_sel = bram_tx_sel_dout_read[7:0];
genvar kk;
generate
    for(kk = 0;kk < 8;kk = kk + 1)begin:blk0
        assign trt_ps[kk] =  tx_sel[kk] ? trt_o : 0;
        assign trr_ps[kk] =  tx_sel[kk] ? trr_o : 0;
    end
endgenerate

//移位
reg [DWIDTH:0] CFGBC_OUTEN_r = 0;
always@(posedge sys_clk)begin
    if(sys_rst)
        CFGBC_OUTEN_r <= 0;
    else
	    CFGBC_OUTEN_r <= {CFGBC_OUTEN_r[DWIDTH-1:0], tr_en};
end

assign trt_temp = CFGBC_OUTEN_r[DWIDTH/2];
assign trr_temp = |CFGBC_OUTEN_r;


//关闭tr芯片（使其处于负载态）
always @(posedge sys_clk) begin
    if(sys_rst)
        trt_o <= 1;
    else if(idle_flag)
        trt_o <= 1;
    else if(trt_temp_neg)
        trt_o <= 0;
    else 
        trt_o <= trt_o;
end
assign trr_o = trr_temp;

//生成trt_temp_neg
always@(posedge sys_clk)trt_temp_r <= trt_temp;
assign trt_temp_neg = trt_temp_r && (~trt_temp);

//生成trr_temp_neg
always@(posedge sys_clk)trr_temp_r <= trr_temp;
assign trr_temp_neg = trr_temp_r && (~trr_temp);
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

//生成prf的计数器
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_prf <= 0;
    else if(prf_pos)begin
        if(cnt_prf == beam_pos_num)
            cnt_prf <= 1;
        else
            cnt_prf <= cnt_prf + 1;
    end
        
end



assign bram_tx_sel_en_read = 1;
assign bram_tx_sel_addr_read = beam_pos_num == 1 ? 0 : cnt_prf -1;

//prf信号打拍
always @(posedge sys_clk) begin
    if(sys_rst)begin
        prf_r <= 0;
    end
    else begin
        prf_r <= {prf_r[0],prf};
    end
end

assign prf_pos = ~prf_r[1] && prf_r[0];



bram_tx_sel u_bram_tx_sel (
  .clka (bram_tx_sel_clk        ),      // input wire clka
  .ena  (bram_tx_sel_en         ),      // input wire ena
  .wea  (bram_tx_sel_we[0]      ),      // input wire [0 : 0] wea
  .addra(bram_tx_sel_addr >> 2  ),      // input wire [2 : 0] addra
  .dina (bram_tx_sel_din        ),      // input wire [31 : 0] dina
  .douta(bram_tx_sel_dout       ),      // output wire [31 : 0] douta
  .clkb (sys_clk                ),      // input wire clkb
  .enb  (bram_tx_sel_en_read    ),      // input wire enb
  .web  (0                      ),      // input wire [0 : 0] web
  .addrb(bram_tx_sel_addr_read  ),      // input wire [3 : 0] addrb
  .dinb (0                      ),      // input wire [15 : 0] dinb
  .doutb(bram_tx_sel_dout_read  )       // output wire [15 : 0] doutb
);

endmodule

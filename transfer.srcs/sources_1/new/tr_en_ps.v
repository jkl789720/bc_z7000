`timescale 1ns / 1ps
module tr_en_ps#(
    parameter DWIDTH        = 4  ,
    parameter EXPAND_PERIOD = 5
)(
input           sys_clk         ,
input           sys_rst         ,
input           tr_en           ,
input [31:0]    beam_pos_num    ,
input [23:0]    beam_pos_cnt    ,// prf --> tr_en 的时间必须大于5us
input [15:0]    receive_period  ,
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




wire [7:0] tx_sel;//选择对应bit作为发射通道，为1作为发射，发射使能来了就发射，否则作为接收
wire trt_o;
wire trr_o;

wire                bram_tx_sel_en_read   ;   
wire [31 : 0]        bram_tx_sel_addr_read ;  
wire [15 : 0]       bram_tx_sel_dout_read ;  

assign tx_sel = bram_tx_sel_dout_read[7:0];


//ram_read_port


genvar kk;
generate
    for(kk = 0;kk < 8;kk = kk + 1)begin:blk0
        assign trt_ps[kk] =  tx_sel[kk] ? trt_o : 0;
        assign trr_ps[kk] =  tx_sel[kk] ? trr_o : 0;
    end
endgenerate

assign bram_tx_sel_en_read = 1;
assign bram_tx_sel_addr_read = beam_pos_num == 1 ? 0 : beam_pos_cnt -1;





bram_tx_sel u_bram_tx_sel (
  .clka (bram_tx_sel_clk        ),      
  .ena  (bram_tx_sel_en         ),      
  .wea  (bram_tx_sel_we[0]      ),      
  .addra(bram_tx_sel_addr >> 2  ),      
  .dina (bram_tx_sel_din        ),      
  .douta(bram_tx_sel_dout       ),      
  .clkb (sys_clk                ),      
  .enb  (bram_tx_sel_en_read    ),      
  .web  (0                      ),      
  .addrb(bram_tx_sel_addr_read  ),      
  .dinb (0                      ),      
  .doutb(bram_tx_sel_dout_read  )       
);

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

endmodule

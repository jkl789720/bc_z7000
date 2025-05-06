`timescale 1ns / 1ps
module bc_txen_expand(
input               sys_clk     ,
input               sys_rst     ,
input               prf_in      ,      
input               tr_en       ,
input  [3:0]        bc_mode     ,
input               sel_param   ,
input               image_start ,
input  [1:0]       send_status_sel ,
input  [15:0]       receive_period ,
output [7:0]        trt         ,
output [7:0]        trr         

);
wire cnt_prf;
//7000和rfsoc不同
wire trt_o_p_0;
wire trr_o_p_0;
wire trt_o_p_2;
wire trr_o_p_2;
wire trt_tmp;
wire trr_tmp;

assign trt = {{4{trt_o_p_2}},{4{trt_o_p_0}}};
assign trr = {{4{trr_o_p_2}},{4{trr_o_p_0}}};

assign trt_tmp = trt;
assign trr_tmp = (cnt_prf == 0 && send_status_sel [0]) | (cnt_prf == 1 && send_status_sel [1])  ? trr : 0;

bc_mode u_bc_mode(
. sys_clk       (sys_clk     ),
. sys_rst       (sys_rst     ),
. prf_in        (prf_in      ),      
. tr_en         (tr_en       ),
. bc_mode       (bc_mode     ),
. sel_param     (sel_param   ),
. image_start   (image_start ),
. cnt_prf       (cnt_prf     ),
. receive_period(receive_period ),
. trt_o_p_0     (trt_o_p_0   ),//v0
. trr_o_p_0     (trr_o_p_0   ),//v0
. trt_o_p_1     (trt_o_p_1   ),//v1
. trr_o_p_1     (trr_o_p_1   ),//v1
. trt_o_p_2     (trt_o_p_2   ),//h0
. trr_o_p_2     (trr_o_p_2   ),//h0
. trt_o_p_3     (trt_o_p_3   ),//h1
. trr_o_p_3     (trr_o_p_3   ) //h1

);

endmodule

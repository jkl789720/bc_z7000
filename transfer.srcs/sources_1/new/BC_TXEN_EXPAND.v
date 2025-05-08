`timescale 1ns / 1ps
module bc_txen_expand(
input               sys_clk     ,
input               sys_rst     ,
input               prf_in      ,      
input               tr_en       ,
input  [3:0]        bc_mode     ,
input               sel_param   ,
input               image_start ,
input  [1:0]       send_permission ,
input  [1:0]       receive_permission ,
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
wire [7:0] trt_tmp;
wire [7:0] trr_tmp;

assign trt_tmp = {{4{trt_o_p_2}},{4{trt_o_p_0}}};
assign trr_tmp = {{4{trr_o_p_2}},{4{trr_o_p_0}}};
wire test_flag;
assign test_flag = (cnt_prf == 0 && receive_permission [0]) | (cnt_prf == 1 && receive_permission [1]);
assign trt = (cnt_prf == 0 && receive_permission [0]) | (cnt_prf == 1 && receive_permission [1])  ? trt_tmp : 8'hff;
assign trr = (cnt_prf == 0 && send_permission [0]) | (cnt_prf == 1 && send_permission [1])  ? trr_tmp : 0;

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

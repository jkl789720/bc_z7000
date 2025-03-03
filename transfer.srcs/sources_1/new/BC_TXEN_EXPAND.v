`timescale 1ns / 1ps
module bc_txen_expand(
input               sys_clk     ,
input               sys_rst     ,
input               prf_in      ,      
input               trt_o       ,
input               trr_o       ,
input  [3:0]        bc_mode     ,
input               sel_param   ,
input               image_start ,
output     [3:0]    BC1_TRT     ,
output     [3:0]    BC1_TRR     ,
output     [3:0]    BC2_TRT     ,
output     [3:0]    BC2_TRR     

);

wire trt_o_p_0;
wire trr_o_p_0;
wire trt_o_p_2;
wire trr_o_p_2;

assign BC1_TRT = {4{trt_o_p_0}};
assign BC1_TRR = {4{trr_o_p_0}};

assign BC2_TRT = {4{trt_o_p_2}};
assign BC2_TRR = {4{trr_o_p_2}};


bc_mode u_bc_mode(
. sys_clk       (sys_clk     ),
. sys_rst       (sys_rst     ),
. prf_in        (prf_in      ),      
. trt_o         (trt_o       ),
. trr_o         (trr_o       ),
. bc_mode       (bc_mode     ),
. sel_param     (sel_param   ),
. image_start   (image_start ),
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

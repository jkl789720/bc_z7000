`timescale 1ns / 1ps
module test_gpio(
    input 					      sys_clk               ,
    output  [3:0]                   BC1_TRT             ,   
    output  [3:0]                   BC1_TRR                
    );

wire clk_50m;
wire  sys_rst;
wire locked;
reg [31:0] cnt_led;
wire led;
wire set_bc1_g3_trt;
wire set_bc1_g3_trr;
wire set_bc1_g4_trt;
wire set_bc1_g4_trr;
assign sys_rst = !locked;
  clk_wiz_0 u_clk_wiz_0
   (
    // Clock out ports
    .clk_50m(clk_50m),     // output clk_50m
    // Status and control signals
    .reset(0), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(sys_clk));      // input clk_in1
vio_gpio u_vio_gpio (
  .clk(clk_50m),                // input wire clk
  .probe_out0(set_bc1_g3_trt),  // output wire [0 : 0] probe_out0
  .probe_out1(set_bc1_g3_trr),  // output wire [0 : 0] probe_out1
  .probe_out2(set_bc1_g4_trt),  // output wire [0 : 0] probe_out2
  .probe_out3(set_bc1_g4_trr)  // output wire [0 : 0] probe_out3
);

always@(posedge clk_50m)begin
    if(sys_rst)begin
        cnt_led <= 0;
    end
    else if(cnt_led == 500 - 1)begin
        cnt_led <= 0;
    end
    else
        cnt_led <= cnt_led + 1;
end

assign led = (cnt_led < 250);

assign BC1_TRT[2] = set_bc1_g3_trt ? led : 0;
assign BC1_TRR[2] = set_bc1_g3_trr ? led : 0;
assign BC1_TRT[3] = set_bc1_g4_trt ? led : 0;
assign BC1_TRR[3] = set_bc1_g4_trr ? led : 0;

endmodule

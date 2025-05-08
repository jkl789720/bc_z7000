`timescale 1ns / 1ps
module tb_init#(
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 10_000_000                      
)();

reg         sys_clk     ;
reg         sys_rst     ;
wire        chip_reset  ;
wire        cs_n     ;
wire        sclk   ;
wire        mosi   ;
wire        init_done   ;


initial begin
    sys_clk = 0;
    sys_rst = 1;
    #100
    sys_rst = 0;
end
always #10 sys_clk = ~sys_clk;

init_fsm#(
    . SYSHZ        (SYSHZ)  ,
    . SCLHZ        (SCLHZ)  
)
u_init_fsm(
    . sys_clk    (sys_clk   ) ,
    . sys_rst    (sys_rst   ) ,
    . chip_reset (chip_reset) ,
    . cs_n    (cs_n   ) ,
    . sclk  (sclk ) ,
    . mosi  (mosi ) ,
    . init_done  (init_done ) 
);
endmodule

`timescale 1ns / 1ps
module tb_init#(
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 10_000_000                      
)();

reg         sys_clk     ;
reg         sys_rst     ;
wire        chip_reset  ;
wire        cs_init     ;
wire        sclk_init   ;
wire        mosi_init   ;
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
    . cs_init    (cs_init   ) ,
    . sclk_init  (sclk_init ) ,
    . mosi_init  (mosi_init ) ,
    . init_done  (init_done ) 
);
endmodule

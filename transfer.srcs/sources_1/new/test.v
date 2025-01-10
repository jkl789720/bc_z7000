`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/10/23 17:44:08
// Design Name: 
// Module Name: test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test(

    );

    cpu_sys_wrapper
(
 .DDR_addr           (DDR_addr         ) ,
 .DDR_ba             (DDR_ba           ) ,
 .DDR_cas_n          (DDR_cas_n        ) ,
 .DDR_ck_n           (DDR_ck_n         ) ,
 .DDR_ck_p           (DDR_ck_p         ) ,
 .DDR_cke            (DDR_cke          ) ,
 .DDR_cs_n           (DDR_cs_n         ) ,
 .DDR_dm             (DDR_dm           ) ,
 .DDR_dq             (DDR_dq           ) ,
 .DDR_dqs_n          (DDR_dqs_n        ) ,
 .DDR_dqs_p          (DDR_dqs_p        ) ,
 .DDR_odt            (DDR_odt          ) ,
 .DDR_ras_n          (DDR_ras_n        ) ,
 .DDR_reset_n        (DDR_reset_n      ) ,
 .DDR_we_n           (DDR_we_n         ) ,
 .FIXED_IO_ddr_vrn   (FIXED_IO_ddr_vrn ) ,
 .FIXED_IO_ddr_vrp   (FIXED_IO_ddr_vrp ) ,
 .FIXED_IO_mio       (FIXED_IO_mio     ) ,
 .FIXED_IO_ps_clk    (FIXED_IO_ps_clk  ) ,
 .FIXED_IO_ps_porb   (FIXED_IO_ps_porb ) ,
 .FIXED_IO_ps_srstb  (FIXED_IO_ps_srstb) 
 );


endmodule

`timescale 1ns / 1ps
module tb_spi#(
    parameter FRAME_DATA_BIT  = 12                             ,
    parameter GROUP_CHIP_NUM  = 4                              ,
    parameter DATA_BIT        = FRAME_DATA_BIT * GROUP_CHIP_NUM,
    parameter SYSHZ           = 50_000_000                     ,
    parameter SCLHZ           = 10_000_000                     
)();

// spi_o Parameters


// spi_o Inputs
reg                     sys_clk ;
reg                     reset   ;
reg   [DATA_BIT-1:0]    data_in ;
reg                     trig    ;

// spi_o Outputs
wire  sel_o;
wire  scl_o;
wire  [3:0]  sd_o;

// spi_o Outputs
wire  [DATA_BIT-1:0]  data_o;
wire  data_valid;

initial begin
    sys_clk = 0;
    data_in = 48'h3f8b4a798f3b;
    trig    = 0;
    reset   = 1;
    #200
    reset   = 0;
    #500
    trig    = 1;
    #20
    trig    = 0;
end

always #10 sys_clk = ~sys_clk;


spi_o #(
    .FRAME_DATA_BIT (FRAME_DATA_BIT),
    .GROUP_CHIP_NUM (GROUP_CHIP_NUM),
    .DATA_BIT       (DATA_BIT      ),
    .SYSHZ          (SYSHZ         ),
    .SCLHZ          (SCLHZ         ))
 u_spi_o (
    .sys_clk                 ( sys_clk   ),
    .reset                   ( reset     ),
    .data_in                 ( data_in   ),
    .trig                    ( trig      ),

    .sel_o                   ( sel_o     ),
    .scl_o                   ( scl_o     ),
    .sd_o                    ( sd_o      )
);




spi_i #(
    .FRAME_DATA_BIT (FRAME_DATA_BIT),
    .GROUP_CHIP_NUM (GROUP_CHIP_NUM),
    .DATA_BIT       (DATA_BIT      ),
    .SYSHZ          (SYSHZ         ),
    .SCLHZ          (SCLHZ         ))
 u_spi_i (
    .sys_clk                 ( sys_clk      ),
    .reset                   ( reset        ),
    .sel_i                   ( sel_o        ),
    .scl_i                   ( scl_o        ),
    .sd_i                    ( sd_o         ),

    .data_o                  ( data_o       ),
    .data_valid              ( data_valid   )
);

endmodule

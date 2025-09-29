//特别注意，bram2spi模块应该对bc_data_done信号进行打拍延时
`timescale 1ns / 1ps
module rfsoc_2z7000#
(
    parameter FRAM_BIT_NUM   = 45        ,//需跟随协议改
    parameter RAM_ADDR_WITDH = 13        ,//需跟随协议改
    parameter SYS_HZ         = 50_000_000,
    parameter SCL_HZ         = 10_000_000
)(
input                               sys_clk                     ,
input                               sys_rst                     ,
input                               cs_n                        ,
input                               scl                         ,
input                               mosi                        ,

output                              ram_rfsoc_clk               ,
output                              ram_rfsoc_en                ,
output                              ram_rfsoc_wren              ,
output [RAM_ADDR_WITDH - 1:0]       ram_rfsoc_addr              ,
output [31:0]                       ram_rfsoc_din 

);

//spi转成的ram接口
wire                        ram_spi_clk    ;
wire                        ram_spi_en     ;
wire                        ram_spi_wren   ;
wire [RAM_ADDR_WITDH - 1:0] ram_spi_addr   ;
wire [31:0]                 ram_spi_din    ;



assign ram_rfsoc_clk  =  ram_spi_clk ;
assign ram_rfsoc_en   =  ram_spi_en  ;
assign ram_rfsoc_wren =  ram_spi_wren;
assign ram_rfsoc_addr =  ram_spi_addr;
assign ram_rfsoc_din  =  ram_spi_din ;

spi2bram#
(
    . FRAM_BIT_NUM      (FRAM_BIT_NUM  ),
    . RAM_ADDR_WITDH    (RAM_ADDR_WITDH),
    . SYS_HZ            (SYS_HZ        ),
    . SCL_HZ            (SCL_HZ        )
)
u_spi2bram(
    .    sys_clk          (sys_clk              )   ,
    .    sys_rst          (sys_rst              )   ,
    .    cs_n             (cs_n                 )   ,
    .    scl              (scl                  )   ,
    .    mosi             (mosi                 )   ,
    .    ram_clk          (ram_spi_clk          )   ,
    .    ram_en           (ram_spi_en           )   ,
    .    ram_wren         (ram_spi_wren         )   ,
    .    ram_addr         (ram_spi_addr         )   ,
    .    ram_din          (ram_spi_din          )
);


endmodule

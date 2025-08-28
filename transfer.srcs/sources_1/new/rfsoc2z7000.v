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
input                               bc_data_done                ,

output                              ram_rfsoc_clk               ,
output                              ram_rfsoc_en                ,
output                              ram_rfsoc_wren              ,
output [RAM_ADDR_WITDH - 1:0]       ram_rfsoc_addr              ,
output [31:0]                       ram_rfsoc_din 

);

localparam RAM_DONE_ADDR = 32'd8191;//ctrl_reg15的地址，按32bit编码，而非字节编码 需跟随协议改

reg [1:0]  bc_data_done_r  ;
wire bc_data_done_pos;

//spi转成的ram接口
wire                        ram_spi_clk    ;
wire                        ram_spi_en     ;
wire                        ram_spi_wren   ;
wire [RAM_ADDR_WITDH - 1:0] ram_spi_addr   ;
wire [31:0]                 ram_spi_din    ;

//done信号生成的ram接口
wire                        ram_done_clk   ;
wire                        ram_done_en    ;
wire                        ram_done_wren  ;
wire [RAM_ADDR_WITDH - 1:0] ram_done_addr  ;
wire [31:0]                 ram_done_din   ;


//对bc_data_done信号进行同步
always @(posedge sys_clk) begin
    if(sys_rst)
        bc_data_done_r <= 0;
    else 
        bc_data_done_r <= {bc_data_done_r[0],bc_data_done};
end

assign bc_data_done_pos = ~bc_data_done_r[1] && bc_data_done_r[0];

assign ram_done_clk = sys_clk;
assign ram_done_en  = bc_data_done_pos;
assign ram_done_wren= bc_data_done_pos;
assign ram_done_addr= RAM_DONE_ADDR;
assign ram_done_din = 32'd1;

assign ram_rfsoc_clk  = sys_clk;
assign ram_rfsoc_en   = bc_data_done_pos ? ram_done_en   : ram_spi_en  ;
assign ram_rfsoc_wren = bc_data_done_pos ? ram_done_wren : ram_spi_wren;
assign ram_rfsoc_addr = bc_data_done_pos ? ram_done_addr : ram_spi_addr;
assign ram_rfsoc_din  = bc_data_done_pos ? ram_done_din  : ram_spi_din ;

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

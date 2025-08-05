`timescale 1ns / 1ps

module top_slave#
(
    parameter FRAM_BIT_NUM  = 128        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL      = 8,
    parameter SPI_LANE      = 4
)(
    input                           sys_clk     ,

    input       [1:0]               cs_n        ,
    input       [1:0]               scl         ,
    input       [SPI_CHANNEL - 1: 0]   mosi        
    );



wire             clka_check ;
wire             ena_check  ;
wire [3:0]       wea_check  ;
wire [31:0]      addra_check;
wire [31:0]      dina_check ;
wire [31:0]      douta_check;
wire [31:0]      rama_rst_check;


wire          ram_bc_angle_clk  ;
wire          ram_bc_angle_en   ;
wire [3:0]    ram_bc_angle_we   ;
wire [31:0]   ram_bc_angle_addr ;
wire [31:0]   ram_bc_angle_din  ;
wire [31:0]   ram_bc_angle_dout ;
wire          ram_bc_angle_rst  ;

//PL
wire          ram_rfsoc_clk    ;
wire          ram_rfsoc_en     ;
wire          ram_rfsoc_wren   ;
wire [31:0]   ram_rfsoc_addr   ;
wire [31:0]   ram_rfsoc_din    ;
wire bram_clk;
wire bram_we;
wire [31:0] bram_addr;
wire [31:0] bram_data;

wire  sys_rst;
wire locked;
wire vio_rst;
wire clk_50m;
  clk_wiz_0 u_clk_wiz_0
   (
    // Clock out ports
    .clk_50m(clk_50m),     // output clk_50m
    // Status and control signals
    .reset(0), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(sys_clk));      // input clk_in1

vio_reset u_vio_reset (
  .clk          (clk_50m    ),
  .probe_out0   (vio_rst    )  
);

assign sys_rst = ~locked | vio_rst;

wire bram_wr_done;

assign ram_rfsoc_clk  = clk_50m;
assign ram_rfsoc_en   = 1;
assign ram_rfsoc_wren = bram_wr_done;
assign ram_rfsoc_addr = 32'd8186;
assign ram_rfsoc_din  = 1;


cpu_sys_wrapper u_cpu_sys_wrapper(
    . app_param0                (app_param0           ),
    . app_param1                (app_param1           ),
    . app_param2                (app_param2           ),
    . app_param3                (app_param3           ),

    . app_status0               (app_status0          ),
    . app_status1               (app_status1          ),



    . ram_bc_angle_addr         (ram_bc_angle_addr    ),
    . ram_bc_angle_clk          (ram_bc_angle_clk     ),
    . ram_bc_angle_din          (ram_bc_angle_din     ),
    . ram_bc_angle_dout         (ram_bc_angle_dout    ),
    . ram_bc_angle_en           (ram_bc_angle_en      ),
    . ram_bc_angle_rst          (ram_bc_angle_rst     ),
    . ram_bc_angle_we           (ram_bc_angle_we      ),


    . ram_bc_code_read_clk      (clka_check           ),
    . ram_bc_code_read_en       (ena_check            ),
    . ram_bc_code_read_we       (wea_check            ),
    . ram_bc_code_read_addr     (addra_check          ),
    . ram_bc_code_read_din      (dina_check           ),
    . ram_bc_code_read_dout     (douta_check          ),
    . ram_bc_code_read_rst      (rama_rst_check       ),

    . bc_uart_adjust_rxd        (BC_UART_ADJUST_RX    ),
    . bc_uart_adjust_txd        (BC_UART_ADJUST_TX    )
 );

data_check #(
    .FRAM_BIT_NUM    (FRAM_BIT_NUM),          // 默认 24，可修改
    .SYS_HZ          (SYS_HZ      ),  // 系统时钟频率（Hz）
    .SCL_HZ          (SCL_HZ      ),   // SCL时钟频率（Hz）
    .SPI_CHANNEL     (SPI_CHANNEL ),           // SPI通道数
    .SPI_LANE        (SPI_LANE    )            // SPI Lane数
) u_data_check (
    .sys_clk          (clk_50m),           // 输入：系统时钟
    .sys_rst          (sys_rst),           // 输入：系统复位
    .bram_we          (bram_we),           // 输入：BRAM写使能
    .bram_addr        (bram_addr),         // 输入：BRAM地址（32bit）
    .bram_data        (bram_data),         // 输入：BRAM数据（32bit）
    .bram_wr_done     (bram_wr_done)
);

 test_slave #
(
    . FRAM_BIT_NUM (FRAM_BIT_NUM),
    . SYS_HZ       (SYS_HZ      ),
    . SCL_HZ       (SCL_HZ      ),
    . SPI_CHANNEL     (SPI_CHANNEL    ),
    . SPI_LANE     (SPI_LANE    )
) u_test_slave (
    .sys_clk      (clk_50m),       // 系统时钟
    .sys_rst      (sys_rst),       // 系统复位，高有效

  .cs_n         ({{4{cs_n[1]}},{4{cs_n[0]}}}    ),      // SPI 片选，低有效
    .scl          ({{4{scl[1]}},{4{scl[0]}}}     ),      // SPI 时钟
    .mosi         (mosi    ),      // SPI 主出从入

    .bram_clk     (bram_clk),      // BRAM 写时钟
    .bram_we      (bram_we ),      // BRAM 写使能
    .bram_addr    (bram_addr),     // BRAM 写地址
    .bram_data    (bram_data),     // BRAM 写数据
    .bram_wr_done (bram_wr_done)   // 写完成标志
);
bram_bc_code_spi u_bram_bc_code_check (
  .clka (clka_check       ),// input  wire clka
  .ena  (ena_check        ),// input  wire ena
  .wea  (wea_check        ),// input  wire [0 : 0] wea
  .addra(addra_check >> 2 ),// input  wire [10 : 0] addra
  .dina (dina_check       ),// input  wire [31 : 0] dina
  .douta(douta_check      ),// output wire [31 : 0] douta
  .clkb (bram_clk         ),// input wire clkb
  .enb  (1                ),// input wire enb
  .web  (bram_we          ),// input wire [0 : 0] web
  .addrb(bram_addr        ),// input wire [10 : 0] addrb
  .dinb (bram_data        ),// input wire [31 : 0] dinb
  .doutb(                 ) // output wire [31 : 0] doutb
);

 bram_spi_in u_bram_bc_angle (
  .clka (ram_bc_angle_clk       ),      // input wire clka
  .ena  (ram_bc_angle_en        ),      // input wire ena
  .wea  (ram_bc_angle_we[0]     ),      // input wire [0 : 0] wea
  .addra(ram_bc_angle_addr >> 2 ),      // input wire [6 : 0] addra
  .dina (ram_bc_angle_din       ),      // input wire [31 : 0] dina
  .douta(ram_bc_angle_dout      ),      // output wire [31 : 0] douta
  .clkb (ram_rfsoc_clk          ),      // input wire clkb
  .enb  (ram_rfsoc_en           ),      // input wire enb
  .web  (ram_rfsoc_wren         ),      // input wire [0 : 0] web
  .addrb(ram_rfsoc_addr         ),      // input wire [7 : 0] addrb
  .dinb (ram_rfsoc_din          ),      // input wire [15 : 0] dinb
  .doutb(doutb                  )       // output wire [15 : 0] doutb
);



ila_done_ram u_ila_done_ram (
	.clk       (ram_rfsoc_clk ), 
	.probe0    (ram_rfsoc_en  ), 
	.probe1    (ram_rfsoc_wren  ), 
	.probe2    (ram_rfsoc_addr), 
	.probe3    (ram_rfsoc_din ) 
);

ila_bccode_bram_rw u_ila_ps_angle_bram_rw (
	.clk    (ram_bc_angle_clk   ), // input wire clk
	.probe0 (ram_bc_angle_en    ), // input wire [0:0]  probe0  
	.probe1 (ram_bc_angle_we    ), // input wire [3:0]  probe1 
	.probe2 (ram_bc_angle_addr  ), // input wire [31:0]  probe2 
	.probe3 (ram_bc_angle_din   ), // input wire [31:0]  probe3 
	.probe4 (ram_bc_angle_dout  )  // input wire [31:0]  probe4
);

ila_bccode_bram_rw u_ila_bccode_bram_back_rw (
	.clk       (clka_check ), // input wire clk
	.probe0    (ena_check  ), // input wire [0:0]  probe0  
	.probe1    (wea_check  ), // input wire [3:0]  probe1 
	.probe2    (addra_check), // input wire [31:0]  probe2 
	.probe3    (dina_check ), // input wire [31:0]  probe3 
	.probe4    (douta_check)  // input wire [31:0]  probe4 
);


endmodule

`timescale 1ns / 1ps
module top_master#
(
    parameter FRAM_BIT_NUM  = 128        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL      = 8,
    parameter SPI_LANE      = 4
)(
    input                               sys_clk     ,
    output  [1:0]                       BC2_SEL     ,
    output  [1:0]                       BC2_CLK     ,
    output  [SPI_CHANNEL - 1: 0]        BC2_DATA    ,
    output  [1:0]                       BC2_LD      ,  
    output  [1:0]                       BC2_TRT     ,
    output  [1:0]                       BC2_TRR                       
);

assign BC2_TRT = 2'b00;
assign BC2_TRR = 2'b00;
assign BC2_LD = 2'b00;

wire  sys_rst;
wire locked;

wire clk_50m;
wire vio_rst;
assign sys_rst = ~locked | vio_rst;
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

wire [31:0]   app_param0 ;
wire [31:0]   app_param1 ;
wire [31:0]   app_param2 ;
wire [31:0]   app_param3 ;

wire [31:0]   app_status0;
wire [31:0]   app_status1;

wire          ram_bc_code_clk  ;
wire          ram_bc_code_en   ;
wire [3:0]    ram_bc_code_we   ;
wire [31:0]   ram_bc_code_addr ;
wire [31:0]   ram_bc_code_din  ;
wire [31:0]   ram_bc_code_dout ;
wire          ram_bc_code_rst  ;


wire             clka_check ;
wire             ena_check  ;
wire [3:0]       wea_check  ;
wire [31:0]      addra_check;
wire [31:0]      dina_check ;
wire [31:0]      douta_check;
wire [31:0]      rama_rst_check;

wire [SPI_CHANNEL - 1: 0]  cs_n ;
wire [SPI_CHANNEL - 1: 0]  scl  ;
wire [SPI_CHANNEL - 1: 0]  mosi ;

wire         bram_we        ;
wire[31:0]   bram_addr      ;
wire[31:0]   bram_data      ;
wire         bram_wr_done   ;

wire [SPI_CHANNEL - 1:0] send_done;

assign BC2_SEL  ={cs_n[4],cs_n[0]};
assign BC2_CLK  = {scl[4],scl[0]};
assign BC2_DATA = mosi;


cpu_sys u_cpu_sys(
    . app_param0                (app_param0           ),
    // . app_param1                (app_param1           ),
    . app_param2                (app_param2           ),
    . app_param3                (app_param3           ),

    . app_status0               (app_status0          ),
    . app_status1               (app_status1          ),

    // . rama_clk                  (ram_bc_code_clk      ),
    // . rama_en                   (ram_bc_code_en       ),
    // . rama_we                   (ram_bc_code_we       ),
    // . rama_addr                 (ram_bc_code_addr     ),
    // . rama_din                  (ram_bc_code_din      ),
    // . rama_dout                 (ram_bc_code_dout     ),
    // . rama_rst                  (ram_bc_code_rst      ),

    . ram_bc_angle_addr         (ram_bc_angle_addr    ),
    . ram_bc_angle_clk          (ram_bc_angle_clk     ),
    . ram_bc_angle_din          (ram_bc_angle_din     ),
    . ram_bc_angle_dout         (ram_bc_angle_dout    ),
    . ram_bc_angle_en           (ram_bc_angle_en      ),
    . ram_bc_angle_rst          (ram_bc_angle_rst     ),
    . ram_bc_angle_we           (ram_bc_angle_we      ),

    . bram_tx_sel_clk           (bram_tx_sel_clk      ),
    . bram_tx_sel_en            (bram_tx_sel_en       ),
    . bram_tx_sel_we            (bram_tx_sel_we       ),
    . bram_tx_sel_addr          (bram_tx_sel_addr     ),
    . bram_tx_sel_din           (bram_tx_sel_din      ),
    . bram_tx_sel_dout          (bram_tx_sel_dout     ),
    . bram_tx_sel_rst           (bram_tx_sel_rst      ),

    . ram_bc_code_read_clk      (clka_check           ),
    . ram_bc_code_read_en       (ena_check            ),
    . ram_bc_code_read_we       (wea_check            ),
    . ram_bc_code_read_addr     (addra_check          ),
    . ram_bc_code_read_din      (dina_check           ),
    . ram_bc_code_read_dout     (douta_check          ),
    . ram_bc_code_read_rst      (rama_rst_check       ),

    . ram_bc_init_clk           (ram_bc_init_clk      ),
    . ram_bc_init_en            (ram_bc_init_en       ),
    . ram_bc_init_we            (ram_bc_init_we       ),
    . ram_bc_init_addr          (ram_bc_init_addr     ),
    . ram_bc_init_din           (ram_bc_init_din      ),
    . ram_bc_init_dout          (ram_bc_init_dout     ),
    . ram_bc_init_rst           (ram_bc_init_rst      ),

    . ram_bc_init_back_clk      (ram_bc_init_clk_back ),
    . ram_bc_init_back_en       (ram_bc_init_en_back  ),
    . ram_bc_init_back_we       (ram_bc_init_we_back  ),
    . ram_bc_init_back_addr     (ram_bc_init_addr_back),
    . ram_bc_init_back_din      (ram_bc_init_din_back ),
    . ram_bc_init_back_dout     (ram_bc_init_dout_back),
    . ram_bc_init_back_rst      (ram_bc_init_rst_back ),

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

data_gen #(
    .FRAM_BIT_NUM (FRAM_BIT_NUM),           // 帧数据位数（默认24）
    .SYS_HZ       (SYS_HZ      ),   // 系统时钟频率（50MHz）
    .SCL_HZ       (SCL_HZ      ),    // 串行时钟频率（1MHz）
    .SPI_CHANNEL  (SPI_CHANNEL ),            // SPI通道数（默认8）
    .SPI_LANE     (SPI_LANE    )             // SPI Lane数（默认4）
) u_data_gen (
    // 系统信号
    .sys_clk      (clk_50m),      // 输入：系统时钟
    .sys_rst      (sys_rst),      // 输入：系统复位（高有效）
    
    // RAM接口信号
    .rama_clk     (ram_bc_code_clk),     // 输出：RAM时钟
    .rama_en      (ram_bc_code_en),      // 输出：RAM使能
    .rama_we      (ram_bc_code_we),      // 输出：RAM写使能（4bit，按字节使能）
    .rama_addr    (ram_bc_code_addr),    // 输出：RAM地址（32bit，递增步进4）
    .rama_din     (ram_bc_code_din),      // 输出：RAM写入数据（32bit）
    .app_param1     (app_param1)  ,   
    .send_done     (send_done)     
);

test_master#
(
    . FRAM_BIT_NUM (FRAM_BIT_NUM),
    . SYS_HZ       (SYS_HZ      ),
    . SCL_HZ       (SCL_HZ      ),
    . SPI_CHANNEL     (SPI_CHANNEL    ),
    . SPI_LANE     (SPI_LANE    )
)
u_test_master(
    . sys_clk    (clk_50m  )  ,
    . sys_rst    (sys_rst  )  ,
    . rama_clk   (ram_bc_code_clk )  ,
	. rama_en    (ram_bc_code_en  )  ,
	. rama_we    (ram_bc_code_we  )  ,
	. rama_addr  (ram_bc_code_addr)  ,
	. rama_din   (ram_bc_code_din )  ,
	. rama_dout  (ram_bc_code_dout)  ,
	. rama_rst   (ram_bc_code_rst )  ,
    
   . clka_check     (clka_check           ),
   . ena_check      (ena_check            ),
   . wea_check      (wea_check            ),
   . addra_check    (addra_check          ),
   . dina_check     (dina_check           ),
   . douta_check    (douta_check          ),
   . rama_rst_check (rama_rst_check       ),
    . app_param1      (app_param1    )  ,
    . cs_n       (cs_n     )  ,
    . scl        (scl      )  ,
    . mosi       (mosi     )  ,
    . send_done       (send_done     )  


);

// top_slave#(
//     .FRAM_BIT_NUM (FRAM_BIT_NUM),           // 帧数据位数（默认24）
//     .SYS_HZ       (SYS_HZ      ),   // 系统时钟频率（50MHz）
//     .SCL_HZ       (SCL_HZ      ),    // 串行时钟频率（1MHz）
//     .SPI_CHANNEL  (SPI_CHANNEL ),            // SPI通道数（默认8）
//     .SPI_LANE     (SPI_LANE    )             // SPI Lane数（默认4）
// )u_top_slave(
//     .  sys_clk (clk_50m)    ,
//     .  cs_n    (BC2_SEL   )    ,
//     .  scl     (BC2_CLK    )    ,
//     .  mosi    (BC2_DATA   )    
//     );

wire  cs_n_0;
wire  cs_n_1;
wire  scl_0 ;
wire  scl_1 ;
wire  mosi_0;
wire  mosi_1;
wire  mosi_2;
wire  mosi_3;
wire  mosi_4;
wire  mosi_5;
wire  mosi_6;
wire  mosi_7;


assign cs_n_0 = BC2_SEL[0];
assign cs_n_1 = BC2_SEL[1];
assign scl_0  = BC2_CLK[0];
assign scl_1  = BC2_CLK[1];
assign mosi_0 = BC2_DATA[0];
assign mosi_1 = BC2_DATA[1];
assign mosi_2 = BC2_DATA[2];
assign mosi_3 = BC2_DATA[3];
assign mosi_4 = BC2_DATA[4];
assign mosi_5 = BC2_DATA[5];
assign mosi_6 = BC2_DATA[6];
assign mosi_7 = BC2_DATA[7];


ila_spi_out u_ila_spi_out (
	.clk(clk_50m), // input wire clk
	.probe0 (cs_n_0),
	.probe1 (cs_n_1),
	.probe2 (scl_0 ),
	.probe3 (scl_1 ),
	.probe4 (mosi_0),
	.probe5 (mosi_1),
	.probe6 (mosi_2),
	.probe7 (mosi_3),
	.probe8 (mosi_4),
	.probe9 (mosi_5),
	.probe10(mosi_6),
	.probe11(mosi_7) 
);

endmodule

`timescale 1ns / 1ps
module ctrl#(
    `ifndef G3
    parameter LANE_BIT         = 20                              ,
    parameter FRAME_DATA_BIT   = 80                              ,
    `else
    parameter LANE_BIT         = 26                              ,
    parameter FRAME_DATA_BIT   = 106                             ,
    `endif       
    
    parameter GROUP_CHIP_NUM   = 32                              ,
    parameter GROUP_NUM        = 1                               ,
    parameter SCLHZ            = 10_000_000                      ,



    parameter DATA_BIT         = FRAME_DATA_BIT * GROUP_CHIP_NUM ,
    parameter SYSHZ            = 50_000_000                      ,
    parameter READ_PORT_BYTES  = 16                              ,
    parameter WRITE_PORT_BYTES = 4                               ,
    parameter BEAM_BYTES       = GROUP_CHIP_NUM * GROUP_NUM * 16 ,
    // parameter BEAM_BYTES       = 16 * 16                         ,
    parameter CMD_BIT          = 10                              ,
    parameter BEAM_NUM         = 1024
)
(
    input 					      sys_clk               ,
    `ifdef TB_TEST
    input                         sys_rst               ,
    `endif
    input                         prf_pin_in            ,

//rfsoc_communication
    input                         scl                  ,
    input                         cs_n                  ,
    input                         mosi                  ,

    input                         prf_rf_in             ,//           
    input                         tr_en                 ,
    input                         bc_data_done          ,//

//BC1_new
    output  [3:0]                   BC1_SEL             ,   
    output  [3:0]                   BC1_CLK             ,         
    output  [15:0]                  BC1_DATA            ,    
    output  [3:0]                   BC1_LD              ,  
    output  [3:0]                   BC1_TRT             ,   
    output  [3:0]                   BC1_TRR             ,   

 
//BC2_new
    output  [3:0]                   BC2_SEL             ,   
    output  [3:0]                   BC2_CLK             ,         
    output  [15:0]                  BC2_DATA            ,    
    output  [3:0]                   BC2_LD              ,  
    output  [3:0]                   BC2_TRT             ,
    output  [3:0]                   BC2_TRR             ,   

//BC_RST
    output                          BC_RST              ,

//uart   
    input                           BC_UART_ADJUST_RX  ,
    output                          BC_UART_ADJUST_TX  
);
`ifndef TB_TEST
wire  sys_rst;
vio_reset u_vio_reset (
  .clk          (sys_clk    ),
  .probe_out0   (sys_rst    )  
);
`endif

//添加了一行注�?

//PS
wire [31:0]   rama_addr  ;
wire          rama_clk   ;
wire [31:0]   rama_din   ;
wire [31:0]   rama_dout  ;
wire          rama_en    ;
wire          rama_rst   ;
wire [3:0]    rama_we    ;

wire          ram_bc_code_clk  ;
wire          ram_bc_code_en   ;
wire [3:0]    ram_bc_code_we   ;
wire [31:0]   ram_bc_code_addr ;
wire [31:0]   ram_bc_code_din  ;
wire [31:0]   ram_bc_code_dout ;
wire          ram_bc_code_rst  ;

wire          ram_bc_angle_clk  ;
wire          ram_bc_angle_en   ;
wire [3:0]    ram_bc_angle_we   ;
wire [31:0]   ram_bc_angle_addr ;
wire [31:0]   ram_bc_angle_din  ;
wire [31:0]   ram_bc_angle_dout ;
wire          ram_bc_angle_rst  ;


wire          bram_tx_sel_clk  ;
wire          bram_tx_sel_en   ;
wire [3:0]    bram_tx_sel_we   ;
wire [31:0]   bram_tx_sel_addr ;
wire [31:0]   bram_tx_sel_din  ;
wire [31:0]   bram_tx_sel_dout ;
wire          bram_tx_sel_rst  ;



//PL
wire          ram_rfsoc_clk    ;
wire          ram_rfsoc_en     ;
wire          ram_rfsoc_wren   ;
wire [7:0]    ram_rfsoc_addr   ;
wire [15:0]   ram_rfsoc_din    ;



wire [31:0]   app_param0 ;
wire [31:0]   app_param1 ;
wire [31:0]   app_param2 ;
wire [31:0]   app_param3 ;

wire [31:0]   app_status0;
wire [31:0]   app_status1;


cpu_sys_wrapper u_cpu_sys_wrapper(
 . app_param0               (app_param0          ),
 . app_param1               (app_param1          ),
 . app_param2               (app_param2          ),
 . app_param3               (app_param3          ),

 . app_status0              (app_status0         ),
 . app_status1              (app_status1         ),

 . rama_clk                 (ram_bc_code_clk    ),
 . rama_en                  (ram_bc_code_en     ),
 . rama_we                  (ram_bc_code_we     ),
 . rama_addr                (ram_bc_code_addr   ),
 . rama_din                 (ram_bc_code_din    ),
 . rama_dout                (ram_bc_code_dout   ),
 . rama_rst                 (ram_bc_code_rst    ),


 . ram_bc_angle_addr        (ram_bc_angle_addr   ),
 . ram_bc_angle_clk         (ram_bc_angle_clk    ),
 . ram_bc_angle_din         (ram_bc_angle_din    ),
 . ram_bc_angle_dout        (ram_bc_angle_dout   ),
 . ram_bc_angle_en          (ram_bc_angle_en     ),
 . ram_bc_angle_rst         (ram_bc_angle_rst    ),
 . ram_bc_angle_we          (ram_bc_angle_we     ),

 . bram_tx_sel_clk          (bram_tx_sel_clk     ),
 . bram_tx_sel_en           (bram_tx_sel_en      ),
 . bram_tx_sel_we           (bram_tx_sel_we      ),
 . bram_tx_sel_addr         (bram_tx_sel_addr    ),
 . bram_tx_sel_din          (bram_tx_sel_din     ),
 . bram_tx_sel_dout         (bram_tx_sel_dout    ),
 . bram_tx_sel_rst          (bram_tx_sel_rst     ),

 . bc_uart_adjust_rxd       (BC_UART_ADJUST_RX   ),
 . bc_uart_adjust_txd       (BC_UART_ADJUST_TX   )
 );

 bc_wrapper_z7#(
    `ifndef G3
    . LANE_BIT         (LANE_BIT        ),
    . FRAME_DATA_BIT   (FRAME_DATA_BIT  ),
    `else
    . LANE_BIT         (LANE_BIT        ),
    . FRAME_DATA_BIT   (FRAME_DATA_BIT  ),
    `endif       
    . GROUP_CHIP_NUM   (GROUP_CHIP_NUM  ),
    . GROUP_NUM        (GROUP_NUM       ),
    . SCLHZ            (SCLHZ           ),
    . DATA_BIT         (DATA_BIT        ),
    . SYSHZ            (SYSHZ           ),
    . READ_PORT_BYTES  (READ_PORT_BYTES ),
    . WRITE_PORT_BYTES (WRITE_PORT_BYTES),
    . BEAM_BYTES       (BEAM_BYTES      ),
    . CMD_BIT          (CMD_BIT         ),
    . BEAM_NUM         (BEAM_NUM        )
)
u_bc_wrapper_z7(
    . sys_clk 	            (sys_clk 	    )       ,
    . sys_rst 	            (sys_rst 	    )       ,
    . prf_pin_in            (prf_pin_in     )       ,
    . prf_rf_in             (prf_rf_in      )       ,
    . tr_en                 (tr_en          )       ,

    . rama_clk              (ram_bc_code_clk )       ,
	. rama_en               (ram_bc_code_en  )       ,
	. rama_we               (ram_bc_code_we  )       ,
	. rama_addr             (ram_bc_code_addr)       ,
	. rama_din              (ram_bc_code_din )       ,
	. rama_dout             (ram_bc_code_dout)       ,
	. rama_rst              (ram_bc_code_rst )       ,

    . bram_tx_sel_clk       (bram_tx_sel_clk )       ,
	. bram_tx_sel_en        (bram_tx_sel_en  )       ,
	. bram_tx_sel_we        (bram_tx_sel_we  )       ,
	. bram_tx_sel_addr      (bram_tx_sel_addr)       ,
	. bram_tx_sel_din       (bram_tx_sel_din )       ,
	. bram_tx_sel_dout      (bram_tx_sel_dout)       ,
	. bram_tx_sel_rst       (bram_tx_sel_rst )       ,
    
    . app_param0            (app_param0     )  	    ,
    . app_param1            (app_param1     )  	    ,
    . app_param2            (app_param2     )  	    ,
    . app_param3            (app_param3     )  	    ,
    . app_status0           (app_status0    )	    ,
    . app_status1           (app_status1    )	    ,
    . BC1_SEL               (BC1_SEL        )       ,
    . BC1_CLK               (BC1_CLK        )       ,
    . BC1_DATA              (BC1_DATA       )       ,
    . BC1_LD                (BC1_LD         )       ,
    . BC1_TRR               (BC1_TRR        )       ,
    . BC1_TRT               (BC1_TRT        )       ,
    . BC2_SEL               (BC2_SEL        )       ,
    . BC2_CLK               (BC2_CLK        )       ,
    . BC2_DATA              (BC2_DATA       )       ,
    . BC2_LD                (BC2_LD         )       ,
    . BC2_TRT               (BC2_TRT        )       ,
    . BC2_TRR               (BC2_TRR        )       ,
    . BC_RST                (BC_RST         )       
);

rfsoc_2z7000 u_rfsoc_2z7000(
. sys_clk       (sys_clk        )  ,
. sys_rst       (sys_rst        )  ,
. cs_n          (cs_n           )  ,
. scl           (scl            )  ,
. mosi          (mosi           )  ,
. bc_data_done  (bc_data_done   )  ,
. ram_rfsoc_clk (ram_rfsoc_clk  )  ,
. ram_rfsoc_en  (ram_rfsoc_en   )  ,
. ram_rfsoc_wren(ram_rfsoc_wren )  ,
. ram_rfsoc_addr(ram_rfsoc_addr )  ,
. ram_rfsoc_din (ram_rfsoc_din  )

);

ram_z7_check u_ram_z7_check(
.  sys_rst          (sys_rst         ), 
.  rama_clk         (ram_rfsoc_clk   ),
.  rama_en          (ram_rfsoc_en    ),
.  rama_wren        (ram_rfsoc_wren  ),
.  rama_addr        (ram_rfsoc_addr  ),
.  rama_din         (ram_rfsoc_din   )
);

bram_spi_in u_bram_spi_in (
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


`ifdef DEBUG    
ila_rfsoc2z7 u_ila_rfsoc2z7 (
	.clk    (sys_clk            ), // input wire clk
	.probe0 (prf_rf_in          ), // 1 
	.probe1 (tr_en              ), // 1 
	.probe2 (bc_data_done       ), // 1 
	.probe3 (cs_n               ), // 1 
	.probe4 (scl                ), // 1 
	.probe5 (mosi               ), // 1
	.probe6 (ram_rfsoc_en       ), // 1 
	.probe7 (ram_rfsoc_wren     ), // 1 
	.probe8 (ram_rfsoc_addr     ), // 8  
	.probe9 (ram_rfsoc_din      )  // 16  
);

ila_z7ps_bccode_bram u_ila_z7ps_bccode_bram (
	.clk       (ram_bc_code_clk ), // input wire clk
	.probe0    (ram_bc_code_en  ), // input wire [0:0]  probe0  
	.probe1    (ram_bc_code_we  ), // input wire [3:0]  probe1 
	.probe2    (ram_bc_code_addr), // input wire [31:0]  probe2 
	.probe3    (ram_bc_code_din ), // input wire [31:0]  probe3 
	.probe4    (ram_bc_code_dout)  // input wire [31:0]  probe4 
);

ila_z7ps_angle_bram u_ila_z7ps_angle_bram (
	.clk    (ram_bc_angle_clk   ), // input wire clk
	.probe0 (ram_bc_angle_en    ), // input wire [0:0]  probe0  
	.probe1 (ram_bc_angle_we    ), // input wire [3:0]  probe1 
	.probe2 (ram_bc_angle_addr  ), // input wire [31:0]  probe2 
	.probe3 (ram_bc_angle_din   ), // input wire [31:0]  probe3 
	.probe4 (ram_bc_angle_dout  )  // input wire [31:0]  probe4
);

ila_z7ps_txen_bram u_ila_z7ps_txen_bram (
	.clk                     (bram_tx_sel_clk       ), // input wire clk
	.probe0                  (bram_tx_sel_en        ),  //1
	.probe1                  (bram_tx_sel_we        ),  //4
	.probe2                  (bram_tx_sel_addr      ),  //32
	.probe3                  (bram_tx_sel_din       ),  //32
	.probe4                  (bram_tx_sel_dout      )   //32
);

`endif
endmodule

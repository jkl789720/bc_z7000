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
    input                         sclk                  ,
    input                         cs_n                  ,
    input                         mosi                  ,

    input                         prf_rf_in             ,//           
    input                         tr_en                 ,
    input                         image_start           ,
    input                         bc_angle_done         ,//

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

//添加了一行注释


wire [31:0]   rama_addr  ;
wire          rama_clk   ;
wire [31:0]   rama_din   ;
wire [31:0]   rama_dout  ;
wire          rama_en    ;
wire          rama_rst   ;
wire [3:0]    rama_we    ;

wire [31:0]   ram_bc_angle_addr;
wire          ram_bc_angle_clk ;
wire [31:0]   ram_bc_angle_din ;
wire [31:0]   ram_bc_angle_dout;
wire          ram_bc_angle_en  ;
wire          ram_bc_angle_rst ;
wire [3:0]    ram_bc_angle_we;



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

 . rama_addr                (rama_addr           ),
 . rama_clk                 (rama_clk            ),
 . rama_din                 (rama_din            ),
 . rama_dout                (rama_dout           ),
 . rama_en                  (rama_en             ),
 . rama_rst                 (rama_rst            ),
 . rama_we                  (rama_we             ),

 . ram_bc_angle_addr        (ram_bc_angle_addr   ),
 . ram_bc_angle_clk         (ram_bc_angle_clk    ),
 . ram_bc_angle_din         (ram_bc_angle_din    ),
 . ram_bc_angle_dout        (ram_bc_angle_dout   ),
 . ram_bc_angle_en          (ram_bc_angle_en     ),
 . ram_bc_angle_rst         (ram_bc_angle_rst    ),
 . ram_bc_angle_we          (ram_bc_angle_we     ),

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
    . sys_clk 	    (sys_clk 	    )       ,
    . sys_rst 	    (sys_rst 	    )       ,
    . prf_pin_in    (prf_pin_in     )       ,
    . tr_en         (tr_en          )       ,
    . image_start   (image_start    )       ,
    . rama_clk      (rama_clk       )       ,
	. rama_en       (rama_en        )       ,
	. rama_we       (rama_we        )       ,
	. rama_addr     (rama_addr      )       ,
	. rama_din      (rama_din       )       ,
	. rama_dout     (rama_dout      )       ,
	. rama_rst      (rama_rst       )       ,
    . app_param0    (app_param0     )  	    ,
    . app_param1    (app_param1     )  	    ,
    . app_param2    (app_param2     )  	    ,
    . app_param3    (app_param3     )  	    ,
    . app_status0   (app_status0    )	    ,
    . app_status1   (app_status1    )	    ,
    . BC1_SEL       (BC1_SEL        )       ,
    . BC1_CLK       (BC1_CLK        )       ,
    . BC1_DATA      (BC1_DATA       )       ,
    . BC1_LD        (BC1_LD         )       ,
    . BC1_TRR       (BC1_TRR        )       ,
    . BC1_TRT       (BC1_TRT        )       ,
    . BC2_SEL       (BC2_SEL        )       ,
    . BC2_CLK       (BC2_CLK        )       ,
    . BC2_DATA      (BC2_DATA       )       ,
    . BC2_LD        (BC2_LD         )       ,
    . BC2_TRT       (BC2_TRT        )       ,
    . BC2_TRR       (BC2_TRR        )       ,
    . BC_RST        (BC_RST         )       
);

bram_beam u_bram_beam (
  .clka (clka ),    // input wire clka
  .ena  (ena  ),      // input wire ena
  .wea  (wea  ),      // input wire [0 : 0] wea
  .addra(addra),  // input wire [7 : 0] addra
  .dina (dina ),    // input wire [15 : 0] dina
  .douta(douta),  // output wire [15 : 0] douta
  .clkb (ram_bc_angle_clk ),    // input wire clkb
  .enb  (ram_bc_angle_en  ),      // input wire enb
  .web  (ram_bc_angle_we[0]  ),      // input wire [0 : 0] web
  .addrb(ram_bc_angle_addr >> 2),  // input wire [6 : 0] addrb
  .dinb (ram_bc_angle_din ),    // input wire [31 : 0] dinb
  .doutb(ram_bc_angle_dout)  // output wire [31 : 0] doutb
);





`ifdef DEBUG    
ila_bram u_ila_bram (
	.clk       (sys_clk  ), // input wire clk
	.probe0    (rama_en  ), // input wire [0:0]  probe0  
	.probe1    (rama_we  ), // input wire [3:0]  probe1 
	.probe2    (rama_addr), // input wire [14:0]  probe2 
	.probe3    (rama_din ), // input wire [31:0]  probe3 
	.probe4    (rama_dout), // input wire [31:0]  probe4 
	.probe5    (rama_clk ),  // input wire [0:0]  probe5
	.probe6    (tr_o_a   )  // input wire [0:0]  probe5
);
`endif
endmodule

//------------------2023/12/29注解--------------------//
//g3换成g2只需要更改 LANE_BIT 和 FRAME_DATA_BIT两个参数即可
//可以把四组波控信号连接到一起，然后继续用这个程序实现并行控制，毕竟16跟数据线是独立的 26 106
`include "configure.vh"
//-------------------需要加入选择-------------------------//
//assign BC_B_TXEN   = tr_o; 设置一个分配器开关，来选择A或B天线阵列

//G2
//18us   900
//3ms    150_000
//G3
//21us   1050
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
    input  [7:0]                  sd_back               ,

//rfsoc_communication
    input                         scl                  ,
    input                         cs_n                  ,
    input                         mosi                  ,

    input                         prf_rf_in             ,//           
    input                         tr_en                 ,
    input                         tr_force_rx           ,//

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
    output                          BC_UART_ADJUST_TX  ,

    output                          frame_valid_s      ,
    output                          bc_code_valid

);
wire rst_sof;
wire reset;


assign tr_en_o = tr_en;
`ifndef TB_TEST
wire  sys_rst;
vio_reset u_vio_reset (
  .clk          (sys_clk    ),
  .probe_out0   (sys_rst    )  
);
`endif

//娣诲姞浜嗕竴琛屾敞閲?

//PS
wire          rama_clk   ;
wire          rama_en    ;
wire [3:0]    rama_we    ;
wire [31:0]   rama_addr  ;
wire [31:0]   rama_din   ;
wire [31:0]   rama_dout  ;
wire          rama_rst   ;


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



wire [31:0]   app_param0 ;
wire [31:0]   app_param1 ;
wire [31:0]   app_param2 ;
wire [31:0]   app_param3 ;

wire [31:0]   app_status0;
wire [31:0]   app_status1;




cpu_sys_wrapper u_cpu_sys_wrapper(
    . app_param0                (app_param0           ),
    . app_param1                (app_param1           ),
    . app_param2                (app_param2           ),
    . app_param3                (app_param3           ),

    . app_status0               (app_status0          ),
    . app_status1               (app_status1          ),

    . rama_clk                  (rama_clk             ),
    . rama_en                   (rama_en              ),
    . rama_we                   (rama_we              ),
    . rama_addr                 (rama_addr            ),
    . rama_din                  (rama_din             ),
    . rama_dout                 (rama_dout            ),
    . rama_rst                  (rama_rst             ),


    . ram_bc_angle_addr         (ram_bc_angle_addr    ),
    . ram_bc_angle_clk          (ram_bc_angle_clk     ),
    . ram_bc_angle_din          (ram_bc_angle_din     ),
    . ram_bc_angle_dout         (ram_bc_angle_dout    ),
    . ram_bc_angle_en           (ram_bc_angle_en      ),
    . ram_bc_angle_rst          (ram_bc_angle_rst     ),
    . ram_bc_angle_we           (ram_bc_angle_we      ),

    . bc_uart_adjust_rxd        (BC_UART_ADJUST_RX    ),
    . bc_uart_adjust_txd        (BC_UART_ADJUST_TX    )
 );



 bc_wrapper#(
    `ifndef G3
    . LANE_BIT                      (LANE_BIT             )         ,
    . FRAME_DATA_BIT                (FRAME_DATA_BIT       )         ,
    `else
    . LANE_BIT                      (LANE_BIT             )         ,
    . FRAME_DATA_BIT                (FRAME_DATA_BIT       )         ,
    `endif       
    . GROUP_CHIP_NUM                (GROUP_CHIP_NUM       )         ,
    . GROUP_NUM                     (GROUP_NUM            )         ,
    . SCLHZ                         (SCLHZ                )         ,
    . DATA_BIT                      (DATA_BIT             )         ,
    . SYSHZ                         (SYSHZ                )         ,
    . READ_PORT_BYTES               (READ_PORT_BYTES      )         ,
    . WRITE_PORT_BYTES              (WRITE_PORT_BYTES     )         ,
    . BEAM_BYTES                    (BEAM_BYTES           )         ,
    . CMD_BIT                       (CMD_BIT              )         ,
    . BEAM_NUM                      (BEAM_NUM             )
                                                          )
u_bc_wrapper                     (
    . sys_clk 	                    (sys_clk 	          )         ,
    . sys_rst 	                    (sys_rst 	          )         ,//上电只复位一次，用sys_rst
    . prf_pin_in                    (prf_pin_in           )         ,
    . prf_rf_in                     (prf_rf_in            )         ,
    . sd_back                       (sd_back              )         ,
    . tr_en                         (tr_en                )         ,
    . tr_force_rx                   (tr_force_rx          )         ,

    . rama_clk                      (rama_clk             )         ,
	. rama_en                       (rama_en              )         ,
	. rama_we                       (rama_we              )         ,
	. rama_addr                     (rama_addr            )         ,
	. rama_din                      (rama_din             )         ,
	. rama_dout                     (rama_dout            )         ,
	. rama_rst                      (rama_rst             )         ,

    . app_param0                    (app_param0           )  	    ,
    . app_param1                    (app_param1           )  	    ,
    . app_param2                    (app_param2           )  	    ,
    . app_param3                    (app_param3           )  	    ,
    . app_status0                   (app_status0          )	        ,
    . app_status1                   (app_status1          )	        ,

    . BC1_SEL                       (BC1_SEL              )         ,
    . BC1_CLK                       (BC1_CLK              )         ,
    . BC1_DATA                      (BC1_DATA             )         ,
    . BC1_LD                        (BC1_LD               )         ,
    . BC1_TRR                       (BC1_TRR              )         ,
    . BC1_TRT                       (BC1_TRT              )         ,
    . BC2_SEL                       (BC2_SEL              )         ,
    . BC2_CLK                       (BC2_CLK              )         ,
    . BC2_DATA                      (BC2_DATA             )         ,
    . BC2_LD                        (BC2_LD               )         ,
    . BC2_TRT                       (BC2_TRT              )         ,
    . BC2_TRR                       (BC2_TRR              )         ,
    . BC_RST                        (BC_RST               )       
);

rfsoc_2z7000 u_rfsoc_2z7000(
. sys_clk       (sys_clk        )  ,
. sys_rst       (reset        )  ,
. cs_n          (cs_n           )  ,
. scl           (scl            )  ,
. mosi          (mosi           )  ,
. ram_rfsoc_clk (ram_rfsoc_clk  )  ,
. ram_rfsoc_en  (ram_rfsoc_en   )  ,
. ram_rfsoc_wren(ram_rfsoc_wren )  ,
. ram_rfsoc_addr(ram_rfsoc_addr )  ,
. ram_rfsoc_din (ram_rfsoc_din  )

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


assign rst_sof = app_param1[7];
reg [1:0] rst_sof_r;
always@(posedge sys_clk)begin
    if(!sys_rst)begin
        rst_sof_r <= 2'b00;
    end else begin
        rst_sof_r <= {rst_sof_r[0],rst_sof};
    end
end
assign reset = rst_sof_r[1] | sys_rst;


`ifdef DEBUG    
ila_rfsoc2z7 u_ila_rfsoc2z7 (
	.clk    (sys_clk            ), // input wire clk
	.probe0 (prf_rf_in          ), // 1 
	.probe1 (tr_en              ), // 1 
	.probe2 (cs_n               ), // 1 
	.probe3 (scl                ), // 1 
	.probe4 (mosi               ), // 1
	.probe5 (ram_rfsoc_en       ), // 1 
	.probe6 (ram_rfsoc_wren     ), // 1 
	.probe7 (ram_rfsoc_addr     ), // 32  
	.probe8 (ram_rfsoc_din      ),  // 32  
	.probe9 (frame_valid_s      )  // 1  
);

ila_ps_angle_bram_rw u_ila_ps_angle_bram_rw (
	.clk    (ram_bc_angle_clk   ), // input wire clk
	.probe0 (ram_bc_angle_en    ), // input wire [0:0]  probe0  
	.probe1 (ram_bc_angle_we    ), // input wire [3:0]  probe1 
	.probe2 (ram_bc_angle_addr  ), // input wire [31:0]  probe2 
	.probe3 (ram_bc_angle_din   ), // input wire [31:0]  probe3 
	.probe4 (ram_bc_angle_dout  )  // input wire [31:0]  probe4
);

ila_bccode_bram_rw u_ila_rama_rw (
	.clk       (rama_clk ), // input wire clk
	.probe0    (rama_en  ), // input wire [0:0]  probe0  
	.probe1    (rama_we  ), // input wire [3:0]  probe1 
	.probe2    (rama_addr), // input wire [31:0]  probe2 
	.probe3    (rama_din ), // input wire [31:0]  probe3 
	.probe4    (rama_dout)  // input wire [31:0]  probe4 
);


assign frame_valid_s = ram_rfsoc_en && ram_rfsoc_wren && ram_rfsoc_addr == 8191 && ram_rfsoc_din == 1;
assign bc_code_valid = app_param1[0];
`endif
endmodule

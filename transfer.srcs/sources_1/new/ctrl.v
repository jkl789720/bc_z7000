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
    parameter SCLHZ            = 1_000_000                      ,



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
wire rst_sof;
wire reset;


assign tr_en_o = tr_en;
assign bc_data_done_o = bc_data_done;
`ifndef TB_TEST
wire  sys_rst;
vio_reset u_vio_reset (
  .clk          (sys_clk    ),
  .probe_out0   (sys_rst    )  
);
`endif

//娣诲姞浜嗕竴琛屾敞閲?

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

wire                          ram_bc_init_clk    ;
wire                          ram_bc_init_en     ;
wire [3:0]                    ram_bc_init_we     ;
wire [31:0]                   ram_bc_init_addr   ;
wire [31:0]                   ram_bc_init_din    ;
wire [31:0]                   ram_bc_init_dout   ;
wire                          ram_bc_init_rst    ;

wire                          ram_bc_init_clk_back  ;
wire                          ram_bc_init_en_back   ;
wire [3:0]                    ram_bc_init_we_back   ;
wire [31:0]                   ram_bc_init_addr_back ;
wire [31:0]                   ram_bc_init_din_back  ;
wire [31:0]                   ram_bc_init_dout_back ;
wire                          ram_bc_init_rst_back  ;



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


//---------------------娉㈡帶鐮佹楠?------------------------//
wire             clka_check ;
wire             ena_check  ;
wire [3:0]       wea_check  ;
wire [31:0]      addra_check;
wire [31:0]      dina_check ;
wire [31:0]      douta_check;
wire [31:0]      rama_rst_check;

wire [31:0]      spi_clk;
wire [31:0]      spi_cs_n;
wire [31:0]      spi_mosi;
wire [31:0]      beam_pos_num;



cpu_sys_wrapper u_cpu_sys_wrapper(
    . app_param0                (app_param0           ),
    . app_param1                (app_param1           ),
    . app_param2                (app_param2           ),
    . app_param3                (app_param3           ),

    . app_status0               (app_status0          ),
    . app_status1               (app_status1          ),

    . rama_clk                  (ram_bc_code_clk      ),
    . rama_en                   (ram_bc_code_en       ),
    . rama_we                   (ram_bc_code_we       ),
    . rama_addr                 (ram_bc_code_addr     ),
    . rama_din                  (ram_bc_code_din      ),
    . rama_dout                 (ram_bc_code_dout     ),
    . rama_rst                  (ram_bc_code_rst      ),


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

    . rama_clk                      (ram_bc_code_clk      )         ,
	. rama_en                       (ram_bc_code_en       )         ,
	. rama_we                       (ram_bc_code_we       )         ,
	. rama_addr                     (ram_bc_code_addr     )         ,
	. rama_din                      (ram_bc_code_din      )         ,
	. rama_dout                     (ram_bc_code_dout     )         ,
	. rama_rst                      (ram_bc_code_rst      )         ,

    . bram_tx_sel_clk               (bram_tx_sel_clk      )         ,
	. bram_tx_sel_en                (bram_tx_sel_en       )         ,
	. bram_tx_sel_we                (bram_tx_sel_we       )         ,
	. bram_tx_sel_addr              (bram_tx_sel_addr     )         ,
	. bram_tx_sel_din               (bram_tx_sel_din      )         ,
	. bram_tx_sel_dout              (bram_tx_sel_dout     )         ,
	. bram_tx_sel_rst               (bram_tx_sel_rst      )         ,

    . ram_bc_init_clk               (ram_bc_init_clk      )         ,
    . ram_bc_init_en                (ram_bc_init_en       )         ,
    . ram_bc_init_we                (ram_bc_init_we       )         ,
    . ram_bc_init_addr              (ram_bc_init_addr     )         ,
    . ram_bc_init_din               (ram_bc_init_din      )         ,
    . ram_bc_init_dout              (ram_bc_init_dout     )         ,
    . ram_bc_init_rst               (ram_bc_init_rst      )         ,

    . ram_bc_init_clk_back          (ram_bc_init_clk_back )         ,
    . ram_bc_init_en_back           (ram_bc_init_en_back  )         ,
    . ram_bc_init_we_back           (ram_bc_init_we_back  )         ,
    . ram_bc_init_addr_back         (ram_bc_init_addr_back)         ,
    . ram_bc_init_din_back          (ram_bc_init_din_back )         ,
    . ram_bc_init_dout_back         (ram_bc_init_dout_back)         ,
    . ram_bc_init_rst_back          (ram_bc_init_rst_back )         ,

    . clka_check                    (clka_check           )         ,
    . ena_check                     (ena_check            )         ,
    . wea_check                     (wea_check            )         ,
    . addra_check                   (addra_check          )         ,
    . dina_check                    (dina_check           )         ,
    . douta_check                   (douta_check          )         ,
    . rama_rst_check                   (rama_rst_check          )         ,
    
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
. bc_data_done  (bc_data_done   )  ,
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
	.probe2 (bc_data_done       ), // 1 
	.probe3 (cs_n               ), // 1 
	.probe4 (scl                ), // 1 
	.probe5 (mosi               ), // 1
	.probe6 (ram_rfsoc_en       ), // 1 
	.probe7 (ram_rfsoc_wren     ), // 1 
	.probe8 (ram_rfsoc_addr     ), // 32  
	.probe9 (ram_rfsoc_din      )  // 32  
);

ila_bccode_bram_rw u_ila_bccode_bram_rw (
	.clk       (ram_bc_code_clk ), // input wire clk
	.probe0    (ram_bc_code_en  ), // input wire [0:0]  probe0  
	.probe1    (ram_bc_code_we  ), // input wire [3:0]  probe1 
	.probe2    (ram_bc_code_addr), // input wire [31:0]  probe2 
	.probe3    (ram_bc_code_din ), // input wire [31:0]  probe3 
	.probe4    (ram_bc_code_dout)  // input wire [31:0]  probe4 
);

ila_ps_angle_bram_rw u_ila_ps_angle_bram_rw (
	.clk    (ram_bc_angle_clk   ), // input wire clk
	.probe0 (ram_bc_angle_en    ), // input wire [0:0]  probe0  
	.probe1 (ram_bc_angle_we    ), // input wire [3:0]  probe1 
	.probe2 (ram_bc_angle_addr  ), // input wire [31:0]  probe2 
	.probe3 (ram_bc_angle_din   ), // input wire [31:0]  probe3 
	.probe4 (ram_bc_angle_dout  )  // input wire [31:0]  probe4
);

ila_ps_txen_bram_rw u_ila_ps_txen_bram_rw (
	.clk                     (bram_tx_sel_clk       ), // input wire clk
	.probe0                  (bram_tx_sel_en        ),  //1
	.probe1                  (bram_tx_sel_we        ),  //4
	.probe2                  (bram_tx_sel_addr      ),  //32
	.probe3                  (bram_tx_sel_din       ),  //32
	.probe4                  (bram_tx_sel_dout      )   //32
);

// ram_z7_check u_ram_z7_check(
// .  sys_rst          (reset         ), 
// .  rama_clk         (ram_rfsoc_clk   ),
// .  rama_en          (ram_rfsoc_en    ),
// .  rama_wren        (ram_rfsoc_wren  ),
// .  rama_addr        (ram_rfsoc_addr  ),
// .  rama_din         (ram_rfsoc_din   )
// );

// //---------------------娉㈡帶鐮佹楠?------------------------//
// assign beam_pos_num = app_param2;
// assign spi_clk = signal_expansion(BC2_CLK,BC1_CLK);
// assign spi_cs_n = signal_expansion(BC2_SEL,BC1_SEL);
// assign spi_mosi = {BC2_DATA,BC1_DATA};
// check_wrapper #(
//     .CHANNEL_NUM  (32 ),
//     .BIT_NUM      (106)
// )
//  u_check_wrapper (
//     .clk                     ( sys_clk            ),
//     .rst_n                   ( ~reset           ),
//     .spi_clk                 ( spi_clk            ),
//     .spi_cs_n                ( spi_cs_n           ),
//     .spi_mosi                ( spi_mosi           ),
//     .beam_pos_num            ( beam_pos_num       ),
//     .clka                    ( clka_check         ),
//     .ena                     ( ena_check          ),
//     .wea                     ( wea_check[0]       ),
//     .addra                   ( addra_check[31:2]  ),
//     .dina                    ( dina_check         ),
//     .douta                   ( douta_check        )
// );

// ila_check_back_ram_r u_u_ila_check_back_ram_r (
// 	.clk(clka_check), // input wire clk


// 	.probe0(ena_check), // input wire [0:0]  probe0  
// 	.probe1(wea_check), // input wire [0:0]  probe1 
// 	.probe2(addra_check), // input wire [3:0]  probe2 
// 	.probe3(dina_check), // input wire [31:0]  probe3 
// 	.probe4(douta_check) // input wire [31:0]  probe4 
// );





// function [31:0] signal_expansion;
//     input [3:0] sig1;//绗竴涓疄鍙?
//     input [3:0] sig0;//绗簩涓疄鍙?
//     begin
//         signal_expansion = {
//                         {4{sig1[3]}},{4{sig1[2]}},{4{sig1[1]}},{4{sig1[0]}},
//                         {4{sig0[3]}},{4{sig0[2]}},{4{sig0[1]}},{4{sig0[0]}}
//         };
//     end
// endfunction

`endif
endmodule

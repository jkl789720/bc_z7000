//------------------2023/12/29注解--------------------//
//g3换成g2只需要更改 LANE_BIT 和 FRAME_DATA_BIT两个参数即可
//可以把四组波控信号连接到一起，然后继续用这个程序实现并行控制，毕竟16跟数据线是独立的 26 106
`include "configure.vh"
//assign BC_B_TXEN   = tr_o; 设置一个分配器开关，来选择A或B天线阵列
//1201us  spi:243024
module bc_wrapper_new
(
  	input 					          sys_clk 	     ,
  	input 					          sys_rst 	     ,
	input                             prf_pin_in     ,
    input                             tr_en          ,


	input                	          rama_clk       ,
	input                             rama_en        ,
	input   [3 : 0]                   rama_we        ,
	input   [31 : 0]                  rama_addr      ,
	input   [31 : 0]                  rama_din       ,
	output  [31 : 0]                  rama_dout      ,
	input                             rama_rst       ,

    input  [31:0] 			          app_param0	 ,
    input  [31:0] 			          app_param1	 ,
    input  [31:0] 			          app_param2	 ,
    output [31:0] 			          app_status0	 ,
    output [31:0] 			          app_status1	 ,

    output                            BC_B_CLK       ,
    output                            BC_B_CS        ,
    output [3:0]                      BC_B_TXD       

); 

//-------------------------spi_o端口定义----------------------------//
wire                  reset        ;

wire [DATA_BIT-1:0]   data_in      ;
wire                  trig         ;
wire                  sel_o        ;
wire                  scl_o        ;
wire     [3:0]        sd_o         ;

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


wire reset;
//-------------------wire declare----------------------//
//spi
wire [DATA_BIT-1:0]        data_in          ;
wire                       trig             ;
wire 					   mode			    ;

wire                       prf_in           ;
wire                       ld_mode_in       ;
wire 					   send_flag_in	    ;
wire 					   single_lane      ;
wire                       tr_mode          ;
wire                       polarization_mode;
wire                       temper_req       ;
wire                       temper_data_valid;

wire [31:0]                beam_pos_num     ;

wire                       temper_ready     ;
wire                       temper_en        ;

wire                       temper_read_done     ;


//--cpu_o_ctrl&&mode
wire 					   prf_mode_in          ;
wire 					   prf_start_in         ;

wire 					   cpu_dat_sd_en        ;


wire                       bc_group_send_done   ;//一个组发送完，而不是整个波位发送完成，这是区分于温度命名的
wire                       ld_done              ;
wire                       now_beam_send_done   ;
wire [31:0] 			   app_param3	        ;
// wire [31:0] 			   app_status0	 ;

wire rd_done = 0;

wire                       scl_o    	 ;
wire                       sel_o         ;
wire                       cmd_flag      ;
wire [GROUP_CHIP_NUM-1:0]  sd_o          ;
wire                       dary_o        ;
wire                       ld_o          ;
wire                       tr_o          ;
wire                       trt_o         ;
wire                       trr_o         ;
wire                       rst_o         ;

wire  [7:0]                temper_data0  ;
wire  [7:0]                temper_data1  ;
wire  [7:0]                temper_data2  ;
wire  [7:0]                temper_data3  ;



wire                       bc_ram_clk        ;
wire                       bc_ram_en         ;
wire [3:0]                 bc_ram_we         ;
wire [23:0]                bc_ram_addr       ;
wire [31:0]                bc_ram_din        ;
wire [31:0]                bc_ram_dout       ;
wire                       bc_ram_rst        ;

wire                       delay_ram_clk     ;
wire                       delay_ram_en      ;
wire [3:0]                 delay_ram_we      ;
wire [23:0]                delay_ram_addr    ;
wire [31:0]                delay_ram_din     ;
wire [31:0]                delay_ram_dout    ;
wire                       delay_ram_rst     ;

wire [31:0] bc_top_addr; 
wire bc_flag;
assign bc_top_addr    = (((GROUP_NUM*GROUP_CHIP_NUM) << 4))*BEAM_NUM;
assign delay_ram_clk  = rama_clk;
assign delay_ram_en   = (~bc_flag) ? rama_en: 0;
assign delay_ram_we   = (~bc_flag) ? rama_we: 0;
assign delay_ram_addr = (~bc_flag) ? rama_addr - (bc_top_addr) : 0;
assign delay_ram_din  = (~bc_flag) ? rama_din : 0;

assign delay_ram_rst = rama_rst;

assign bc_ram_clk  = rama_clk;
assign bc_ram_en   = bc_flag ? rama_en: 0;
assign bc_ram_we   = bc_flag ? rama_we: 0;
assign bc_ram_addr = bc_flag ? rama_addr : 0;
assign bc_ram_din  = bc_flag ? rama_din : 0;

assign bc_ram_rst = rama_rst;

assign rama_dout = (rama_addr >= bc_top_addr) ? delay_ram_dout: bc_ram_dout;
assign bc_flag = (rama_addr < bc_top_addr);

//reg

	assign prf_start_in         = app_param0[0];
	assign prf_mode_in          = app_param0[1];
	assign ld_mode_in           = app_param0[2];
	assign send_flag_in         = app_param0[3];
	assign single_lane          = app_param0[4];
	assign tr_mode              = app_param0[5];
	assign polarization_mode    = app_param0[6];
    assign temper_req           = app_param0[7];

	assign valid_in     = app_param1[0];
	assign beam_pos_num	= app_param2   ;
	//cpu_i_gen
	assign app_status0          = `ID_NUM;
    assign app_status1          = {31'b0,temper_data_valid};



//---------已经不起作用了,可随时删除，暂留以备后续
cpu_ctrl_sig_gen u_cpu_ctrl_sig_gen(
. sys_rst       (sys_rst      ) ,
. sys_clk       (sys_clk      ) ,
. prf_in        (prf_in       ) ,
. valid_in      (valid_in     ) ,
. rd_done       (rd_done      ) ,
. cpu_dat_sd_en (cpu_dat_sd_en) ,
. data_sending  (data_sending ) 
);

wave_ctrl_sig_gen#(
    .LANE_BIT         (LANE_BIT         ),
    .FRAME_DATA_BIT   (FRAME_DATA_BIT   ),
    .GROUP_CHIP_NUM   (GROUP_CHIP_NUM   ),
    .GROUP_NUM        (GROUP_NUM        ),
    .DATA_BIT         (DATA_BIT         ),
    .SYSHZ            (SYSHZ            ),
    .SCLHZ            (SCLHZ            ),
    .READ_PORT_BYTES  (READ_PORT_BYTES  ),
    .WRITE_PORT_BYTES (WRITE_PORT_BYTES ),
    .BEAM_BYTES       (BEAM_BYTES       ),
    .CMD_BIT          (CMD_BIT          ),
    .BEAM_NUM         (BEAM_NUM         )
)
u_wave_ctrl_sig_gen(
. sys_clk       		(sys_clk       		),
. reset       		    (reset       		),
. prf_pin_in    		(prf_pin_in    		),
. prf_start_in  		(prf_start_in  		),
. prf_mode_in   		(prf_mode_in   		),
. prf           		(prf_in             ),
. ld_o	                (ld_o	            ),
. send_flag_in			(send_flag_in	    ),
. single_lane			(single_lane		),
. tr_mode				(tr_mode			),
. tr_en				    (tr_en				),
. tr_o				    (tr_o				),
. trt_o				    (trt_o				),
. trr_o				    (trr_o				)
);
		

send_data_gen#(
    .LANE_BIT         (LANE_BIT         ),
    .FRAME_DATA_BIT   (FRAME_DATA_BIT   ),
    .GROUP_CHIP_NUM   (GROUP_CHIP_NUM   ),
    .GROUP_NUM        (GROUP_NUM        ),
    .DATA_BIT         (DATA_BIT         ),
    .SYSHZ            (SYSHZ            ),
    .SCLHZ            (SCLHZ            ),
    .READ_PORT_BYTES  (READ_PORT_BYTES  ),
    .WRITE_PORT_BYTES (WRITE_PORT_BYTES ),
    .BEAM_BYTES       (BEAM_BYTES       ),
    .CMD_BIT          (CMD_BIT          ),
    .BEAM_NUM         (BEAM_NUM         )
)
u_send_data_gen(
.  sys_clk  	        (sys_clk 	            ) ,
.  sys_rst  	        (sys_rst 	            ) ,

.  bc_ram_clk           (bc_ram_clk             ) ,
.  bc_ram_en            (bc_ram_en              ) ,
.  bc_ram_we            (bc_ram_we              ) ,
.  bc_ram_addr          (bc_ram_addr            ) ,
.  bc_ram_din           (bc_ram_din             ) ,
.  bc_ram_dout          (bc_ram_dout            ) ,
.  bc_ram_rst           (bc_ram_rst             ) ,

.  delay_ram_clk        (delay_ram_clk          ) ,
.  delay_ram_en         (delay_ram_en           ) ,
.  delay_ram_we         (delay_ram_we           ) ,
.  delay_ram_addr       (delay_ram_addr         ) ,
.  delay_ram_din        (delay_ram_din          ) ,
.  delay_ram_dout       (delay_ram_dout         ) ,
.  delay_ram_rst        (delay_ram_rst          ) ,

.  valid_in 	        (valid_in	            ) ,
.  beam_pos_num	        (beam_pos_num           ) ,
.  prf_in      	        (prf_in                 ) ,
.  data_in  	        (data_in  	            ) ,
.  trig     	        (trig     	            ) ,
.  mode  		        (mode    	            ) ,
.  bc_group_send_done   (bc_group_send_done     ) ,
.  now_beam_send_done   (now_beam_send_done     ) ,
.  ld_mode_in  	        (ld_mode_in             ) ,
.  ld_o  	            (ld_o                   ) ,
.  dary_o  	            (dary_o                 ) ,
.  temper_en            (temper_en              ) ,
.  temper_read_done     (temper_read_done       ) ,
.  temper_req           (temper_req             ) ,
.  reset                (reset                  ) 
);

temperature #(
    .LANE_BIT         (LANE_BIT         ),
    .FRAME_DATA_BIT   (FRAME_DATA_BIT   ),
    .GROUP_CHIP_NUM   (GROUP_CHIP_NUM   ),
    .GROUP_NUM        (GROUP_NUM        ),
    .DATA_BIT         (DATA_BIT         ),
    .SYSHZ            (SYSHZ            ),
    .SCLHZ            (SCLHZ            ),
    .READ_PORT_BYTES  (READ_PORT_BYTES  ),
    .WRITE_PORT_BYTES (WRITE_PORT_BYTES ),
    .BEAM_BYTES       (BEAM_BYTES       ),
    .CMD_BIT          (CMD_BIT          ),
    .BEAM_NUM         (BEAM_NUM         )
)u_temperature (
    .sys_clk                 ( sys_clk             ),
    .reset                   ( reset               ),
    .data_in                 ( data_in             ),
    .trig                    ( trig                ),
    .mode                    ( mode                ),
    .temper_en               ( temper_en           ),
    .sd_i                    ( sd_i                ),
    .sel_o                   ( sel_o               ),
    .cmd_flag                ( cmd_flag            ),
    .scl_o                   ( scl_o               ),
    .sd_o                    ( sd_o                ),
    .rst_o                   ( rst_o               ),
    .bc_group_send_done      ( bc_group_send_done  ),
    .temper_data0            ( temper_data0        ),
    .temper_data1            ( temper_data1        ),
    .temper_data2            ( temper_data2        ),
    .temper_data3            ( temper_data3        ),
    .temper_data_valid       ( temper_data_valid   ),
    .temper_read_done        ( temper_read_done    )
);

`ifdef DEBUG
wire [15:0] sd;
assign sd = sd_o;

ila_top u_ila_top (
	.clk	        (sys_clk	  ), 
	.probe0	        (PLUART_txd	  ), 
	.probe1	        (PLUART_rxd	  ),
    .probe2         (sd           ),
    .probe3         (sel_o        ),
    .probe4         (cmd_flag     ),
    .probe5         (scl_o        ),
    .probe6         (dary_o       ),
    .probe7         (ld_o         ),
    .probe8         (trt_o        ),
    .probe9         (trr_o        ),
    .probe10        (prf_pin_in   )
);

vio_sys u_vio_sys (
.clk          (sys_clk 	    ),
.probe_in0    (prf_mode_in  ),
.probe_in1    (ld_mode_in   ),
.probe_in2    (send_flag_in ),
.probe_in3    (valid_in     ),
.probe_in4    (beam_pos_num ),
.probe_in5    (single_lane  ),
.probe_out0   (sys_rst_vio  )
);

`endif

`ifdef SAR
    assign sel_o_a    = sel_o    ;
    assign cmd_flag_a = cmd_flag ;
    assign scl_o_a    = scl_o    ;
    assign sd_o_a     = sd_o     ;
    assign ld_o_a     = ld_o     ;
    assign tr_o_a     = tr_o && (~polarization_mode)     ;
    assign rst_o_a    = rst_o    ;

    assign sel_o_b    = sel_o    ;
    assign cmd_flag_b = cmd_flag ;
    assign scl_o_b    = scl_o    ;
    assign sd_o_b     = sd_o     ;
    assign ld_o_b     = ld_o     ;
    assign tr_o_b     = tr_o && polarization_mode     ;
    assign rst_o_b    = rst_o    ;
`else
    assign sel_o_h    = sel_o    ;
    assign scl_o_h    = scl_o    ;
    assign sd_o_h     = sd_o     ;
    assign dary_o_h   = dary_o   ;
    assign ld_o_h     = ld_o     ;
    assign trt_o_h    = trt_o    ;
    assign trr_o_h    = trr_o    ;
    assign rst_o_h    = rst_o    ;
`endif

endmodule
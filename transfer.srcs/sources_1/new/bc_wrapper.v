//------------------2023/12/29注解--------------------//
//g3换成g2只需要更改 LANE_BIT 和 FRAME_DATA_BIT两个参数即可
//可以把四组波控信号连接到一起，然后继续用这个程序实现并行控制，毕竟16跟数据线是独立的 26 106
`include "configure.vh"
//assign BC_B_TXEN   = tr_o; 设置一个分配器开关，来选择A或B天线阵列
//1201us  spi:243024
module bc_wrapper#(
    `ifndef G3
    parameter LANE_BIT         = 20                              ,
    parameter FRAME_DATA_BIT   = 80                              ,
    `else
    parameter LANE_BIT         = 26                              ,
    parameter FRAME_DATA_BIT   = 106                             ,
    `endif       
    
    parameter GROUP_CHIP_NUM   = 4                               ,
    parameter GROUP_NUM        = 4                               ,
    parameter SCLHZ            = 10_000_000                      ,



    parameter DATA_BIT         = FRAME_DATA_BIT * GROUP_CHIP_NUM ,
    parameter SYSHZ            = 50_000_000                      ,
    parameter READ_PORT_BYTES  = 16                              ,
    parameter WRITE_PORT_BYTES = 4                               ,
    parameter BEAM_BYTES       = GROUP_CHIP_NUM * GROUP_NUM * 16 ,
    parameter CMD_BIT          = 10                              ,
    parameter BEAM_NUM         = 1024
)
(
  	input 					          sys_clk 	     ,
  	input 					          sys_rst 	     ,
	input                             prf_pin_in     ,
    input                             tr_en          ,

    output                            sel_o_a        ,
    output                            cmd_flag_a     ,
    output                            scl_o_a    	 ,
    output [GROUP_CHIP_NUM-1:0]       sd_o_a         ,
    output                            ld_o_a         ,
    output                            tr_o_a         ,
    output                            rst_o_a        ,
        
    output                            sel_o_b        ,
    output                            cmd_flag_b     ,
    output                            scl_o_b    	 ,
    output [GROUP_CHIP_NUM-1:0]       sd_o_b         ,
    output                            ld_o_b         ,
    output                            tr_o_b         ,
    output                            rst_o_b        ,

    output                            sel_o_h        ,
    output                            scl_o_h    	 ,
    output [GROUP_CHIP_NUM-1:0]       sd_o_h         ,
    output                            ld_o_h         ,
    output                            dary_o_h       ,
    output                            trt_o_h        ,
    output                            trr_o_h        ,
    output                            rst_o_h        ,

    output [23:0]                     beam_pos_cnt   ,


	input                	          rama_clk       ,
	input                             rama_en        ,
	input  [3 : 0]                    rama_we        ,
	input  [31 : 0]                   rama_addr      ,
	input  [31 : 0]                   rama_din       ,
	output [31 : 0]                   rama_dout      ,
	input                             rama_rst       ,

    input  [31:0] 			          app_param0	 ,
    input  [31:0] 			          app_param1	 ,
    input  [31:0] 			          app_param2	 ,
    output [31:0] 			          app_status0	 ,
    output [31:0] 			          app_status1	 

); 


wire reset;//复位,包含了sys_rst、valid_pos、reset_sof

	// wire sys_clk_bufg,sys_clk;
//    IBUFDS IBUFDS_inst (
//       .O(sys_clk_bufg),   // 1-bit output: Buffer output
//       .I(sys_clk_P),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
//       .IB(sys_clk_n)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
//    );
//     BUFG BUFG_inst (
//     .O(sys_clk), // 1-bit output: Clock output
//     .I(sys_clk_bufg)  // 1-bit input: Clock input
//    );

//data_in



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

wire                       reset_sof            ;

wire [31:0]                cnt_bit;

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
wire [31:0]                bc_ram_addr       ;
wire [31:0]                bc_ram_din        ;
wire [31:0]                bc_ram_dout       ;
wire                       bc_ram_rst        ;

wire                       delay_ram_clk     ;
wire                       delay_ram_en      ;
wire [3:0]                 delay_ram_we      ;
wire [31:0]                delay_ram_addr    ;
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
reg [31:0] app_param0_r [1:0];
reg [31:0] app_param1_r [1:0];
reg [31:0] app_param2_r [1:0];
always@(posedge sys_clk)begin
    if(sys_rst)begin
        app_param0_r[0] <= 0;
        app_param1_r[0] <= 0;
        app_param2_r[0] <= 0;

        app_param0_r[1] <= 0;
        app_param1_r[1] <= 0;
        app_param2_r[1] <= 0;
    end
    else begin
        app_param0_r[0] <= app_param0;
        app_param1_r[0] <= app_param1;
        app_param2_r[0] <= app_param2;

        app_param0_r[1] <= app_param0_r[0];
        app_param1_r[1] <= app_param1_r[0];
        app_param2_r[1] <= app_param2_r[0];
    end
end
        

    assign prf_start_in         = app_param0_r[1][0];
    assign prf_mode_in          = app_param0_r[1][1];
    assign ld_mode_in           = app_param0_r[1][2];
    assign send_flag_in         = app_param0_r[1][3];//打拍
    assign single_lane          = app_param0_r[1][4];//打拍
    assign tr_mode              = app_param0_r[1][5];
    assign polarization_mode    = app_param0_r[1][6];


    assign valid_in     = app_param1_r[1][0];//打拍
    assign temper_req   = app_param1_r[1][1];//打拍
    assign bc_mode      = app_param1_r[1][5:2];//打拍
    assign sel_param    = app_param1_r[1][6];//打拍

    assign reset_sof    = app_param1_r[1][7];

    assign beam_pos_num	= app_param2_r[1]   ;
	//cpu_i_gen
	assign app_status0          = `ID_NUM;
    assign app_status1          = {31'b0,temper_data_valid};


//---------已经不起作用了,可随时删除，暂留以备后续
cpu_ctrl_sig_gen u_cpu_ctrl_sig_gen(
. sys_rst       (reset        ) ,
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
. reset       		    (reset              ),
. prf_pin_in    		(prf_pin_in    		),
. prf_start_in  		(prf_start_in  		),
. prf_mode_in   		(prf_mode_in   		),
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
.  sys_rst  	        (sys_rst | reset_sof    ) ,

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
.  reset                (reset                  ) ,
.  beam_pos_cnt         (beam_pos_cnt           ) 
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
    .temper_read_done        ( temper_read_done    ),
    .ld_o                    ( ld_o                ),
    .dary_o                  ( dary_o              ),
    .tr_o                    ( tr_o                ),
    .cnt_bit                 ( cnt_bit             )
);






// localparam DWIDTH = 100;
// reg [DWIDTH-1:0] CFGBC_OUTEN_r = 0;
// always@(posedge sys_clk)begin
//     if(sys_rst)
//         CFGBC_OUTEN_r <= 0;
//     else
// 	    CFGBC_OUTEN_r <= {CFGBC_OUTEN_r[DWIDTH-2:0], tr_o};
// end
// wire trt_cap;
// assign BC_A_TXD[0] = tr_o;
`ifdef DEBUG
wire [31:0] sd;
assign sd = sd_o;

ila_spi u_ila_spi (
	.clk	        (sys_clk	  ),// 
	.probe0	        (PLUART_txd	  ),//1  
	.probe1	        (PLUART_rxd	  ),//1 
    .probe2         (sd           ),//32
    .probe3         (sel_o        ),//1 
    .probe4         (cmd_flag     ),//1 
    .probe5         (scl_o        ),//1 
    .probe6         (dary_o       ),//1 
    .probe7         (ld_o         ),//1 
    .probe8         (trt_o        ),//1 
    .probe9         (trr_o        ),//1 
    .probe10        (prf_pin_in   ),//1 
    .probe11        (tr_o         ),//1 
    .probe12        (cnt_bit      )//32 
);


vio_sys u_vio_sys (
.clk          (sys_clk 	            ),//
.probe_in0    (prf_mode_in          ),//1 
.probe_in1    (ld_mode_in           ),//1 
.probe_in2    (send_flag_in         ),//1 
.probe_in3    (valid_in             ),//1 
.probe_in4    (beam_pos_num         ),//32
.probe_in5    (single_lane          ),//1
.probe_in6    (prf_start_in         ),//1
.probe_in7    (tr_mode              ),//1
.probe_in8    (polarization_mode    ),//1
.probe_in9    (temper_req           ),//1
.probe_in10   (bc_mode              ),//1
.probe_in11   (sel_param            ),//1
.probe_in12   (reset_sof            ) //1
);

`endif

    // assign BC_A_CLK    = scl_o;
    // assign BC_A_CS     = sel_o;
    // assign BC_A_LATCH  = ld_o;
    // // assign BC_A_RXD    = ld_o;
    // assign BC_A_RXEN   = cmd_flag;
    // assign BC_A_TXD    = sd_o;
    // assign BC_A_TXEN   = tr_o;

    // assign BC_B_CLK    = scl_o;
    // assign BC_B_CS     = sel_o;
    // assign BC_B_LATCH  = ld_o;
    // // assign BC_A_RXD    = ld_o;
    // assign BC_B_RXEN   = cmd_flag;
    // assign BC_B_TXD    = sd_o;
    // assign BC_B_TXEN   = tr_o;


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

    assign sel_o_h    = sel_o    ;
    assign scl_o_h    = scl_o    ;
    assign sd_o_h     = sd_o     ;
    assign dary_o_h   = dary_o   ;
    assign ld_o_h     = ld_o     ;
    assign trt_o_h    = trt_o    ;
    assign trr_o_h    = trr_o    ;
    assign rst_o_h    = rst_o    ;

    assign prf_in = prf_pin_in;

endmodule
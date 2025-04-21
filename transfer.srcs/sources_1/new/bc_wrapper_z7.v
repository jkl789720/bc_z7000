//功能：tr信号一分多，又或者说是tr模式控制
`timescale 1ns / 1ps
module bc_wrapper_z7#(
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
    input 					        sys_clk 	    ,
    input 					        sys_rst 	    ,
    input                           prf_pin_in      ,
    input                           prf_rf_in       ,
    input                           tr_en           ,


    input                	        rama_clk        ,
	input                           rama_en         ,
	input   [3 : 0]                 rama_we         ,
	input   [31 : 0]                rama_addr       ,
	input   [31 : 0]                rama_din        ,
	output  [31 : 0]                rama_dout       ,
	input                           rama_rst        ,

//tr_en_sel_ram
    input                           bram_tx_sel_clk ,
    input                           bram_tx_sel_en  ,
    input  [3:0]                    bram_tx_sel_we  ,
    input  [31:0]                   bram_tx_sel_addr,
    input  [31:0]                   bram_tx_sel_din ,
    output [31:0]                   bram_tx_sel_dout,
    output                          bram_tx_sel_rst ,


    input   [31:0] 			        app_param0	    ,
    input   [31:0] 			        app_param1	    ,
    input   [31:0] 			        app_param2	    ,
    input   [31:0] 			        app_param3	    ,
    output  [31:0] 			        app_status0	    ,
    output  [31:0] 			        app_status1	    ,  

//BC1_new
    output  [3:0]                   BC1_SEL      ,   
    output  [3:0]                   BC1_CLK      ,         
    output  [15:0]                  BC1_DATA     ,    
    output  [3:0]                   BC1_LD       ,  
    output  [3:0]                   BC1_TRT      ,  
    output  [3:0]                   BC1_TRR      ,    
 
//BC2_new
    output  [3:0]                   BC2_SEL      ,   
    output  [3:0]                   BC2_CLK      ,         
    output  [15:0]                  BC2_DATA     ,    
    output  [3:0]                   BC2_LD       ,  
    output  [3:0]                   BC2_TRT      ,
    output  [3:0]                   BC2_TRR      ,   

//BC_RST
    output                          BC_RST       

);
wire reset;
//-------------------wire declare----------------------//
//spi
wire [DATA_BIT-1:0]        data_in          ;
wire                       trig             ;
wire 					   mode			    ;

wire                       ld_mode          ;
wire 					   send_flag_in	    ;
wire 					   single_lane      ;
wire                       tr_mode          ;
wire                       polarization_mode;
wire                       temper_req       ;
wire                       temper_data_valid;

wire                       image_start      ;
wire                       sel_param        ;    
wire [3:0]                 bc_mode          ;
wire                       valid_in         ;

wire [31:0]                beam_pos_num     ;
wire [15:0]                receive_period   ;

wire                       temper_ready     ;
wire                       temper_en        ;

wire                       temper_read_done    ;

wire                       rst_soft            ;

wire [31:0]                cnt_bit;

//--cpu_o_ctrl&&mode
wire 					   prf_mode             ;
wire 					   prf_start_in         ;

wire 					   cpu_dat_sd_en        ;


wire                       spi_done             ;//一个组发送完，而不是整个波位发送完成，这是区分于温度命名的
wire                       ld_done              ;
wire                       now_beam_send_done   ;

wire rd_done = 0;

wire                       scl_o    	 ;
wire                       sel_o         ;
wire                       cmd_flag      ;
wire [GROUP_CHIP_NUM-1:0]  sd_o          ;
wire                       dary_o        ;
wire                       ld_o          ;
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

wire [7:0] trt_ps;
wire [7:0] trr_ps;

wire [7:0] trt;
wire [7:0] trr;

wire [23:0] beam_pos_cnt;


reg [31:0]  app_param0_r [1:0];
reg [31:0]  app_param1_r [1:0];
reg [31:0]  app_param2_r [1:0];


//地址分配
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

//寄存寄存器
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

//寄存器赋值
 assign prf_start_in        = app_param0_r[1][0];
 assign prf_mode            = app_param0_r[1][1];
 assign ld_mode             = app_param0_r[1][2];
 assign send_flag_in        = app_param0_r[1][3];//打拍
 assign single_lane         = app_param0_r[1][4];//打拍
 assign tr_mode             = app_param0_r[1][5];
 assign polarization_mode   = app_param0_r[1][6];


assign valid_in         = app_param1_r[1][0];//打拍
assign temper_req       = app_param1_r[1][1];//打拍
assign bc_mode          = app_param1_r[1][5:2];//打拍
assign sel_param        = app_param1_r[1][6];//打拍
assign rst_soft         = app_param1_r[1][7];
assign image_start      = app_param1_r[1][8];
assign receive_period      = app_param1_r[1][31:16];

assign beam_pos_num	    = app_param2_r[1]   ;

assign prf = prf_mode ? prf_pin_in : prf_rf_in;
assign reset = sys_rst || rst_soft;

		

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
.  sys_rst  	        (reset                  ) ,
.  prf      	        (prf                    ) ,

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
.  ld_mode  	        (ld_mode                ) ,

.  spi_done             (spi_done               ) ,

.  temper_read_done     (temper_read_done       ) ,
.  temper_en            (temper_en              ) ,

.  data_in  	        (data_in  	            ) ,
.  trig     	        (trig     	            ) ,
.  mode  		        (mode    	            ) ,


.  ld_o  	            (ld_o                   ) ,
.  dary_o  	            (dary_o                 ) ,

.  temper_req           (temper_req             ) ,
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
    .spi_done                ( spi_done            ),
    .temper_data0            ( temper_data0        ),
    .temper_data1            ( temper_data1        ),
    .temper_data2            ( temper_data2        ),
    .temper_data3            ( temper_data3        ),
    .temper_data_valid       ( temper_data_valid   ),
    .temper_read_done        ( temper_read_done    ),
    .ld_o                    ( ld_o                ),
    .dary_o                  ( dary_o              ),
    .cnt_bit                 ( cnt_bit             )
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
. prf    		        (prf    		    ),
. ld_o	                (ld_o	            ),
. send_flag_in			(send_flag_in	    ),
. single_lane			(single_lane		),
. tr_mode				(tr_mode			),
. tr_en				    (tr_en				),
. tr_en_o				(tr_en_o		    )
);

//从PS端扩充，边坡发射使能信号
tr_en_ps u_tr_en_ps(
. sys_clk            (sys_clk         ) ,
. sys_rst            (sys_rst         ) ,
. tr_en              (tr_en_o         ) ,
. prf                (prf             ) ,
. beam_pos_num       (beam_pos_num    ) ,
. receive_period       (receive_period    ) ,
. bram_tx_sel_clk    (bram_tx_sel_clk ) ,
. bram_tx_sel_en     (bram_tx_sel_en  ) ,
. bram_tx_sel_we     (bram_tx_sel_we  ) ,
. bram_tx_sel_addr   (bram_tx_sel_addr) ,
. bram_tx_sel_din    (bram_tx_sel_din ) ,
. bram_tx_sel_dout   (bram_tx_sel_dout) ,
. bram_tx_sel_rst    (bram_tx_sel_rst ) ,
. trt_ps             (trt_ps          ) , 
. trr_ps             (trr_ps          )  
    );

//根据bcmode扩充
bc_txen_expand u_bc_txen_expand(
.  sys_clk     (sys_clk     ),
.  sys_rst     (sys_rst     ),//不能被软件复位
.  prf_in      (prf         ),
.  tr_en       (tr_en_o     ),
.  bc_mode     (bc_mode     ),
.  sel_param   (sel_param   ),
.  image_start (image_start ),
.  receive_period (receive_period ),

.  trt          (trt        ),
.  trr          (trr        )
);

//-------------------------io_assign-----------------------------//
wire                            sel_o_a        ;
wire                            cmd_flag_a     ;
wire                            scl_o_a    	   ;
wire [GROUP_CHIP_NUM-1:0]       sd_o_a         ;
wire                            ld_o_a         ;
wire                            tr_o_a         ;
wire                            rst_o_a        ;
    
wire                            sel_o_b        ;
wire                            cmd_flag_b     ;
wire                            scl_o_b    	   ;
wire [GROUP_CHIP_NUM-1:0]       sd_o_b         ;
wire                            ld_o_b         ;
wire                            tr_o_b         ;
wire                            rst_o_b        ;

// wire                            sel_o_h        ;
// wire                            scl_o_h    	   ;
// wire [GROUP_CHIP_NUM-1:0]       sd_o_h         ;
// wire                            ld_o_h         ;
// wire                            dary_o_h       ;
// wire                            tr_en_o        ;//2025/04/11 15:38 跟上面的管脚冲突，亟需处理
// wire                            rst_o_h        ;




//------------mimo or junke--------------------//
assign BC1_SEL  = {4{sel_o}} ;
assign BC1_CLK  = {4{scl_o}} ;
assign BC1_DATA = sd_o[15:0] ;
assign BC1_LD   = {4{ld_o}}  ;
assign BC1_TRT  = trt[3:0]   ;//边坡为 trt_ps junke/ku polarization为 trt
assign BC1_TRR  = trr[3:0]   ;


assign BC2_SEL  = {4{sel_o}} ;
assign BC2_CLK  = {4{scl_o}} ;
assign BC2_DATA = sd_o[31:16];
assign BC2_LD   = {4{ld_o}}  ;
assign BC2_TRT  = trt[7:4]   ;//边坡为 trt_ps junke/ku polarization为 trt
assign BC2_TRR  = trr[7:4]   ;

assign BC_RST   = rst_o      ;

//--------------------207sar--------------------//
assign sel_o_a    = sel_o    ;
assign cmd_flag_a = cmd_flag ;
assign scl_o_a    = scl_o    ;
assign sd_o_a     = sd_o     ;
assign ld_o_a     = ld_o     ;
assign tr_o_a     = tr_en_o && (~polarization_mode)     ;
assign rst_o_a    = rst_o    ;

assign sel_o_b    = sel_o    ;
assign cmd_flag_b = cmd_flag ;
assign scl_o_b    = scl_o    ;
assign sd_o_b     = sd_o     ;
assign ld_o_b     = ld_o     ;
assign tr_o_b     = tr_en_o && polarization_mode     ;
assign rst_o_b    = rst_o    ;

//--------------------mini_sar--------------------//
assign sel_o_h    = sel_o    ;
assign scl_o_h    = scl_o    ;
assign sd_o_h     = sd_o     ;
assign dary_o_h   = dary_o   ;
assign ld_o_h     = ld_o     ;
assign rst_o_h    = rst_o    ;

// `ifdef DEBUG
    vio_new_reg u_vio_new_reg (
    .clk(sys_clk),              // input wire clk
    .probe_in0(bc_mode),  // input wire [3 : 0] probe_in0
    .probe_in1(sel_param),  // input wire [0 : 0] probe_in1
    .probe_in2(image_start)  // input wire [0 : 0] probe_in2
    );

    ila_trt u_ila_trt (
        .clk(sys_clk), // input wire clk


        .probe0     (BC1_TRT[0] ), // input wire [0:0]  probe0  
        .probe1     (BC1_TRR[0] ), // input wire [0:0]  probe1 
        .probe2     (BC1_TRT[1] ), // input wire [0:0]  probe2 
        .probe3     (BC1_TRR[1] ), // input wire [0:0]  probe3 
        .probe4     (BC1_TRT[2] ), // input wire [0:0]  probe4 
        .probe5     (BC1_TRR[2] ), // input wire [0:0]  probe5 
        .probe6     (BC1_TRT[3] ), // input wire [0:0]  probe6 
        .probe7     (BC1_TRR[3] ), // input wire [0:0]  probe7
        .probe8     (BC2_TRT[0] ), // input wire [0:0]  probe0  
        .probe9     (BC2_TRR[0] ), // input wire [0:0]  probe1 
        .probe10    (BC2_TRT[1] ), // input wire [0:0]  probe2 
        .probe11    (BC2_TRR[1] ), // input wire [0:0]  probe3 
        .probe12    (BC2_TRT[2] ), // input wire [0:0]  probe4 
        .probe13    (BC2_TRR[2] ), // input wire [0:0]  probe5 
        .probe14    (BC2_TRT[3] ), // input wire [0:0]  probe6 
        .probe15    (BC2_TRR[3] ), // input wire [0:0]  probe7
        .probe16    (prf), // input wire [0:0]  probe7
        .probe17    (tr_en_o), // input wire [0:0]  probe7
        .probe18    (bc_mode), // input wire [3:0]  probe7
        .probe19    (image_start), // input wire [0:0]  probe7
        .probe20    (sys_rst) // input wire [0:0]  probe7
    );
    wire [31:0] sd;
    assign sd = sd_o;
    ila_spi_bc_code u_ila_spi_bc_code (
        .clk	        (sys_clk	      ),// 
        .probe0	        (PLUART_txd	      ),//1  
        .probe1	        (PLUART_rxd	      ),//1 
        .probe2         (sd               ),//32
        .probe3         (sel_o            ),//1 
        .probe4         (cmd_flag         ),//1 
        .probe5         (scl_o            ),//1 
        .probe6         (dary_o           ),//1 
        .probe7         (ld_o             ),//1 
        .probe8         (prf              ),//1 
        .probe9         (tr_en_o          ),//1 
        .probe10        (cnt_bit          ),//32 
        .probe11        (beam_pos_cnt[7:0]) //8
    );
    
    
    
    
    vio_ctrl_reg u_vio_ctrl_reg (
    .clk          (sys_clk 	            ),//
    .probe_in0    (prf_mode             ),//1 
    .probe_in1    (ld_mode              ),//1 
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
    .probe_in12   (reset_sof            ), //1
    .probe_in13   (receive_period       ) //16
    );
    
// `endif
endmodule

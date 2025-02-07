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

//ram_port
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


//ram_read_port

wire                bram_tx_sel_en_read   ;   
wire [3 : 0]        bram_tx_sel_addr_read ;  
wire [15 : 0]       bram_tx_sel_dout_read ;  



wire                        sel_o_h     ;
wire                        scl_o_h     ;
wire [GROUP_CHIP_NUM-1:0]   sd_o_h      ;
wire                        ld_o_h      ;
wire                        dary_o_h    ;
wire                        trt_o_h     ;
wire                        trr_o_h     ;
wire                        rst_o_h     ;

reg [31:0]  app_param0_r [1:0];
reg [31:0]  app_param1_r [1:0];
reg [31:0]  app_param2_r [1:0];


wire prf_mode;
wire prf;
reg [1:0] prf_r;
wire prf_pos;
reg [7:0] cnt_prf;

wire valid;
reg [1:0] valid_r;
wire valid_pos;

wire [7:0] tx_sel;//选择对应bit作为发射通道，为1作为发射，发射使能来了就发射，否则作为接收
wire [7:0] trt;
wire [7:0] trr;

wire [23:0] beam_pos_cnt;

wire [31:0] beam_pos_num;

assign beam_pos_num = app_param2_r[1][31:0];

assign prf_mode = app_param0_r[1][1];
assign prf = prf_mode ? prf_pin_in : prf_rf_in;


assign tx_sel = bram_tx_sel_dout_read[7:0];

genvar kk;
generate
    for(kk = 0;kk < 8;kk = kk + 1)begin:blk0
        assign trt[kk] =  tx_sel[kk] ? trt_o_h : 0;
        assign trr[kk] =  tx_sel[kk] ? trr_o_h : 0;
    end
endgenerate

assign BC1_SEL  = {4{sel_o_h}} ;
assign BC1_CLK  = {4{scl_o_h}} ;
assign BC1_DATA = sd_o_h[15:0] ;
assign BC1_LD   = {4{ld_o_h}}  ;
assign BC1_TRT  = trt[3:0]     ;
assign BC1_TRR  = trr[3:0]     ;


assign BC2_SEL  = {4{sel_o_h}} ;
assign BC2_CLK  = {4{scl_o_h}} ;
assign BC2_DATA = sd_o_h[31:16];
assign BC2_LD   = {4{ld_o_h}}  ;
assign BC2_TRT  = trt[7:4]     ;
assign BC2_TRR  = trr[7:4]     ;

assign BC_RST   = rst_o_h      ;


//生成一份打拍的代码
always @(posedge  sys_clk) begin
    if(sys_rst)begin
        app_param0_r[0] <= 0;
        app_param0_r[1] <= 0;
    end
    else begin
        app_param0_r[0] <= app_param0;
        app_param0_r[1] <= app_param0_r[0];
    end
end

//生成一份打拍的代码
always @(posedge  sys_clk) begin
    if(sys_rst)begin
        app_param1_r[0] <= 0;
        app_param1_r[1] <= 0;
    end
    else begin
        app_param1_r[0] <= app_param1;
        app_param1_r[1] <= app_param1_r[0];
    end
end

//生成一份打拍的代码
always @(posedge  sys_clk) begin
    if(sys_rst)begin
        app_param2_r[0] <= 0;
        app_param2_r[1] <= 0;
    end
    else begin
        app_param2_r[0] <= app_param2;
        app_param2_r[1] <= app_param2_r[0];
    end
end

assign valid = app_param1_r[1][0];

always @(posedge sys_clk) begin
    if(sys_rst)begin
        valid_r <= 0;
    end
    else begin
        valid_r <= {valid_r[0],valid};
    end
end

assign valid_pos = ~valid_r[1] && valid_r[0];

//prf信号打拍
always @(posedge sys_clk) begin
    if(sys_rst)begin
        prf_r <= 0;
    end
    else begin
        prf_r <= {prf_r[0],prf};
    end
end

assign prf_pos = ~prf_r[1] && prf_r[0];

always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_prf <= 0;
    else if(valid_pos)
        cnt_prf <= 0;
    else if(prf_pos)begin
        if(cnt_prf == beam_pos_num)
            cnt_prf <= 1;
        else
            cnt_prf <= cnt_prf + 1;
    end
        
end



assign bram_tx_sel_en_read = 1;
assign bram_tx_sel_addr_read = beam_pos_num == 1 ? 0 : cnt_prf -1;


    
bc_wrapper#(
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
u_bc_wrapper(
  	.    sys_clk 	    ( sys_clk 	    )       ,
  	.    sys_rst 	    ( sys_rst 	    )       ,
	.    prf            ( prf           )       ,
    .    tr_en          ( tr_en         )       ,

    .    sel_o_a        ( sel_o_a       )       ,
    .    cmd_flag_a     ( cmd_flag_a    )       ,
    .    scl_o_a        ( scl_o_a       )	    ,
    .    sd_o_a         ( sd_o_a        )       ,
    .    ld_o_a         ( ld_o_a        )       ,
    .    tr_o_a         ( tr_o_a        )       ,
    .    rst_o_a        ( rst_o_a       )       ,

    .    sel_o_b        ( sel_o_b       )       ,
    .    cmd_flag_b     ( cmd_flag_b    )       ,
    .    scl_o_b        ( scl_o_b       )	    ,
    .    sd_o_b         ( sd_o_b        )       ,
    .    ld_o_b         ( ld_o_b        )       ,
    .    tr_o_b         ( tr_o_b        )       ,
    .    rst_o_b        ( rst_o_b       )       ,

    .    sel_o_h        ( sel_o_h       )       ,
    .    scl_o_h        ( scl_o_h       )	    ,
    .    sd_o_h         ( sd_o_h        )       ,
    .    ld_o_h         ( ld_o_h        )       ,
    .    dary_o_h       ( dary_o_h      )       ,
    .    trt_o_h        ( trt_o_h       )       ,
    .    trr_o_h        ( trr_o_h       )       ,
    .    rst_o_h        ( rst_o_h       )       ,
    .    beam_pos_cnt   ( beam_pos_cnt  )       ,

	.    rama_clk       ( rama_clk      )       ,
	.    rama_en        ( rama_en       )       ,
	.    rama_we        ( rama_we       )       ,
	.    rama_addr      ( rama_addr     )       ,
	.    rama_din       ( rama_din      )       ,
	.    rama_dout      ( rama_dout     )       ,
	.    rama_rst       ( rama_rst      )       ,

    .    app_param0	    ( app_param0	)       ,
    .    app_param1	    ( app_param1	)       ,
    .    app_param2	    ( app_param2	)       ,
    .    app_status0    ( app_status0   )	    ,
    .    app_status1    ( app_status1   )	 

); 



bram_tx_sel u_bram_tx_sel (
  .clka (bram_tx_sel_clk        ),      // input wire clka
  .ena  (bram_tx_sel_en         ),      // input wire ena
  .wea  (bram_tx_sel_we[0]      ),      // input wire [0 : 0] wea
  .addra(bram_tx_sel_addr >> 2  ),      // input wire [2 : 0] addra
  .dina (bram_tx_sel_din        ),      // input wire [31 : 0] dina
  .douta(bram_tx_sel_dout       ),      // output wire [31 : 0] douta
  .clkb (sys_clk                ),      // input wire clkb
  .enb  (bram_tx_sel_en_read    ),      // input wire enb
  .web  (0                      ),      // input wire [0 : 0] web
  .addrb(bram_tx_sel_addr_read  ),      // input wire [3 : 0] addrb
  .dinb (0                      ),      // input wire [15 : 0] dinb
  .doutb(bram_tx_sel_dout_read  )       // output wire [15 : 0] doutb
);


ila_tx_en u_ila_tx_en (
	.clk                     (sys_clk   ), // input wire clk


	.probe0                  (tx_sel               ), //8
	.probe1                  (trt                  ), //8
	.probe2                  (trr                  ), //8
	.probe3                  (bram_tx_sel_addr_read), //4
	.probe4                  (trt_o_h              ), //1
	.probe5                  (trr_o_h              ),  //1
	.probe6                  (bram_tx_sel_clk      ),  //1
	.probe7                  (bram_tx_sel_en       ),  //1
	.probe8                  (bram_tx_sel_we       ),  //4
	.probe9                  (bram_tx_sel_addr     ),  //32
	.probe10                 (bram_tx_sel_din      ),  //32
	.probe11                 (bram_tx_sel_dout     )   //32
);

wire ld_mode;
wire tr_mode;

assign  ld_mode = app_param0_r[1][2];
assign  tr_mode = app_param0_r[1][5];

vio_bc_mode u_vio_bc_mode (
  .clk(sys_clk),              // input wire clk
  .probe_in0(prf_mode),  // input wire [0 : 0] probe_in0
  .probe_in1(ld_mode),  // input wire [0 : 0] probe_in1
  .probe_in2(tr_mode)  // input wire [0 : 0] probe_in2
);

endmodule

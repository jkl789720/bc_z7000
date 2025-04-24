`include "configure.vh"
`timescale 1ns / 1ps
module tb_wrapper_new#(
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
    parameter CMD_BIT          = 10                              ,
    parameter BEAM_NUM         = 1024
)
();

localparam LANE_NUM = 64*2;
localparam BEAM_POS_NUM =  4;
localparam WRITE_TIMES = 3;
localparam TOTAL_LANE_NUM = LANE_NUM * BEAM_POS_NUM;




// test Inputs
reg   sys_clk;
reg   prf_pin_in;

reg                       sys_rst     ;//

reg SYSCLK;
wire LED;




reg                       valid_in    ;//--

//BC1_new
wire  [3:0]                   BC1_SEL      ;   
wire  [3:0]                   BC1_CLK      ;         
wire  [15:0]                  BC1_DATA     ;    
wire  [3:0]                   BC1_LD       ;  
wire  [3:0]                   BC1_TRT      ;  
wire  [3:0]                   BC1_TRR      ;    
wire  [3:0]                   BC2_SEL      ;   
wire  [3:0]                   BC2_CLK      ;         
wire  [15:0]                  BC2_DATA     ;    
wire  [3:0]                   BC2_LD       ;  
wire  [3:0]                   BC2_TRT      ;
wire  [3:0]                   BC2_TRR      ;   
wire                          BC_RST       ;


//tx_sel_en

reg  [3:0]      bram_tx_sel_we  ;
reg  [31:0]     bram_tx_sel_addr;
wire [31:0]     bram_tx_sel_din ;
wire [31:0]     bram_tx_sel_dout;
wire            bram_tx_sel_rst ;



always @(posedge sys_clk) begin
    if(sys_rst)
        bram_tx_sel_we <= 4'hf;
    else if(bram_tx_sel_addr == 4 * (BEAM_POS_NUM/2) - 4)
        bram_tx_sel_we <= 0;
end

always @(posedge sys_clk) begin
    if(sys_rst)
        bram_tx_sel_addr <= 0;
    else if(bram_tx_sel_we == 4'hf)begin
        if(bram_tx_sel_addr == 4 * (BEAM_POS_NUM/2) - 4)
            bram_tx_sel_addr <= 0;
        else
            bram_tx_sel_addr <= bram_tx_sel_addr + 4;
    end
end

assign bram_tx_sel_din = {8'd0,8'b1111_0000,8'd0,8'b0000_1111};





reg  [31 : 0]               wr_cnt_lane , wr_cnt_beam           ;//通道计数，波位计数
wire                        add_wr_cnt_lane , end_wr_cnt_lane   ;
wire                        add_wr_cnt_beam , end_wr_cnt_beam   ;

wire                        w2r                                 ;
wire [31:0]                 cnt_lane_total                      ;

wire [31:0]               beam_pos_num ;

//rama
reg                       rama_clk         ;
wire                      rama_en         ;
reg    [3 : 0]            rama_we         ;
wire   [31 : 0]           rama_addr       ;
reg   [31 : 0]            rama_din        ;
wire   [31 : 0]           rama_dout       ;
wire                      rama_rst        ; 

wire [31:0] 			  app_param0      ;
wire [31:0] 			  app_param1      ;
wire [31:0] 			  app_param2      ;



assign  rama_rst  = 0         ;
assign  rama_en   = 1         ;
assign  rama_addr = cnt_lane_total * 4;//总的当前写入通道数

reg soft_rst;

assign app_param2 = BEAM_POS_NUM;
assign app_param1 = {16'd65535,8'b0,soft_rst,1'b1,4'd2,1'b0,valid_in};
assign app_param0 = {16'd0,9'b0,7'b0001111};//外部产生prf、动态配置、发送、内部产生tr






initial begin
    sys_clk = 0;
    SYSCLK  = 0;
    sys_rst = 1;
    rama_clk   = 0;
    #1000
    sys_rst = 0;
end

always #10 sys_clk = ~sys_clk;
always #20 SYSCLK =  ~SYSCLK;

always #10 rama_clk  = ~rama_clk ;

localparam IDLE   = 4'd0;
localparam WRITE  = 4'd1;
localparam VALID  = 4'd2;
localparam DELAY  = 4'd3;
localparam IS_CONTITUE  = 4'd4;
localparam STOP  = 4'd5;

reg [3:0] c_state,n_state;
//----------------状态机中需要用到的变量------------------//
reg [31:0] cnt_delay;
reg [3:0] wr_times;

assign add_wr_cnt_lane = rama_we;
assign end_wr_cnt_lane = add_wr_cnt_lane && wr_cnt_lane == LANE_NUM - 1 && rama_we;
assign add_wr_cnt_beam = end_wr_cnt_lane;
assign end_wr_cnt_beam = add_wr_cnt_beam && wr_cnt_beam == BEAM_POS_NUM - 1;


//------------状态转换条件---------------//

assign cnt_lane_total = wr_cnt_beam * LANE_NUM + wr_cnt_lane;

assign w2r = (cnt_lane_total == TOTAL_LANE_NUM - 1);
reg [31:0] cnt_valid;
always@(posedge rama_clk )begin
    if(sys_rst)
        c_state <= IDLE;
    else
        c_state <= n_state;
end
always@(*)begin
    if(sys_rst)
        n_state = IDLE;
    else 
        case (c_state)
            IDLE: begin
                n_state = WRITE;
            end
            WRITE :begin
                if(w2r)
                    n_state = VALID;
                else
                    n_state = c_state;
            end
            VALID :begin
                if(cnt_valid == 100 - 1)
                    n_state = DELAY;
                else
                    n_state = VALID;
            end 
            DELAY:begin
                if(cnt_delay == 20000 - 1)
                    n_state = IS_CONTITUE;
                else
                    n_state = DELAY;
            end
            IS_CONTITUE :begin
                if(wr_times == WRITE_TIMES-1)
                    n_state = STOP;
                else
                    n_state = IDLE;
            end
            STOP: begin
                n_state = STOP;
            end
            default: n_state = IDLE;
        endcase
end
always@(posedge rama_clk )begin
    if(sys_rst)begin
        rama_we   <= 0;
        valid_in <= 0;
        cnt_valid <= 0;
        wr_cnt_lane <= 0;
        wr_cnt_beam <= 0;
        rama_din    <= 0;
        cnt_delay <= 0;
        wr_times <= 0;
    end
    else
        case (c_state)
            IDLE: begin
                rama_we   <= 0;
                valid_in <= 0;
                cnt_valid <= 0;
                wr_cnt_lane <= 0;
                wr_cnt_beam <= 0;
                rama_din    <= 0;
                cnt_delay <= 0;
            end
            WRITE :begin
                if(w2r)
                    rama_we   <= 0;
                else
                    rama_we   <= 4'hf;
                if(add_wr_cnt_lane)begin
                    if(end_wr_cnt_lane)
                        wr_cnt_lane <= 0;
                    else
                        wr_cnt_lane <= wr_cnt_lane + 1; 
                end

                if(add_wr_cnt_beam)begin
                    if(end_wr_cnt_beam)
                        wr_cnt_beam <= 0;
                    else
                        wr_cnt_beam <= wr_cnt_beam + 1;
                end
            end
            VALID : begin
                rama_we <= 0;
                valid_in <= cnt_valid > 40;//40-100
                soft_rst <= cnt_valid < 20;//0-20
                cnt_valid <= cnt_valid + 1;
            end
            DELAY:begin
                valid_in <= 0;
                cnt_delay <= cnt_delay + 1;
            end
            IS_CONTITUE :begin
                if(wr_times == WRITE_TIMES - 1)
                    wr_times <= WRITE_TIMES - 1;
                else
                    wr_times <= wr_times + 1;
            end
            STOP: begin
                cnt_delay <= 0;
            end
        endcase

end

always @(*) begin
    if(sys_rst)
        rama_din <= 0;
    if(c_state == WRITE)begin
        if(wr_cnt_lane >=  (4 * wr_cnt_beam) && wr_cnt_lane < 4 * (wr_cnt_beam + 1))
            rama_din <= 0;
        else
            rama_din <= 32'h5555_5555;
    end
end

//-------------------生成prf信号----------------------//
localparam PRF_FREQ_HZ = 11200;
localparam CNT_NUM = 11200;
reg [$clog2(CNT_NUM)-1:0] cnt;
always@(posedge sys_clk)begin
	if(sys_rst)	
		cnt <= 0;
	else if(1)begin
		if(cnt == CNT_NUM - 1)
			cnt <= 0;
		else 
			cnt <= cnt + 1;
	end
end

always@(posedge sys_clk)begin
	if(sys_rst)	
		prf_pin_in <= 0;
	else if(1)begin
		if(cnt == 0)
			prf_pin_in <= 1;
		else if(cnt == CNT_NUM/10-1)
			prf_pin_in <=0;
	end
end







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
    . sys_clk 	        (sys_clk 	        )       ,
    . sys_rst 	        (sys_rst 	        )       ,
    . prf_pin_in        (prf_pin_in         )       ,
    . tr_en             (tr_en              )       ,
    . rama_clk          (rama_clk           )       ,
	. rama_en           (rama_en            )       ,
	. rama_we           (rama_we            )       ,
	. rama_addr         (rama_addr          )       ,
	. rama_din          (rama_din           )       ,
	. rama_dout         (rama_dout          )       ,
	. rama_rst          (rama_rst           )       ,

    . bram_tx_sel_clk   (sys_clk            )  ,
    . bram_tx_sel_en    (1                  )  ,
    . bram_tx_sel_we    (bram_tx_sel_we     )  ,
    . bram_tx_sel_addr  (bram_tx_sel_addr   )  ,
    . bram_tx_sel_din   (bram_tx_sel_din    )  ,
    . bram_tx_sel_dout  (bram_tx_sel_dout   )  ,
    . bram_tx_sel_rst   (bram_tx_sel_rst    )  ,
    
    . app_param0        (app_param0         )  	    ,
    . app_param1        (app_param1         )  	    ,
    . app_param2        (app_param2         )  	    ,
    . app_status0       (app_status0        )	    ,
    . app_status1       (app_status1        )	    ,
    . BC1_SEL           (BC1_SEL            )       ,
    . BC1_CLK           (BC1_CLK            )       ,
    . BC1_DATA          (BC1_DATA           )       ,
    . BC1_LD            (BC1_LD             )       ,
    . BC1_TRR           (BC1_TRR            )       ,
    . BC1_TRT           (BC1_TRT            )       ,
    . BC2_SEL           (BC2_SEL            )       ,
    . BC2_CLK           (BC2_CLK            )       ,
    . BC2_DATA          (BC2_DATA           )       ,
    . BC2_LD            (BC2_LD             )       ,
    . BC2_TRT           (BC2_TRT            )       ,
    . BC2_TRR           (BC2_TRR            )       ,
    . BC_RST            (BC_RST             )       
);
//-------------------------校验----------------------//
//---------------------娉㈡帶鐮佹楠?------------------------//
wire             clka_check ;
wire             ena_check  ;
wire [3:0]       wea_check  ;
wire [31:0]      addra_check;
wire [31:0]      dina_check ;
wire [31:0]      douta_check;

wire [31:0]      spi_clk;
wire [31:0]      spi_cs_n;
wire [31:0]      spi_mosi;

assign beam_pos_num = BEAM_POS_NUM;
assign spi_clk = signal_expansion(BC2_CLK,BC1_CLK);
assign spi_cs_n = signal_expansion(BC2_SEL,BC1_SEL);
assign spi_mosi = {BC2_DATA,BC1_DATA};
check_wrapper #(
    .CHANNEL_NUM  (32 ),
    .BIT_NUM      (106)
)
 u_check_wrapper (
    .clk                     ( sys_clk            ),
    .rst_n                   ( ~(sys_rst | soft_rst)           ),
    .spi_clk                 ( spi_clk            ),
    .spi_cs_n                ( spi_cs_n           ),
    .spi_mosi                ( spi_mosi           ),
    .beam_pos_num            ( beam_pos_num       ),
    .clka                    ( clka_check         ),
    .ena                     ( ena_check          ),
    .wea                     ( wea_check[0]       ),
    .addra                   ( addra_check[31:2]  ),
    .dina                    ( dina_check         ),
    .douta                   ( douta_check        )
);

ila_check_back_ram_r u_u_ila_check_back_ram_r (
	.clk(clka_check), // input wire clk


	.probe0(ena_check), // input wire [0:0]  probe0  
	.probe1(wea_check), // input wire [0:0]  probe1 
	.probe2(addra_check), // input wire [3:0]  probe2 
	.probe3(dina_check), // input wire [31:0]  probe3 
	.probe4(douta_check) // input wire [31:0]  probe4 
);





function [31:0] signal_expansion;
    input [3:0] sig1;//绗竴涓疄鍙?
    input [3:0] sig0;//绗簩涓疄鍙?
    begin
        signal_expansion = {
                        {4{sig1[3]}},{4{sig1[2]}},{4{sig1[1]}},{4{sig1[0]}},
                        {4{sig0[3]}},{4{sig0[2]}},{4{sig0[1]}},{4{sig0[0]}}
        };
    end
endfunction

BC_TRANS u_BC_TRANS(
    .   SYSCLK   (SYSCLK  ) ,	// 25MHz
    .   LED      (LED     ) ,
    .	BC_CLK   (scl_o_a  ) ,
    .	BC_TXD   (sd_o_a  ) ,
    .	BC_CS    (sel_o_a   ) ,//mode
    .	BC_RXEN  (cmd_flag_a ) ,//mode
    .	BC_TXEN  (tr_o_a ) ,//tr
    .	BC_LATCH (ld_o_a) ,//ld
    .	BC_RXD   (BC_RXD  )
);

endmodule

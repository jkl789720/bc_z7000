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
localparam TOTAL_LANE_NUM = LANE_NUM * BEAM_POS_NUM;




// test Inputs
reg   sys_clk;
reg   prf_pin_in;
reg   prf_rf_in;

// assign prf_rf_in = prf_pin_in;

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

wire [15:0] data_low,data_high;
assign data_low  = bram_tx_sel_addr >> 1;
assign data_high  = 1'b1+(bram_tx_sel_addr >> 1);
assign bram_tx_sel_din = {data_high,data_low};





reg  [31 : 0]               wr_cnt_lane , wr_cnt_beam           ;//通道计数，波位计数
wire                        add_wr_cnt_lane , end_wr_cnt_lane   ;
wire                        add_wr_cnt_beam , end_wr_cnt_beam   ;

wire                        w2r                                 ;
wire [31:0]                 cnt_lane_total                      ;

wire [31:0]               beam_pos_num = BEAM_POS_NUM;

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




assign app_param2 = beam_pos_num;
assign app_param1 = {31'b0,valid_in};
assign app_param0 = {25'b0,7'b0001100};//外部产生prf、动态配置、发送、内部产生tr






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

reg [3:0] c_state,n_state;
//----------------状态机中需要用到的变量------------------//



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
                n_state = c_state;
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
                if(cnt_valid == 50000)
                    cnt_valid <= 50000;
                else 
                    cnt_valid <= cnt_valid + 1;
                
                valid_in <= cnt_valid == 1;
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
localparam PRF_FREQ_HZ = 1000;
localparam CNT_NUM = 1000;
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


always@(posedge sys_clk)begin
	if(sys_rst)	
		prf_rf_in <= 0;
	else if(1)begin
		if(cnt == 100)
            prf_rf_in <= 1;
		else if(cnt == CNT_NUM/10-1)
			prf_rf_in <=0;
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
    . prf_rf_in         (prf_rf_in           )       ,
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

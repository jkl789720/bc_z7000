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
    parameter SCLHZ            = 1_000_000                      ,



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
localparam BEAM_POS_NUM =  32;
localparam WRITE_TIMES = 1;
localparam TOTAL_LANE_NUM = LANE_NUM * BEAM_POS_NUM;
localparam INIT_REG_NUM = 128;//多写一个方便回读




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

wire            ram_bc_init_clk    ;
wire            ram_bc_init_en     ;
wire  [3:0]     ram_bc_init_we     ;
wire  [31:0]    ram_bc_init_addr   ;
wire  [31:0]    ram_bc_init_din    ;
wire [31:0]     ram_bc_init_dout   ;
wire            ram_bc_init_rst    ;

wire            ram_bc_init_clk_back    ;
wire            ram_bc_init_en_back     ;
wire  [3:0]     ram_bc_init_we_back     ;
wire  [31:0]    ram_bc_init_addr_back   ;
wire  [31:0]    ram_bc_init_din_back    ;
wire [31:0]     ram_bc_init_dout_back   ;
wire            ram_bc_init_rst_back    ;
reg [7:0]       cnt_init;
reg [31:0]      mem_value [INIT_REG_NUM-1:0];
wire            init_start;
wire            init_done;
assign ram_bc_init_clk = sys_clk;
assign ram_bc_init_en  = 1'b1;

wire          clka_check    ;
wire          ena_check     ;
wire [3:0]    wea_check     ;
wire [31:0]   addra_check   ;
wire [31:0]   dina_check    ;
wire [31:0]   douta_check   ;
wire          rama_rst_check;


//----------------初始化ram生成------------------//

initial begin
        $readmemh("D:/code/verilog/data/mem_value.txt", mem_value);  // 从 hex 文件加载数据
end

always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_init <= 0;
    else if(cnt_init == INIT_REG_NUM)
        cnt_init <= INIT_REG_NUM;
    else
        cnt_init <= cnt_init + 1;
end

assign ram_bc_init_we = cnt_init <= INIT_REG_NUM - 1 ? 4'hf : 0;
assign ram_bc_init_addr = cnt_init << 2;
assign ram_bc_init_din = mem_value[cnt_init];

assign init_start = cnt_init == INIT_REG_NUM;

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

assign bram_tx_sel_din = 32'h00003cc3;




wire [7:0] sd_back;
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

wire [15:0] wave_switch_interval;
wire [3:0] bc_mode;
wire [1:0] send_permission;
wire [1:0] receive_permission;
wire [15:0] receive_peropd;
reg soft_rst;
wire init_read_req;


assign sd_back = {BC2_DATA[12],BC2_DATA[8],BC2_DATA[4],BC2_DATA[0],BC1_DATA[12],BC1_DATA[8],BC1_DATA[4],BC1_DATA[0]};

assign  rama_rst  = 0         ;
assign  rama_en   = 1         ;
assign  rama_addr = cnt_lane_total * 4;//总的当前写入通道数



assign bc_mode = 0;
assign send_permission = 2'b11;
assign receive_permission = 2'b11;
assign wave_switch_interval = 4;
assign receive_peropd = 5000;
assign init_read_req = 1;

assign app_param2 = BEAM_POS_NUM;
assign app_param1 = {receive_peropd,1'b0,init_read_req,init_start,receive_permission,send_permission,1'b0,soft_rst,1'b1,bc_mode,1'b0,valid_in};
assign app_param0 = {wave_switch_interval,9'b0,7'b0001111};//外部产生prf、动态配置、发送、内部产生tr






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
                if(init_done)
                    n_state = WRITE;
                else
                    n_state = c_state;
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
localparam PRF_FREQ_HZ = 110200;
localparam CNT_NUM = 110200;
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
    . sys_clk 	        (sys_clk 	        )       ,
    . sys_rst 	        (sys_rst 	        )       ,
    . prf_pin_in        (prf_pin_in         )       ,
    . tr_en             (tr_en              )       ,
    . sd_back           (sd_back            )       ,
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

    . ram_bc_init_clk   (ram_bc_init_clk    )       ,
    . ram_bc_init_en    (ram_bc_init_en     )       ,
    . ram_bc_init_we    (ram_bc_init_we     )       ,
    . ram_bc_init_addr  (ram_bc_init_addr   )       ,
    . ram_bc_init_din   (ram_bc_init_din    )       ,
    . ram_bc_init_dout  (ram_bc_init_dout   )       ,
    . ram_bc_init_rst   (ram_bc_init_rst    )       ,

    . ram_bc_init_clk_back   (ram_bc_init_clk_back )       ,
    . ram_bc_init_en_back    (ram_bc_init_en_back  )       ,
    . ram_bc_init_we_back    (ram_bc_init_we_back  )       ,
    . ram_bc_init_addr_back  (ram_bc_init_addr_back)       ,
    . ram_bc_init_din_back   (ram_bc_init_din_back )       ,
    . ram_bc_init_dout_back  (ram_bc_init_dout_back)       ,
    . ram_bc_init_rst_back   (ram_bc_init_rst_back )       ,

    . clka_check                (clka_check         )       ,
    . ena_check                 (ena_check          )       ,
    . wea_check                 (wea_check          )       ,
    . addra_check               (addra_check        )       ,
    . dina_check                (dina_check         )       ,
    . douta_check               (douta_check        )       ,
    . rama_rst_check            (rama_rst_check     )       ,
    
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
    . BC_RST            (BC_RST             )       , 
    . init_done         (init_done          )        
);



endmodule

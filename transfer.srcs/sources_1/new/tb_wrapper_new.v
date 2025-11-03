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


localparam BC_CODE_BASE        = 0;//波控码：256k
localparam INIT_CODE_BASE      = 32'h20000;//初始化值：8k
localparam BC_CODE_BACK_BASE   = 32'h22000;//波控码回读：8k  64通道最多32个波位  128通道最多16个波位
localparam INIT_CODE_BACK_BASE = 32'h24000;//初始化值回读：8k
localparam ADDR_TOP            = 32'h28000;

// test Inputs
reg   sys_clk;
reg   prf_pin_in;

reg                       sys_rst     ;//

reg SYSCLK;
wire LED;

wire tr_force_rx;


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



wire            ram_bc_init_clk    ;
wire            ram_bc_init_en     ;
wire  [3:0]     ram_bc_init_we     ;
wire  [31:0]    ram_bc_init_addr   ;
wire  [31:0]    ram_bc_init_din    ;
wire [31:0]     ram_bc_init_dout   ;
wire            ram_bc_init_rst    ;

reg [7:0]       cnt_init;
reg [31:0]      mem_value [INIT_REG_NUM-1:0];
reg            init_start;
wire            init_done;
assign ram_bc_init_clk = sys_clk;
assign ram_bc_init_en  = 1'b1;

//----------------初始化ram生成------------------//

initial begin
        $readmemh("D:/code/verilog/data/mem_value.txt", mem_value);  // 从 hex 文件加载数据
end

wire [7:0] sd_back;
wire [31:0]               beam_pos_num ;

//rama
reg                       rama_clk         ;
wire                      rama_en        = 1 ;
reg    [3 : 0]            rama_we         ;
reg   [31 : 0]           rama_addr       ;
reg   [31 : 0]            rama_din        ;
wire   [31 : 0]           rama_dout       ;
wire                      rama_rst        ; 

wire [31:0] 			  app_param0      ;
wire [31:0] 			  app_param1      ;
wire [31:0] 			  app_param2      ;
wire [31:0] 			  app_param3      ;

wire [15:0] wave_switch_interval;
wire [3:0] bc_mode;
wire [1:0] send_permission;
wire [1:0] receive_permission;
wire [15:0] receive_peropd;
wire init_read_req;



assign sd_back = {BC2_DATA[12],BC2_DATA[8],BC2_DATA[4],BC2_DATA[0],BC1_DATA[12],BC1_DATA[8],BC1_DATA[4],BC1_DATA[0]};




assign bc_mode = 0;
assign send_permission = 2'b11;
assign receive_permission = 2'b11;
assign wave_switch_interval = 4;
assign receive_peropd = 5000;
assign init_read_req = 1;

assign app_param3 = 32'hFFFF_FFFF;
assign app_param2 = BEAM_POS_NUM;
assign app_param1 = {receive_peropd,1'b0,init_read_req,init_start,receive_permission,send_permission,1'b0,1'b0,1'b1,bc_mode,1'b0,valid_in};
assign app_param0 = {wave_switch_interval,9'b0,7'b0001111};//外部产生prf、动态配置、发送、内部产生tr


task automatic register_write(
    input [31:0] reg_addr,
    input [31:0] reg_data
);
begin
    rama_we   = 4'hf;
    rama_addr = reg_addr;
    rama_din = reg_data;
    @(posedge rama_clk);
end
endtask


task automatic init_write;
integer i;
begin
    for(i=0;i<INIT_REG_NUM;i=i+1) begin
        register_write(INIT_CODE_BASE + (i<<2),mem_value[i]);
    end
end
endtask

task automatic bc_code_write;
integer i;
integer bc_pos_cnt_stim,lane_cnt_stim;
begin
    for(i=0;i<TOTAL_LANE_NUM;i=i+1) begin
        bc_pos_cnt_stim = i / LANE_NUM;
        lane_cnt_stim   = i % LANE_NUM;
        if(lane_cnt_stim >= bc_pos_cnt_stim*4 + 0 && lane_cnt_stim <= bc_pos_cnt_stim*4 + 3)
            register_write(BC_CODE_BASE + (i<<2),0);
        else
            register_write(BC_CODE_BASE + (i<<2),32'haaaa_aaaa);
    end
end
endtask

initial begin
    sys_clk = 0;
    SYSCLK  = 0;
    sys_rst = 1;
    rama_clk   = 0;
    init_start = 0;
    valid_in = 0;
    rama_we = 0;
    #1000
    sys_rst = 0;
    //初始化指令
    @(posedge rama_clk);
    init_write();
    rama_we = 0;
    #20
    init_start = 1;
    #20
    init_start = 0;

    wait(init_done);
    @(posedge rama_clk);
    bc_code_write();
    rama_we = 0;
    #20
    valid_in = 1;
    #20
    valid_in = 0;

end

always #10 sys_clk = ~sys_clk;
always #20 SYSCLK =  ~SYSCLK;

always #10 rama_clk  = ~rama_clk ;


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


assign tr_force_rx = (cnt > 900 + 1000 && cnt <= 900 + 2000);




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
    . tr_force_rx       (tr_force_rx        )       ,
    . sd_back           (sd_back            )       ,

    . rama_clk          (rama_clk           )       ,
	. rama_en           (rama_en            )       ,
	. rama_we           (rama_we            )       ,
	. rama_addr         (rama_addr          )       ,
	. rama_din          (rama_din           )       ,
	. rama_dout         (rama_dout          )       ,
	. rama_rst          (rama_rst           )       ,



    
    . app_param0        (app_param0         )  	    ,
    . app_param1        (app_param1         )  	    ,
    . app_param2        (app_param2         )  	    ,
    . app_param3        (app_param3         )  	    ,
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

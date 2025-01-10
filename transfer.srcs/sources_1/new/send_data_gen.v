//-------------------注解----------------------//
//cmd_value需要加延迟值
////rd_cnt >> 2才是组id
//数据发送完成应该是载入完成才对 即group_data_send_done需要更改
//周期数337232 1112.865us
`include "configure.vh"
`timescale 1ns / 1ps
module send_data_gen#(
    parameter LANE_BIT         = 20                              ,
    parameter FRAME_DATA_BIT   = 80                              ,
    parameter GROUP_CHIP_NUM   = 4                               ,
    parameter GROUP_NUM        = 16                              ,
    parameter DATA_BIT         = FRAME_DATA_BIT * GROUP_CHIP_NUM ,
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 1_875_000                       ,
    parameter READ_PORT_BYTES  = 16                              ,                
    parameter WRITE_PORT_BYTES = 4                               ,                
    parameter BEAM_BYTES       = GROUP_CHIP_NUM * GROUP_NUM * 16 ,
    parameter CMD_BIT          = 10                              ,
    parameter BEAM_NUM         = 1024
)
(
input                       sys_clk                     ,
input                       sys_rst                     ,
//---------------wr_data_in----------------//

input                       bc_ram_clk                  ,
input                       bc_ram_en                   ,
input   [3:0]               bc_ram_we                   ,
input   [31:0]              bc_ram_addr                 ,
input   [31:0]              bc_ram_din                  ,
output  [31:0]              bc_ram_dout                 ,
input                       bc_ram_rst                  ,

input                       delay_ram_clk               ,
input                       delay_ram_en                ,
input  [3:0]                delay_ram_we                ,
input  [31:0]               delay_ram_addr              ,
input  [31:0]               delay_ram_din               ,
output [31:0]               delay_ram_dout              ,
input                       delay_ram_rst               ,

//控制信号
input                       valid_in                    ,
input   [31:0]              beam_pos_num                ,
input                       prf_in                      ,

//数据信号
output reg [DATA_BIT-1:0]   data_in                     ,
output reg                  trig                        ,
output reg                  mode                        ,
input                       bc_group_send_done          ,
output reg                  now_beam_send_done          ,
input                       ld_mode_in                  ,
output reg                  ld_o                        ,
output reg                  dary_o                      ,
output reg                  temper_en                   ,
input                       temper_read_done            ,
input                       temper_req                  ,
output                      reset
);


//-----------------温度请求处理逻辑-------------------//
//这样做的好处是有且只响应一次请求逻辑
reg temper_req_r;
wire temper_req_pos;
reg temper_req_keep;
always@(posedge sys_clk)begin
    temper_req_r <= temper_req;
end
assign temper_req_pos = ~temper_req_r && temper_req;

always@(posedge sys_clk)begin
    if(sys_rst)
        temper_req_keep <= 0;
    else if(temper_req_pos)
        temper_req_keep <= 1;
    else if(temper_req_keep && temper_en)
        temper_req_keep <= 0;
end

reg flag;
reg [31:0] cnt;



reg now_beam_get_done;
// wire group_data_send_done;
// assign group_data_send_done = ld_done;

//-----------------valid打两拍降低亚稳态------------------//
reg [2:0] valid_r;
wire valid_pos;//打两拍再检测上升沿
reg valid_pos_r0=0;
always@(posedge sys_clk)begin
    if(sys_rst)
        valid_r <= 0;
    else 
        valid_r <= {valid_r[1:0],valid_in};
end
assign valid_pos = ~valid_r[2] && valid_r[1]; 
always@(posedge sys_clk) valid_pos_r0 <= valid_pos;
assign reset = sys_rst | valid_pos;
//-----------------检测prf信号上升沿------------------//
reg [2:0] prf_r;//打两拍再检测上升沿
wire prf_pos;
always@(posedge sys_clk)begin
    if(reset)
        prf_r <= 0;
    else 
        prf_r <= {prf_r[1:0],prf_in};
end
assign prf_pos = ~prf_r[2] && prf_r[1];
//-----------------------对mode打两拍减小亚稳态传播概率------------------------//
reg [1:0] ld_mode_r;
wire ld_mode;
always@(posedge sys_clk)begin
    if(reset)
        ld_mode_r <= 0;
    else 
        ld_mode_r <= {ld_mode_r[0],ld_mode_in};
end
assign ld_mode = ld_mode_r[1];

//-----------------------------------------------------//
//rd_data
reg                                   rd_en             ;
reg                                   rd_en_r0          ;
reg  [$clog2(GROUP_CHIP_NUM*GROUP_NUM)-1:0]     rd_cnt            ;
reg  [$clog2(GROUP_CHIP_NUM*GROUP_NUM)-1:0]     rd_cnt_r0         ;
wire [127:0]                          rd_data           ;

// reg  [23:0]                     beam_pos_cnt_temp ;
reg [23:0]                            beam_pos_cnt      ;

wire [31:0]                           rd_addr           ;

wire [31:0]                           base_addr         ;//ctrl
wire [31:0]                           offset_addr       ;


wire end_now_beam;//获取完当前波位,脉冲信号
assign end_now_beam = rd_cnt == (GROUP_CHIP_NUM * GROUP_NUM) - 1;


reg [4:0] c_state,n_state;
//----------------------------状态编码-------------------------------------//
localparam IDLE                         = 5'd0  ;
localparam ARBITRATE0                   = 5'd1  ;//判断是单波位还是多波位
localparam WAIT_PRF                     = 5'd2  ;
localparam CMD_GEN                      = 5'd3  ;
localparam SEND_CMD                     = 5'd4  ;
localparam DELAY1                       = 5'd5  ;//指令和数据之间的延时 0.5us
localparam GET_GROUP_DATA               = 5'd6  ;
localparam SEND_GROUP_DATA              = 5'd7  ;
localparam DELAY2                       = 5'd8  ;//组间延时
localparam WHETHER_BEAM_SEND_DONE       = 5'd9  ;
localparam WAIT_DARY                    = 5'd10 ;
localparam SEND_DARY                    = 5'd11 ;
localparam WAIT_LD                      = 5'd12 ;
localparam SEND_LD                      = 5'd13 ;
localparam ARBITRATE1                   = 5'd14 ;//判断是单波位还是多波位
localparam CHANGE_BW                    = 5'd15 ;
localparam READ_TEMPERATURE             = 5'd16 ;
localparam WHETHER_READ_TEMPERATURE     = 5'd17 ;
//---------------------状态切换相关变量定义-------------------------------//
// reg cmd_send_done,data_send_done;
// reg now_beam_get_done;
wire group_data_get_done;
reg  ld_done;

wire [63:0] ns_value_0,ns_value_1,time_1us,time_xus;
assign ns_value_0 = 1200;
`ifdef SAR
    assign ns_value_1 = 4500;
`else
    assign ns_value_1 = 1200;
`endif
assign time_1us = (ns_value_0 * SYSHZ) / 1000_000_000;
assign time_xus = (ns_value_1 * SYSHZ) / 1000_000_000;
reg [31:0] cnt_ld;
reg [31:0] cnt_delay;
wire [31:0] delay_valve;
assign delay_valve = 'd25;
//----------------------读取数据--------------------------//
wire get_req,get_start_flag;
reg get_ready;
always@(posedge sys_clk)begin
    if(reset)
        get_ready <= 1;
    else if(get_start_flag && get_ready)
        get_ready <= 0;
    else if(group_data_get_done)
        get_ready <= 1;
end

assign get_req = (c_state == GET_GROUP_DATA);
assign get_start_flag = get_req && get_ready;



//数据处理和拼接
reg [FRAME_DATA_BIT-1:0] data_buff [GROUP_CHIP_NUM-1:0];//缓存组内芯片对应的数据帧,一个深度是一个芯片，这里深度还只能是组内芯片数量，因为大sar是按组发的，缓存一个组就够了；其他模式也只有一个组


//-------rd_port生成
wire               add_rd_cnt;
wire               end_group_rd_cnt;
assign add_rd_cnt = rd_en;
assign end_group_rd_cnt = add_rd_cnt && rd_cnt[$clog2(GROUP_CHIP_NUM)-1:0] == GROUP_CHIP_NUM - 1;
always@(posedge sys_clk)begin
    if(reset)
        rd_en <= 0;
    else if(get_start_flag)
        rd_en <= 1;
    else if(end_group_rd_cnt)
        rd_en <= 0;
end
always@(posedge sys_clk)begin
    if(reset)
         rd_cnt <= 0;
    else if(add_rd_cnt)begin
        if(end_now_beam)
            rd_cnt <= 0;
        else
            rd_cnt <= rd_cnt +1;
    end    
end

always@(posedge sys_clk)begin
    if(reset)
        rd_cnt_r0 <= 0;
    else 
        rd_cnt_r0 <= rd_cnt;
end

always@(posedge sys_clk)begin
    if(reset)
        rd_en_r0 <= 0;
    else 
        rd_en_r0 <= rd_en;
end

integer j;
always@(posedge sys_clk)begin
    if(reset)begin
        for(j = 0; j < 16; j = j + 1)
            data_buff[j] <= 0;
    end
    else if(rd_en_r0)
        data_buff[rd_cnt_r0[$clog2(GROUP_CHIP_NUM)-1:0]] <= {2'b0,rd_data[96 + LANE_BIT - 1 : 96],rd_data[64 + LANE_BIT - 1 : 64],rd_data[32 + LANE_BIT - 1 : 32],rd_data[LANE_BIT - 1 : 0]};   
end

//发送数据拼接
wire [DATA_BIT - 1: 0] send_data;
genvar kk;
generate 
    for(kk = 0;kk < GROUP_CHIP_NUM;kk = kk + 1)begin:blk
        assign send_data[FRAME_DATA_BIT*(kk+1)-1:FRAME_DATA_BIT*kk] = data_buff[kk];
    end
endgenerate

//-----------------------addr_ctrl---------------------------//
// always@(posedge sys_clk)begin
//     if(reset)
//         beam_pos_cnt <= 0;
//     else if(valid_pos && beam_pos_num > 1)
//         beam_pos_cnt <= 0;
//     else if(end_now_beam)begin
//         if(beam_pos_cnt >= beam_pos_num - 1)
//             beam_pos_cnt <= 0;
//         else
//             beam_pos_cnt <= beam_pos_cnt + 1;
//     end
// end

// assign beam_pos_cnt = beam_pos_cnt_temp - 1   ;

//注意检测
localparam OFFSET_SHIFT = $clog2(READ_PORT_BYTES);
localparam BASE_SHIFT   = $clog2(BEAM_BYTES);

assign offset_addr  = rd_cnt << OFFSET_SHIFT      ;
assign base_addr    = beam_pos_cnt << BASE_SHIFT  ;
assign rd_addr      = base_addr + offset_addr     ;



assign group_data_get_done = rd_en_r0 && rd_cnt_r0[$clog2(GROUP_CHIP_NUM)-1:0] == GROUP_CHIP_NUM - 1;
//---------------------生成输出的中间变量定义--------------------------//
wire [3:0] group_id;
wire [3:0] delay_en;
wire [39:0] cmd_value;
// assign group_id = 8 + (rd_cnt >> 2);//rd_cnt >> 2才是组id
assign group_id = (rd_cnt / GROUP_CHIP_NUM);//rd_cnt >> 2才是组id
assign delay_en = {4{group_id == 0}};

wire        rd_delay_en;
wire [31:0] rd_delay_addr;
wire [31:0] rd_delay_data;

assign  rd_delay_en = (c_state == CMD_GEN);
assign  rd_delay_addr = beam_pos_cnt << 2;

assign cmd_value = {rd_delay_data,delay_en,group_id};


//----------------------------------状态机------------------------------------//
always@(posedge sys_clk)begin
    if(reset)
        c_state <= IDLE;
    else
        c_state <= n_state;
end
always@(*)begin
    if(reset)
        n_state = IDLE;
    else begin
        case (c_state)
            `ifdef SAR
                IDLE:begin
                    if(valid_pos_r0)//由于时序对齐的原因用打一拍后的信号
                        n_state = ARBITRATE0;
                    else
                        n_state = c_state;
                end 
            `else 
                IDLE:begin
                    if(valid_pos_r0)//由于时序对齐的原因用打一拍后的信号
                        n_state = CMD_GEN;
                    else
                        n_state = c_state;
                end 
            `endif
            ARBITRATE0: begin
                if(beam_pos_num == 1)
                    n_state = CMD_GEN;
                else
                    n_state = WAIT_PRF;
            end
            WAIT_PRF:begin
                if(prf_pos)
                    n_state = CMD_GEN;
                else
                    n_state = c_state;
            end
            CMD_GEN :begin
                n_state = SEND_CMD;
            end
            SEND_CMD :begin
                if(bc_group_send_done)
                    n_state = DELAY1;
                else
                    n_state = c_state;
            end
            DELAY1 :begin
                if(cnt_delay == delay_valve - 1)
                    n_state = GET_GROUP_DATA;
                else
                    n_state = c_state;
            end
            GET_GROUP_DATA :begin
                if(group_data_get_done)
                    n_state = SEND_GROUP_DATA;
                else
                    n_state = c_state;
            end
            SEND_GROUP_DATA :begin
                if(bc_group_send_done)
                    n_state = DELAY2;
                else
                    n_state = c_state;
            end
            DELAY2 :begin
                if(cnt_delay == delay_valve - 1)
                    n_state = WHETHER_BEAM_SEND_DONE;
                else
                    n_state = c_state;
            end
            WHETHER_BEAM_SEND_DONE :begin
                if(now_beam_get_done)
                    n_state = WAIT_DARY;
                else
                    n_state = CMD_GEN;
            end
            WAIT_DARY :begin
                if(ld_mode == 0)
                    n_state = SEND_DARY;
                else if(prf_pos)
                    n_state = SEND_DARY;
                else
                    n_state = c_state;
            end
            // WAIT_DARY :begin
            //     if(ld_mode == 0)
            //         n_state = SEND_DARY;
            //     else if(prf_pos)
            //         n_state = SEND_DARY;
            //     else
            //         n_state = c_state;
            // end
            SEND_DARY :begin
                if(cnt_ld == time_1us - 1)
                    n_state = WAIT_LD;
                else
                    n_state = c_state;
            end
            WAIT_LD :begin
                if(cnt_ld == time_1us - 1)
                    n_state = SEND_LD;
                else
                    n_state = c_state;
            end
            SEND_LD :begin
                if(cnt_ld == time_xus - 1)
                    n_state = WHETHER_READ_TEMPERATURE;
                else
                    n_state = c_state;
            end
            WHETHER_READ_TEMPERATURE :begin
                if(temper_req_keep)
                    n_state = READ_TEMPERATURE;
                else
                    n_state = ARBITRATE1;
            end
            READ_TEMPERATURE:begin
                if(temper_read_done)
                    n_state = ARBITRATE1;
                else
                    n_state = c_state;
            end
            ARBITRATE1: begin//latch done
                if(beam_pos_num == 1)
                    n_state = IDLE;
                else
                    n_state = CHANGE_BW;
            end
            `ifdef SAR
                CHANGE_BW : begin
                    n_state = WAIT_PRF;
                end
            `else
                CHANGE_BW : begin
                    n_state = CMD_GEN;
                end
            `endif
            default: n_state = IDLE;
        endcase
    end
end

always@(posedge sys_clk)begin
    if(reset)begin
        now_beam_get_done  <= 0;
        data_in            <= 0;
        trig               <= 0;
        mode               <= 0;
        flag               <= 0;
        beam_pos_cnt       <= 0;
        ld_done            <= 0;
        cnt_ld             <= 0;
        ld_o               <= 0;
        dary_o             <= 0;
        now_beam_send_done <= 0;
        cnt_delay          <= 0;
        temper_en          <= 0;
    end
    else begin
        case (c_state)
            IDLE: begin
                now_beam_get_done <= 0;
                data_in           <= 0;
                trig              <= 0;
                mode              <= 0;
                flag              <= 0;
                beam_pos_cnt      <= 0;
                ld_done           <= 0;
                cnt_ld            <= 0;
                ld_o              <= 0;
                dary_o            <= 0;
                now_beam_send_done<= 0; 
                cnt_delay         <= 0; 
                temper_en         <= 0;
            end
            ARBITRATE0:begin
                // flag <= 1;
            end
            SEND_CMD :begin
                flag <= 1;
                data_in <= cmd_value;
                trig    <= 1;
                mode    <= 1;
            end
            DELAY1 :begin
                if(cnt_delay == delay_valve - 1)
                    cnt_delay <= 0;
                else
                    cnt_delay <= cnt_delay + 1;
            end
            GET_GROUP_DATA :begin
                trig <= 0;
                mode <= 0;
                if(end_now_beam)
                    now_beam_get_done <= 1;
                else
                    now_beam_get_done <= now_beam_get_done;
            end
            SEND_GROUP_DATA :begin
                data_in <= send_data;
                trig <= 1;
                mode <= 0;
            end
            DELAY2 :begin
                if(cnt_delay ==  delay_valve- 1)
                    cnt_delay <= 0;
                else
                    cnt_delay <= cnt_delay + 1;
            end
            WHETHER_BEAM_SEND_DONE :begin
                if(now_beam_get_done)
                    flag <= 0;
                trig <= 0;
            end
            SEND_DARY :begin
                dary_o <= 1;
                if(cnt_ld == time_1us - 1)begin
                    cnt_ld               <= 0;
                end
                else begin 
                    cnt_ld               <= cnt_ld + 1;
                end
            end
            WAIT_LD :begin
                dary_o <= 0;
                if(cnt_ld == time_1us - 1)begin
                    cnt_ld               <= 0;
                end
                else begin 
                    cnt_ld               <= cnt_ld + 1;
                end
            end
            SEND_LD :begin
                ld_o <= 1;
                if(cnt_ld == time_xus - 1)begin
                    cnt_ld               <= 0;
                    ld_done              <= 1;
                end
                else begin 
                    cnt_ld               <= cnt_ld + 1;
                    ld_done              <= 0;
                end
            end
            READ_TEMPERATURE :begin
                temper_en <= 1;
            end
            ARBITRATE1 :begin
                temper_en <= 0;
                ld_o <= 0;
                now_beam_get_done <= 0;
                now_beam_send_done <= 1;
                    
            end
            CHANGE_BW :begin
                now_beam_send_done <= 0;
                if(beam_pos_cnt >= beam_pos_num - 1)
                    beam_pos_cnt <= 0;
                else
                    beam_pos_cnt <= beam_pos_cnt + 1;
            end
        endcase
    end
end
// always@(posedge sys_clk)begin
//     if(reset)
//         beam_pos_cnt <= 0;
//     else if(valid_pos && beam_pos_num > 1)
//         beam_pos_cnt <= 0;
//     else if(end_now_beam)begin
//         if(beam_pos_cnt >= beam_pos_num - 1)
//             beam_pos_cnt <= 0;
//         else
//             beam_pos_cnt <= beam_pos_cnt + 1;
//     end
// end
bram u_bram (
  .clka (bc_ram_clk ), 
  .ena  (bc_ram_en  ), 
  .wea  (bc_ram_we  ),//4 
  .addra(bc_ram_addr),//32 
  .dina (bc_ram_din ),//32 
  .douta(bc_ram_dout),//32 
  .rsta (bc_ram_rst ), 
  .clkb (sys_clk    ),//1 
  .enb  (rd_en      ),//1 
  .web  (0          ),//16 
  .addrb(rd_addr    ),//32 
  .dinb (0          ),//128 
  .doutb(rd_data    ),//128 
  .rstb (0          )  
);

bram_delay u_bram_delay (
  .clka         (delay_ram_clk      ),
  .ena          (delay_ram_en       ),
  .wea          (delay_ram_we       ),//4
  .addra        (delay_ram_addr     ),//32
  .dina         (delay_ram_din      ),//32
  .douta        (delay_ram_dout     ),//32
  .rsta         (delay_ram_rst      ),
  .clkb         (sys_clk            ),//1
  .enb          (rd_delay_en        ),//1
  .web          (0                  ),//4
  .addrb        (rd_delay_addr      ),//32
  .dinb         (0                  ),//32
  .doutb        (rd_delay_data      ),//32
  .rstb         (0                  )
);

//------------------------调试信号
reg  [23:0]                     rd_addr_r0        ;
reg  [23:0]                     beam_pos_cnt_r0   ;
always@(posedge sys_clk)begin
    if(reset)
        beam_pos_cnt_r0 <= 0;
    else
        beam_pos_cnt_r0 <= beam_pos_cnt;
end

always@(posedge sys_clk)begin
    if(reset)
        rd_addr_r0 <= 0;
    else
        rd_addr_r0 <= rd_addr;
end

`ifdef DEBUG
ila_sd_da_sar u_ila_sd_da_sar(
.clk          (sys_clk 		  ),
.probe0      (ld_o             ),//1
.probe1      (dary_o           ),//1
.probe2      (c_state          ),//5
.probe3      (n_state          ),//5
.probe4      (valid_pos        ),//1
.probe5      (prf_pos          ),//1
.probe6      (beam_pos_cnt_r0  ),//24
.probe7      (beam_pos_num     ),//32
.probe8      (valid_in         ) //1

);

ila_bram_read u_ila_bram_read (
	.clk(sys_clk), // input wire clk


	.probe0(rd_en), // input wire [0:0]  probe0  
	.probe1(rd_addr), // input wire [31:0]  probe1 
	.probe2(rd_data), // input wire [127:0]  probe2
	.probe3(send_data[25:0]) // input wire [25:0]  probe2
); 

`endif


always@(posedge sys_clk)begin
    if(reset)
        cnt <= 0;
    else if(flag)
        cnt <= cnt + 1;
    else
        cnt <= 0;
end


endmodule

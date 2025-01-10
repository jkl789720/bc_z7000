`include "configure.vh"
//注意要发两次读指令，第二次数据字段才是返回的温度值
//add_cnt_cycle 和 bit需要更改
//115bit
`timescale 1ns / 1ps
module temperature#(
    parameter LANE_BIT         = 20                              ,
    parameter FRAME_DATA_BIT   = 80                              ,
    parameter GROUP_CHIP_NUM   = 4                               ,
    parameter GROUP_NUM        = 16                              ,
    parameter DATA_BIT         = FRAME_DATA_BIT * GROUP_CHIP_NUM ,
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 10_000_000                      ,
    parameter READ_PORT_BYTES  = 16                              ,                
    parameter WRITE_PORT_BYTES = 4                               ,                
    parameter BEAM_BYTES       = GROUP_CHIP_NUM * GROUP_NUM * 16 ,
    parameter CMD_BIT          = 10                              ,
    parameter BEAM_NUM         = 1024
)
(
input                               sys_clk                      ,
input                               reset                        ,

input  [DATA_BIT-1:0]               data_in                      ,
input                               trig                         ,
input                               mode                         ,//mode 为0表示发送数据 为1表示发送指令
output reg                          sel_o                        ,
output reg                          cmd_flag                     ,
output reg                          scl_o                        ,
output reg [GROUP_CHIP_NUM-1:0]     sd_o                         ,
output                              rst_o                        ,
output reg                          bc_group_send_done                 ,

input                               temper_en                    ,
output     [7:0]                    temper_data0                 ,
output     [7:0]                    temper_data1                 ,
output     [7:0]                    temper_data2                 ,
output     [7:0]                    temper_data3                 ,
output reg                          temper_data_valid            ,
output                              temper_read_done             ,

input      [GROUP_CHIP_NUM-1:0]     sd_i                         ,
input                               ld_o                         ,
input                               dary_o                       ,
input                               tr_o                         ,
output reg [31:0]                   cnt_bit
);

reg [7:0] temper_data_buf [GROUP_CHIP_NUM-1:0];
reg [FRAME_DATA_BIT-1:0] data_in_temp_data [GROUP_CHIP_NUM-1:0];
reg [40-1:0] data_in_temp_cmd;


//---------------------temper_en上升沿----------------------//
reg temper_en_r;
wire temper_en_pos; 
always@(posedge sys_clk)begin
    if(reset)
        temper_en_r <= 0;
    else
        temper_en_r <= temper_en;
end
assign temper_en_pos    = temper_en && (~temper_en_r);

//---------------------trig上升沿----------------------//
reg trig_r;
wire trig_pos; 
always@(posedge sys_clk)begin
    if(reset)
        trig_r <= 0;
    else
        trig_r <= trig;
end
assign trig_pos    = trig && (~trig_r);
wire [31:0] cycle,cycle_mid;
assign cycle            = SYSHZ / SCLHZ ;
assign cycle_mid        = cycle >> 1;
//状态变量定义
localparam IDLE         = 0;
localparam MODE_CHANGE0 = 1;
localparam DELAY0       = 2;
localparam TEMPER_READ0 = 3;
localparam DELAY1       = 4;
localparam TEMPER_READ1 = 5;
localparam DELAY2       = 6;
localparam MODE_CHANGE1 = 7;
localparam BC_SEND      = 8;

//-------------------状态切换相关条件定义-----------------------//
wire mode_change1_done,mode_change0_done;
wire temper_read1_done,temper_read0_done;
wire add_cnt_bit;
wire end_cnt_bit;
reg [31:0] cnt_cycle;
// reg [31:0] cnt_bit;
assign add_cnt_bit = cnt_cycle == cycle - 1;
assign end_cnt_bit = add_cnt_bit && ((mode == 1 && cnt_bit == CMD_BIT + 2 - 1) || (mode == 0 && cnt_bit == FRAME_DATA_BIT + 2 - 1));//+2是为了留起始位和停止位

reg [3:0] c_state,n_state;



//--------------------------与输出相关的变量定义------------------------------//
wire bc_data_send_flag;
wire bc_cmd_send_flag;
wire temper_send_flag;
assign bc_data_send_flag = (cnt_bit > 0 && cnt_bit <= FRAME_DATA_BIT);
assign bc_cmd_send_flag =  (cnt_bit > 0 && cnt_bit <= CMD_BIT);
assign temper_send_flag =  cnt_bit >= 2 && cnt_bit <= 14;
wire [11:0] temper_cmd_value;
reg  [11:0] temper_cmd_value_buff[GROUP_CHIP_NUM-1:0];
assign temper_cmd_value = {4'b0110,8'h02};

reg flag;

always@(posedge sys_clk)begin
    if(reset)
        c_state <= IDLE;
    else
        c_state <= n_state;
end

always@(*)begin
    if(reset)
        n_state = IDLE;
    else
        case (c_state)
            IDLE :begin
                if(temper_en_pos)
                    n_state = MODE_CHANGE0;
                else if(trig_pos)
                    n_state = BC_SEND;
                else
                    n_state = c_state;
            end 
            MODE_CHANGE0 :begin
                if(mode_change0_done)
                    n_state = DELAY0;
                else
                    n_state = c_state;
            end
            DELAY0 :begin
                if(cnt_cycle == cycle - 1)
                    n_state = TEMPER_READ0;
                else
                    n_state = c_state;
            end
            TEMPER_READ0 :begin
                if(temper_read0_done)
                    n_state = DELAY1;
                else
                    n_state = c_state;
            end
            DELAY1 :begin
                if(cnt_cycle == cycle - 1)
                    n_state = TEMPER_READ1;
                else
                    n_state = c_state;
            end
            TEMPER_READ1 :begin
                if(temper_read1_done)
                    n_state = DELAY2;
                else
                    n_state = c_state;
            end
            DELAY2 :begin
                if(cnt_cycle == cycle - 1)
                    n_state = MODE_CHANGE1;
                else
                    n_state = c_state;
            end
            MODE_CHANGE1 :begin
                if(mode_change1_done)
                    n_state = IDLE;
                else
                    n_state = c_state;
            end
            BC_SEND :begin
                if(add_cnt_bit)begin
                    if(end_cnt_bit)
                        n_state = IDLE;
                    else 
                        n_state = c_state;             
                end
                else
                    n_state = c_state; 
            end
            default: n_state = IDLE;
        endcase
end
reg test_flag;
always@(posedge sys_clk)begin
    if(reset)begin
        cnt_bit           <= 0;
        cnt_cycle         <= 0;
        sel_o             <= 1;
        cmd_flag          <= 0;
        scl_o             <= 0;
        test_flag         <= 0;
        data_in_temp_cmd  <= 0;
    end
    else begin
        case (c_state)
            IDLE :begin
                cnt_bit            <= 0;
                cnt_cycle          <= 0;
                sel_o              <= 1;
                cmd_flag           <= 0;
                scl_o              <= 0;
                test_flag          <= 0;
                data_in_temp_cmd   <= data_in;
            end 
            MODE_CHANGE0,MODE_CHANGE1 :begin
                if(cnt_cycle == cycle - 1)
                    cnt_cycle <= 0;
                else
                    cnt_cycle <= cnt_cycle + 1;

                if(cnt_cycle == cycle - 1)begin
                    if(cnt_bit == 16)
                        cnt_bit     <= 0;
                    else
                        cnt_bit <= cnt_bit + 1;
                end
                else
                    cnt_bit <= cnt_bit;

                if(cnt_cycle == cycle - 1)begin
                    if(cnt_bit == 0)
                        sel_o      <= 0;
                    else if(cnt_bit == 8)
                        sel_o      <= 1;
                    else if(cnt_bit == 14)
                        sel_o      <= 0;
                    else if(cnt_bit == 16)
                        sel_o      <= 1;
                end

                case (cnt_bit)
                    2,3,4,10,11,12,13 :begin
                        if(cnt_cycle == 0)//换成零看看行不行;看看cycle最大值小的时候能不能满足需求
                            scl_o      <= 0;
                        else if(cnt_cycle == cycle_mid)
                            scl_o      <= 1;
                    end
                    7,8,9:begin
                        scl_o      <= 1;
                    end
                    default: scl_o      <= 0;
                endcase

            end
            DELAY0,DELAY1,DELAY2:begin
                if(cnt_cycle == cycle - 1)
                    cnt_cycle <= 0;
                else
                    cnt_cycle <= cnt_cycle + 1;
            end
            TEMPER_READ0,TEMPER_READ1 :begin
                test_flag   <= 1;
                if(cnt_cycle == cycle - 1)
                    cnt_cycle <= 0;
                else
                    cnt_cycle <= cnt_cycle + 1;
                
                if(cnt_cycle == cycle - 1)begin
                    if(cnt_bit == 38)begin
                        cnt_bit     <= 0;
                    end
                    else
                        cnt_bit <= cnt_bit + 1;
                end

                if(cnt_cycle == cycle - 1)begin
                    if(cnt_bit == 0)
                        sel_o      <= 0;
                    else if(cnt_bit == 30)
                        sel_o      <= 1;
                    else if(cnt_bit == 36)
                        sel_o      <= 0;
                    else if(cnt_bit == 38)
                        sel_o      <= 1;
                end
                else
                    sel_o      <= sel_o     ;
                
                if((cnt_bit >= 2 && cnt_bit <= 29) || (cnt_bit >= 32 && cnt_bit <= 35))begin
                    if(cnt_cycle == 0)//换成零看看行不行;看看cycle最大值小的时候能不能满足需求
                        scl_o      <= 0;
                    else if(cnt_cycle == cycle_mid)
                        scl_o      <= 1;
                end
                else if(cnt_bit == 30 || cnt_bit == 31)
                    scl_o      <= 1;
                else
                    scl_o      <= 0;

                // if(temper_send_flag)begin//发送温度数据
                //     if(cnt_cycle == 0)begin
                //         sd        <= temper_cmd_value_buff[11];
                //         temper_cmd_value_buff <= {temper_cmd_value_buff[10:0],1'b0};
                //     end
                //     else begin
                //         sd        <= sd       ;
                //         temper_cmd_value_buff <= temper_cmd_value_buff;
                //     end
                // end

            end
            BC_SEND:begin
                if(cnt_cycle == cycle - 1)
                    cnt_cycle <= 0;
                else 
                    cnt_cycle <= cnt_cycle + 1;

                if(add_cnt_bit)begin
                    if(end_cnt_bit)
                        cnt_bit <= 0;
                    else 
                        cnt_bit <= cnt_bit + 1;
                end
                
                if((bc_data_send_flag && mode == 0) || (bc_cmd_send_flag && mode == 1))begin
                    if(cnt_cycle == cycle_mid)    
                        scl_o      <= 1;
                    else if(cnt_cycle == cycle - 1)
                        scl_o      <= 0;
                end

                if(end_cnt_bit)begin
                    sel_o    <= 1;
                    cmd_flag <= 0;
                end
                else begin
                   sel_o    <= mode;
                    cmd_flag <= mode; 
                end
                
                    
            end
        endcase
    end
end

genvar ii;
generate
for(ii = 0; ii < GROUP_CHIP_NUM ; ii = ii + 1)begin:blk1
    always@(posedge sys_clk)begin
        if(reset)begin
            data_in_temp_data[ii]  <= 0;  
            sd_o[ii]          <= 0;
        end
        else begin
            case (c_state)
                IDLE :begin
                    data_in_temp_data[ii] <= data_in[(ii+1)*FRAME_DATA_BIT-1:ii*FRAME_DATA_BIT];
                    temper_cmd_value_buff[ii]    <= temper_cmd_value;
                    sd_o[ii] <= 0 ;
                end 
                BC_SEND :begin
                    `ifdef G3
                        if(mode == 0)begin
                            if(cnt_cycle == 0 && bc_data_send_flag)begin
                                sd_o[ii] <= data_in_temp_data[ii][FRAME_DATA_BIT-1];
                                data_in_temp_data[ii] <= {data_in_temp_data[ii][FRAME_DATA_BIT-2:0],1'b0};
                            end
                            else begin
                                sd_o[ii] <= sd_o[ii];
                                data_in_temp_data[ii] <= data_in_temp_data[ii];
                            end
                        end
                        else begin
                            if(cnt_cycle == 0 && bc_cmd_send_flag)
                                sd_o[ii] <= data_in_temp_cmd[ii+((cnt_bit-1)<<2)];
                            else
                                sd_o[ii] <= sd_o[ii]; 
                        end
                            
                    `else
                        if(mode == 0)begin
                            if(cnt_cycle == 0 && bc_data_send_flag)begin
                                sd_o[ii] <= data_in_temp_data[ii][0];
                                data_in_temp_data[ii] <= {1'b0,data_in_temp_data[ii][FRAME_DATA_BIT-1:1]};
                            end
                            else begin
                                sd_o[ii] <= sd_o[ii];
                                data_in_temp_data[ii] <= data_in_temp_data[ii];
                            end
                        end
                        else begin
                            if(cnt_cycle == 0 && bc_cmd_send_flag)
                                sd_o[ii] <= data_in_temp_cmd[ii+((cnt_bit-1)<<2)];
                            else
                                sd_o[ii] <= sd_o[ii]; 
                        end
                    `endif
                    test_flag = 1;
                end
                TEMPER_READ0,TEMPER_READ1:begin
                    //发送温度数据
                    if(temper_send_flag)begin
                        if(cnt_cycle == 0)begin
                            sd_o[ii]                    <= temper_cmd_value_buff[ii][11];
                            temper_cmd_value_buff[ii]   <= {temper_cmd_value_buff[ii][10:0],1'b0};
                        end
                        else begin
                            sd_o[ii]                    <= sd_o[ii]           ;
                            temper_cmd_value_buff[ii]   <= temper_cmd_value_buff[ii] ;
                        end
                    end

                    //接收温度数据
                    if(cnt_cycle == cycle_mid && cnt_bit >= 22 && cnt_bit <= 29 && c_state == TEMPER_READ1)
                        temper_data_buf[ii] <= {temper_data_buf[ii][6:0],sd_i[ii]};
                    else 
                        temper_data_buf[ii] <= temper_data_buf[ii];

                end
            endcase
        end
    end
end
endgenerate
assign temper_data0 = temper_data_buf[0];
assign temper_data1 = temper_data_buf[4];
assign temper_data2 = temper_data_buf[8];
assign temper_data3 = temper_data_buf[12];

always@(posedge sys_clk)begin
    if(reset)
        flag <= 0;
    else if(c_state == MODE_CHANGE0)
        flag <= 1;
    else if(c_state == MODE_CHANGE1 && mode_change1_done)
        flag <= 0;
end

reg [31:0] cnt;
always@(posedge sys_clk)begin
    if(reset)
        cnt <= 0;
    else if(flag)
        cnt <= cnt + 1;
    else
        cnt <= 0;
end

assign mode_change1_done = cnt_cycle == cycle - 1 && cnt_bit == 16;
assign mode_change0_done = cnt_cycle == cycle - 1 && cnt_bit == 16;
assign temper_read1_done = cnt_cycle == cycle - 1 && cnt_bit == 38;
assign temper_read0_done = cnt_cycle == cycle - 1 && cnt_bit == 38;

always@(posedge sys_clk)begin
    if(reset)
        temper_data_valid <= 0;
    else if(cnt_cycle == cycle_mid && cnt_bit == 29 && c_state == TEMPER_READ1)
        temper_data_valid <= 1;
    else if(temper_en)
        temper_data_valid <= 0;
end

// always@(posedge sys_clk)begin
//     if(reset)
//         temper_read_done <= 0;
//     else if(cnt_cycle == cycle_mid && cnt_bit == 38 && c_state == TEMPER_READ1)
//         temper_read_done <= 1;
//     else 
//         temper_read_done <= 0;
// end

assign temper_read_done = mode_change1_done;

always@(posedge sys_clk)begin
    if(reset)
        bc_group_send_done <= 0;
    else if(end_cnt_bit && c_state == BC_SEND)
        bc_group_send_done <= 1;
    else 
        bc_group_send_done <= 0;
end

//上电给芯片复位
reg [15:0] cnt_reset = 100;

always@(posedge sys_clk)begin
    if(cnt_reset > 0)
        cnt_reset <= cnt_reset - 1;
    else
        cnt_reset <= cnt_reset;
end

assign rst_o = cnt_reset > 0 && cnt_reset <= 90;

endmodule

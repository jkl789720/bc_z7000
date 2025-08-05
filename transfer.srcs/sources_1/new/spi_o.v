`timescale 1ns / 1ps
module spi_o#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000
)(
    input                       sys_clk     ,
    input                       sys_rst     ,

    input   [FRAM_BIT_NUM-1:0]  data_in     ,
    input                       trig_in     ,

    output                      cs_n        ,
    output  reg                 scl         ,
    output  reg                 mosi        ,

    output                      send_done
);

localparam CYCLE = SYS_HZ / SCL_HZ;
localparam MID = CYCLE / 2;

//计数器信号
reg cnt_cycle_flag;
reg [7:0] cnt_cycle;
wire add_cnt_cycle,end_cnt_cycle;
reg [7:0] cnt_bit;
wire add_cnt_bit,end_cnt_bit;

//trig信号上升沿信号
reg trig_in_r;
wire trig_in_pos;

//out_shift_reg
reg [FRAM_BIT_NUM-1:0] shift_reg;

wire data_send_flag;//指示整个数据发送的时间段
wire bit_send_flag;//指示bit发送的那一个时钟周期

//------------------------------trig信号打拍--------------------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        trig_in_r <= 0;
    else
        trig_in_r <= trig_in;
end

assign trig_in_pos = ~trig_in_r && trig_in;

//-----------------------计数器生成----------------------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_cycle_flag <= 0;
    else if(trig_in_pos)
        cnt_cycle_flag <= 1;
    else if(send_done)
        cnt_cycle_flag <= 0;
end

assign add_cnt_cycle = cnt_cycle_flag;
assign end_cnt_cycle = add_cnt_cycle && cnt_cycle == CYCLE - 1;

assign add_cnt_bit = end_cnt_cycle;
assign end_cnt_bit = add_cnt_bit && cnt_bit == FRAM_BIT_NUM + 1;//多两个bit分别是起始位和停止位

always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_cycle <= 0;
    else if(trig_in_pos)
        cnt_cycle <= 0;
    else if(add_cnt_cycle)begin
        if(end_cnt_cycle)
            cnt_cycle <= 0;
        else
            cnt_cycle <= cnt_cycle + 1;
    end
end

always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_bit <= 0;
    else if(trig_in_pos)
        cnt_bit <= 0;
    else if(add_cnt_bit)begin
        if(end_cnt_bit)
            cnt_bit <= 0;
        else
            cnt_bit <= cnt_bit + 1;
    end
end

//----------------------输出信号生成------------------------//
assign data_send_flag = !cs_n && (cnt_bit > 0 && cnt_bit <= FRAM_BIT_NUM);
always @(posedge sys_clk) begin
    if(sys_rst)
        scl <= 0;
    else if(data_send_flag)begin
        if(cnt_cycle == 0)
            scl <= 0;
        else if(cnt_cycle == MID)
            scl <= 1;
    end
    else
        scl <= 0;
end

assign bit_send_flag = cnt_cycle == 0 && data_send_flag;
always @(posedge sys_clk) begin
    if(sys_rst)begin
        mosi <= 0;
        shift_reg <= 0;
    end
    else if(trig_in)
        shift_reg <= data_in;
    else if(bit_send_flag)begin
        mosi <= shift_reg[FRAM_BIT_NUM-1];
        shift_reg <= {shift_reg[FRAM_BIT_NUM-2:0],1'b0};
    end
end

assign cs_n = ~add_cnt_cycle;

assign send_done = end_cnt_bit;

endmodule

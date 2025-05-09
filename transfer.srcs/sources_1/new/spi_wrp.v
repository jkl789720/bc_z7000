`include "configure.vh"
`timescale 1ns / 1ps
module spi_wrp#(
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 10_000_000                      ,
    parameter DATA_WIDTH        = 28                      
)(
    input                   sys_clk     ,
    input                   sys_rst     ,
    input                   wr_en       ,
    input  [DATA_WIDTH-1:0] wr_data     ,//在这里包含控制字段和数据字段
    
    output reg              cs_n        ,
    output reg              sclk        ,
    output reg              mosi        ,
    input                   miso        ,
    output reg              wr_done     ,
    output reg [23:0]       recv_data 
);
localparam  CYCLE               = SYSHZ / SCLHZ ;//5
localparam  CYCLE_MID           = CYCLE/2;//2
localparam  SPI_WIDTH           = DATA_WIDTH + 15;//10个bit附加字段，5bit保护字段
reg [7:0]                   cnt_cycle;
wire [7:0]                   sample_offset_cycle;
reg [$clog2(SPI_WIDTH)-1:0] cnt_bit;
reg work_flag;
reg [DATA_WIDTH-1:0] wr_data_tmp;
reg wr_en_r;
wire wr_en_pos;
//--------------上升沿提取--------------//
always@(posedge sys_clk)begin
    if(sys_rst)
        wr_en_r <= 0;
    else 
        wr_en_r <= wr_en;
end
assign wr_en_pos = wr_en && !wr_en_r;
//--------------计数器生成-----------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_cycle <= 0;
    else if(work_flag)begin 
        if(cnt_cycle == CYCLE - 1)
            cnt_cycle <= 0;
        else
            cnt_cycle <= cnt_cycle + 1;
    end
    else
        cnt_cycle <= 0;
end

always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_bit <= 0;
    else if(work_flag)begin
        if(cnt_cycle == CYCLE - 1)begin
            if(cnt_bit == SPI_WIDTH - 1)
                cnt_bit <= 0;
            else
                cnt_bit <= cnt_bit + 1;
        end
    end
    else 
        cnt_bit <= 0;
end

always @(posedge sys_clk) begin
    if(sys_rst)
        work_flag <= 0;
    else if(wr_en_pos)
        work_flag <= 1;
    else if(work_flag && cnt_bit == SPI_WIDTH - 1 && cnt_cycle == CYCLE - 1)
        work_flag <= 0;
end

always @(posedge sys_clk) begin
    if(sys_rst)
        wr_done <= 0;
    else if(work_flag && cnt_bit == SPI_WIDTH - 1 && cnt_cycle == CYCLE - 1)
        wr_done <= 1;
    else
        wr_done <= 0;
end

//----------------spi信号生成---------------------//
//cs
always @(posedge sys_clk) begin
    if(sys_rst)
        cs_n <= 1;
    else if(work_flag && cnt_bit == 0 && cnt_cycle == 0)
        cs_n <= 0;
    else if(cnt_bit == DATA_WIDTH + 3 && cnt_cycle == 0) 
        cs_n <= 1;
    else if(cnt_bit == DATA_WIDTH + 9 && cnt_cycle == 0)
        cs_n <= 0;
    else if(cnt_bit == DATA_WIDTH + 9 && cnt_cycle == CYCLE - 1)
        cs_n <= 1;
end
always @(posedge sys_clk) begin
    if(sys_rst)
        sclk <= 0;
    else if((cnt_bit >= 1 && cnt_bit <= DATA_WIDTH) | (cnt_bit >= DATA_WIDTH + 4 && cnt_bit <= DATA_WIDTH + 7))begin
        if(cnt_cycle == 0)
            sclk <= 0;
        else if(cnt_cycle == CYCLE_MID)
            sclk <= 1;
    end
    else if(cnt_bit == DATA_WIDTH + 1)
            sclk <= 0;
    else if(cnt_bit == DATA_WIDTH + 2 | cnt_bit == DATA_WIDTH + 3)
            sclk <= 1;
    else if(cnt_bit == DATA_WIDTH + 8)
            sclk <= 0;
end
wire test_flag;
wire [2:0] sample_offset;
// assign test_flag = cnt_cycle == 1  && (cnt_bit >= 6 && cnt_bit <= DATA_WIDTH + 5);//注sim:仿真使用
assign test_flag = cnt_cycle == sample_offset_cycle && (cnt_bit >= sample_offset && cnt_bit <= sample_offset + 24 - 1);//注design:根据ila的时序图调整得到，在此刻能采集到正确回码数据 注debug
always @(posedge sys_clk) begin
    if(sys_rst)begin
        mosi <= 0;
        wr_data_tmp <= 0;
    end
    else if(wr_en_pos)
        wr_data_tmp <= wr_data;
    else if(cnt_cycle == 0 && (cnt_bit >= 1 && cnt_bit <= DATA_WIDTH))begin
        mosi <= wr_data_tmp[DATA_WIDTH - 1];
        wr_data_tmp <= {wr_data_tmp[DATA_WIDTH - 2:0],1'b0};
    end
end

always @(posedge sys_clk) begin
    if(sys_rst)begin
        recv_data <= 0;
    end
    else if(test_flag)begin
        recv_data <= {recv_data[22:0], miso};
    end
end
`ifdef DEBUG
    ila_spi_init u_ila_spi_init(
        .clk(sys_clk),
        .probe0(cs_n),
        .probe1(sclk),
        .probe2(miso),
        .probe3(recv_data),
        .probe4(test_flag),
        .probe5(wr_done),
        .probe6(cnt_bit),
        .probe7(cnt_cycle)
    );
vio_debug u_vio_debug(
        .clk(sys_clk),
        .probe_out0(sample_offset),
        .probe_out1(sample_offset_cycle)
    );
`endif
endmodule

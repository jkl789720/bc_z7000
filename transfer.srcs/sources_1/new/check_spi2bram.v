`timescale 1ns / 1ps
module check_spi2bram#(
    parameter GROUP_NUM = 8 //注意：个组是物理结构上的组数，跟顶层模块参数不同
)(
    input                           sys_clk     ,
    input                           sys_rst     ,
    input   [23 : 0]                beam_pos_cnt ,
    input  [GROUP_NUM*4-1:0]        mosi        ,
    input  [GROUP_NUM - 1:0]        scl         ,
    input  [GROUP_NUM - 1:0]        cs_n        ,
    output                          bram_clk    ,
    output                          bram_we     ,
    output      [31:0]              bram_addr   ,
    output      [31:0]              bram_data   ,
    output reg                      bram_wr_done
    );
localparam LANE_NUM = GROUP_NUM * 16;
localparam CHIP_NUM = GROUP_NUM * 4;
localparam  FRAM_BIT_NUM = 106; 
wire [FRAM_BIT_NUM-1:0]         rd_data  [CHIP_NUM-1:0]   ;
wire [CHIP_NUM-1:0]             rd_datav            ;

reg [26-1:0]  rd_data_keep  [LANE_NUM-1:0];
reg  [CHIP_NUM-1:0]              rd_datav_keep  ;
reg [$clog2(LANE_NUM)-1:0] cnt_lane;
wire add_cnt_lane,end_cnt_lane;
reg work_flag;
integer i,j;

//数据有效信号寄存
always @(posedge sys_clk) begin
    if(sys_rst)begin
        rd_datav_keep <= 0;
    end
    else begin
        rd_datav_keep <= rd_datav;
    end
end
//数据寄存，按通道存储
always @(posedge sys_clk) begin
    if(sys_rst)begin
        for(i = 0;i < GROUP_NUM;i = i + 1)begin//i遍历组
            for(j = 0;j < 4;j = j + 1)begin//j遍历芯片
                rd_data_keep[i*16+(j*4+0)] <= 0; 
                rd_data_keep[i*16+(j*4+1)] <= 0; 
                rd_data_keep[i*16+(j*4+2)] <= 0; 
                rd_data_keep[i*16+(j*4+3)] <= 0; 
            end
        end
    end
    else begin
        for(i = 0;i < GROUP_NUM;i = i + 1)begin//i遍历组
            for(j = 0;j < 4;j = j + 1)begin//j遍历芯片
                rd_data_keep[i*16+(j*4+0)] <= rd_data[i*4+j][25:0  ]; //i*4+j是芯片索引 i*16+(j*4+0)是通道索引
                rd_data_keep[i*16+(j*4+1)] <= rd_data[i*4+j][51:26 ]; 
                rd_data_keep[i*16+(j*4+2)] <= rd_data[i*4+j][77:52 ]; 
                rd_data_keep[i*16+(j*4+3)] <= rd_data[i*4+j][103:78]; 
            end
        end
    end
end
//生成工作标志
always @(posedge sys_clk) begin
    if(sys_rst)
        work_flag <= 0;
    else if(|rd_datav_keep)
        work_flag <= 1;
    else if(end_cnt_lane)
        work_flag <= 0;
end

//生成计数器
assign add_cnt_lane = work_flag;
assign end_cnt_lane = add_cnt_lane && cnt_lane == LANE_NUM - 1;
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_lane <= 0;
    else if(add_cnt_lane)begin
        if(end_cnt_lane)
            cnt_lane <= 0;
        else 
            cnt_lane <= cnt_lane + 1;
    end
end
//生成bram端口
assign bram_clk = sys_clk;
assign bram_we = work_flag;
assign bram_addr = beam_pos_cnt * LANE_NUM + cnt_lane;
assign bram_data = rd_data_keep[cnt_lane];
always @(posedge sys_clk) begin
    if(sys_rst)
        bram_wr_done <= 0;
    else
        bram_wr_done <= end_cnt_lane;
end

wire [7:0] scl_temp; 
wire [7:0] cs_n_temp;

assign scl_temp  = {{4{scl[1]}},{4{scl[0]}}};  // 正确拼接方式
assign cs_n_temp = {{4{cs_n[1]}},{4{cs_n[0]}}};
genvar kk;
generate
    for(kk = 0; kk < CHIP_NUM;kk = kk + 1)begin:gen_spi_slv
        spi_slv#(
            . FRAM_BIT_NUM (FRAM_BIT_NUM)
        ) uspi_slv(
        . sys_clk   (sys_clk        )  ,
        . sys_rst   (sys_rst        )  ,
        . mosi      (mosi[kk]       )  ,//
        . scl       (scl_temp[kk]            )  ,
        . cs_n      (cs_n_temp[kk]           )  ,
        . rd_data   (rd_data[kk]    )  ,//
        . rd_datav  (rd_datav[kk]   )   //
        );
    end
endgenerate


endmodule

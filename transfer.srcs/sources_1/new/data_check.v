/*
data_check #(
    .FRAM_BIT_NUM    (24),          // 默认 24，可修改
    .SYS_HZ          (50_000_000),  // 系统时钟频率（Hz）
    .SCL_HZ          (1_000_000),   // SCL时钟频率（Hz）
    .SPI_CHANNEL     (8),           // SPI通道数
    .SPI_LANE        (4)            // SPI Lane数
) u_data_check (
    .sys_clk          (sys_clk),           // 输入：系统时钟
    .sys_rst          (sys_rst),           // 输入：系统复位
    .bram_we          (bram_we),           // 输入：BRAM写使能
    .bram_addr        (bram_addr),         // 输入：BRAM地址（32bit）
    .bram_data        (bram_data),         // 输入：BRAM数据（32bit）
    .bram_wr_done     (bram_wr_done),      // 输入：BRAM写入完成标志
    .now_frames       (now_frames),        // 输出：当前帧数（32bit）
    .cmltv_fail_frames(cmltv_fail_frames), // 输出：累计失败帧数（32bit）
    .nowfrm_fail_lanes(nowfrm_fail_lanes)  // 输出：当前帧失败Lane数（32bit）
);
*/

`timescale 1ns / 1ps
module data_check#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL   = 8,
    parameter SPI_LANE      = 4
)(
    input               sys_clk             ,
    input               sys_rst             ,
    input               bram_we             ,
    input      [31:0]   bram_addr           ,//递增1
    input      [31:0]   bram_data           ,
    input               bram_wr_done        ,
    output reg [31:0]   now_frames          ,
    output reg [31:0]   cmltv_fail_frames   ,
    output reg [31:0]   nowfrm_fail_lanes   
    );
localparam ENTRY_NUM = SPI_CHANNEL*SPI_LANE;

reg [15:0] cnt_lane;
wire cnt_error,data_error,error;
reg bram_we_r;
wire bram_we_rising,bram_we_falling;
reg frame_disable;//确保一帧出错计数器只计数一次
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_lane <= 0;
    else if(bram_we)
        cnt_lane <= cnt_lane + 1;
end

assign cnt_error = bram_we && cnt_lane[$clog2(ENTRY_NUM)-1:0] != bram_addr[$clog2(ENTRY_NUM)-1:0];

(* keep = "true", dont_touch = "true" *)wire [31:0] ref_data;
// assign ref_data = {16'haaaa,11'b0,cnt_lane[4:0]};
assign ref_data = {16'haaaa,cnt_lane};//修改这里可以修改激励
assign data_error = bram_we && bram_data != ref_data;

assign error = (cnt_error || data_error);

//--写使能上升沿
always@(posedge sys_clk)begin
    if(sys_rst)
        bram_we_r <= 0;
    else 
        bram_we_r <= bram_we;
end
assign bram_we_rising = !bram_we_r && bram_we;
assign bram_we_falling = !bram_we && bram_we_r;
//记录帧数
always@(posedge sys_clk)begin
    if(sys_rst)
        now_frames <= 0;
    else if(bram_we_rising)
        now_frames <= now_frames + 1;
end
//生成禁用逻辑
always@(posedge sys_clk)begin
    if(sys_rst)
        frame_disable <= 0;
    else if(bram_we_falling)
        frame_disable <= 0;
    else if(error)
        frame_disable <= 1;
end
//生成错误帧数
always@(posedge sys_clk)begin
    if(sys_rst)
        cmltv_fail_frames <= 0;
    else if(error && !frame_disable)
        cmltv_fail_frames <= cmltv_fail_frames + 1;
end

always@(posedge sys_clk)begin
    if(sys_rst)
        nowfrm_fail_lanes <= 0;
    else if(bram_we_falling)
        nowfrm_fail_lanes <= 0;
    else if(error)
        nowfrm_fail_lanes <= nowfrm_fail_lanes + 1;
end

ila_data_check u_ila_data_check (
	.clk(sys_clk), // input wire clk
	.probe0(bram_we), // input wire [0:0]  probe0  
	.probe1(bram_addr), // input wire [31:0]  probe1 
	.probe2(cnt_lane), // input wire [15:0]  probe2 
	.probe3(bram_data), // input wire [31:0]  probe3 
	.probe4(ref_data), // input wire [31:0]  probe4 
	.probe5(cnt_error), // input wire [0:0]  probe5 
	.probe6(data_error), // input wire [0:0]  probe6 
	.probe7(error), // input wire [0:0]  probe7 
	.probe8(now_frames), // input wire [31:0]  probe8 
	.probe9(cmltv_fail_frames), // input wire [31:0]  probe9 
	.probe10(nowfrm_fail_lanes) // input wire [31:0]  probe10
);

endmodule

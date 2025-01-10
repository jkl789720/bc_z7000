`timescale 1ns / 1ps
`include "configure.vh"
module cpu_ctrl_sig_gen(
input      sys_rst        ,
input      sys_clk        ,
input      prf_in         ,
input      valid_in       ,
input      send_done      ,
input      rd_done        ,
output reg cpu_dat_sd_en  ,
output reg data_sending   
);


reg send_ready;

//-----------------检测prf信号上升沿------------------//
reg [2:0] prf_r;//打两拍再检测上升沿
wire prf_pos;
always@(posedge sys_clk)begin
    if(sys_rst)
        prf_r <= 0;
    else 
        prf_r <= {prf_r[1:0],prf_in};
end
assign prf_pos = ~prf_r[2] && prf_r[1];

//-----------------检测valid信号上升沿------------------//
reg [2:0] valid_r;//打两拍再检测上升沿
wire valid_pos;
always@(posedge sys_clk)begin
    if(sys_rst)
        valid_r <= 0;
    else 
        valid_r <= {valid_r[1:0],valid_in};
end
assign valid_pos = ~valid_r[2] && valid_r[1];

always@(posedge  sys_clk)begin
    if(sys_rst)
        data_sending <= 0;
    else if(prf_pos && send_ready)
        data_sending <= 1;
    else if(send_done)
        data_sending <= 0;
end

// assign send_ready = ~data_sending;

always@(posedge  sys_clk)begin
    if(sys_rst)
        send_ready <= 1;
    else if(send_done)
        send_ready <= 1;
    else if(prf_pos && send_ready)
        send_ready <= 0;
end

always@(posedge  sys_clk)begin
    if(sys_rst)
        cpu_dat_sd_en <= 0;
    else if(prf_pos && send_ready)
        cpu_dat_sd_en <= 1;
    else if(valid_pos)
        cpu_dat_sd_en <= 0;
end
//----------------------统计时间参数-------------------------//
reg [63:0] cnt_sending;
reg [63:0] cnt_sending_now;//本次发送时间
reg [63:0] cnt_sending_max;//最大发送时间
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_sending <= 0;
    else if(data_sending)
        cnt_sending <= cnt_sending + 1;
    else
        cnt_sending <= 0;//每次发送数据都要清零
end

always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_sending_now <= 0;
    else if(send_done)
        cnt_sending_now <= cnt_sending ;
end

always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_sending_max <= 0;
    else if(send_done)
        cnt_sending_max <= (cnt_sending  > cnt_sending_max)?cnt_sending :cnt_sending_max;
end

// ila_cpu_ctrl u_ila_cpu_ctrl(
// .clk          (sys_clk 		 ), 
// .probe0       (prf_in        ), 
// .probe1       (valid_in      ), 
// .probe2       (send_done     ), 
// .probe3       (rd_done       ), 
// .probe4       (cpu_dat_sd_en ), 
// .probe5       (send_ready    ),
// //
// .probe6 	  (data_sending	 )
// );


endmodule

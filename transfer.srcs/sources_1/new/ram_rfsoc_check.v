`timescale 1ns / 1ps
module ram_rfsoc_check(
input                   sys_clk         , 
input                   sys_rst         , 
input                   rama_clk        ,
input                   rama_en         ,
input       [3:0]       rama_wren       ,
input       [31:0]      rama_addr       ,
input       [31:0]      rama_din        ,
output      [31:0]      rama_dout       ,
output reg  [31:0]      check_fail_times
);

wire rst;
wire vio_reset;
assign rst = sys_rst || vio_reset;
vio_check_reset u_vio_check_reset (
  .clk(sys_clk),          
  .probe_out0(vio_reset)  
);

reg         rama_en_r[1:0]   ;
reg [3:0]   rama_wren_r[1:0] ;
reg [31:0]  rama_addr_r[1:0] ;
reg [31:0]  rama_din_r[1:0]  ;

//接收角度
wire [15:0] azi_angle;
wire [15:0] pitch_angle;


//本地角度
reg [15:0] pitch_angle_local;
reg [15:0] azi_angle_local;

always @(posedge sys_clk) begin
    if(rst)begin
        rama_en_r[0] <= 0;
        rama_en_r[1] <= 0;
    end 
    else begin
        rama_en_r[0] <= rama_en; 
        rama_en_r[1] <= rama_en_r[0];
    end
end

always @(posedge sys_clk) begin
    if(rst)begin
        rama_wren_r[0] <= 0;
        rama_wren_r[1] <= 0;
    end 
    else begin
        rama_wren_r[0] <= rama_wren; 
        rama_wren_r[1] <= rama_wren_r[0];
    end
end


always @(posedge sys_clk) begin
    if(rst)begin
        rama_addr_r[0] <= 0;
        rama_addr_r[1] <= 0;
    end 
    else begin
        rama_addr_r[0] <= rama_addr; 
        rama_addr_r[1] <= rama_addr_r[0];
    end
end

always @(posedge sys_clk) begin
    if(rst)begin
        rama_din_r[0] <= 0;
        rama_din_r[1] <= 0;
    end 
    else begin
        rama_din_r[0] <= rama_din; 
        rama_din_r[1] <= rama_din_r[0];
    end
end

//角度递增条件生成
wire add_azi,end_azi;
wire add_pitch,end_pitch;
assign add_azi = rama_en_r[1] && (rama_wren_r[1] == 4'hF) && (rama_addr_r[1] == 0);
assign end_azi = add_azi && azi_angle_local == 60;

assign add_pitch = end_azi;
assign end_pitch = add_pitch && pitch_angle_local == 60;

//校验逻辑生成
always @(posedge sys_clk) begin
    if(rst)
        check_fail_times <= 0;
    else if(add_azi)begin
        if(!(pitch_angle == pitch_angle_local && azi_angle == azi_angle_local))
            check_fail_times <= check_fail_times + 1;
        else
            check_fail_times <= check_fail_times;
    end
end
//本地角度生成
always @(posedge sys_clk) begin
    if(rst)
        azi_angle_local <= 0;
    else if(add_azi)begin
        if(end_azi)
            azi_angle_local <= 0;
        else
            azi_angle_local <= azi_angle_local + 1;
    end
end

always@(posedge sys_clk) begin
    if(rst)
        pitch_angle_local <= 0;
    else if(add_pitch)begin
        if(end_pitch)
            pitch_angle_local <= 0;
        else
            pitch_angle_local <= pitch_angle_local + 1;
    end
end
//输入角度
assign azi_angle   = rama_din_r[1][15:0];
assign pitch_angle = rama_din_r[1][31:16];

ila_ram_rfsoc_check u_ila_ram_rfsoc_check (
	.clk(sys_clk                ),
	.probe0(add_azi             ),
	.probe1(azi_angle           ),
	.probe2(pitch_angle         ),
	.probe3(pitch_angle_local   ),
	.probe4(azi_angle_local     ),
	.probe5(check_fail_times    ) 
);
endmodule

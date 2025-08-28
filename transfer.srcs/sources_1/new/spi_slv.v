`timescale 1ns / 1ps
module spi_slv#(
    parameter FRAM_BIT_NUM = 248
)(
input                           sys_clk     ,
input                           sys_rst     ,
input                           mosi        ,
input                           scl         ,
input                           cs_n        ,
output                          miso        ,
output reg [FRAM_BIT_NUM-1:0]   rd_data     ,
output reg                      rd_datav    
);


reg [10:0]   cs_n_r  ;
reg [5:0]   scl_r ;
reg [5:0]   mosi_r;

wire cs_n_neg;
wire cs_n_neg_rm_bur;

wire        scl_pos;

reg [$clog2(FRAM_BIT_NUM)-1:0]   cnt_bit;//6
wire        add_cnt_bit,end_cnt_bit;


assign scl_pos = ~scl_r[5] && scl_r[4] ;


//-------------------异步信号同步-----------------------//
always @(posedge sys_clk) begin
    if(sys_rst)begin
        cs_n_r   <= 0;
        scl_r  <= 0;
        mosi_r <= 0;
    end
    else begin
        cs_n_r   <= {cs_n_r[9:0],cs_n};
        scl_r  <= {scl_r [4:0],scl };
        mosi_r <= {mosi_r[4:0],mosi};
    end
end

assign cs_n_neg = cs_n_r[5] && ~cs_n_r[4] && ~cs_n_r[3] && ~cs_n_r[2] && ~cs_n_r[1] && ~cs_n_r[0];
assign cs_n_neg_rm_bur = cs_n_neg && cs_n_r[6] && cs_n_r[7] && cs_n_r[8] && cs_n_r[9] && cs_n_r[10];

//-------------------数据接收计数器生成-----------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_bit <= 0;
    else if(cs_n_neg_rm_bur)
        cnt_bit <= 0;
    else if(add_cnt_bit)begin
        if(end_cnt_bit)
            cnt_bit <= 0;
        else
            cnt_bit <= cnt_bit + 1;
    end  
end

assign add_cnt_bit = (!cs_n_r[5]) && scl_pos;
assign end_cnt_bit = add_cnt_bit && cnt_bit == FRAM_BIT_NUM - 1;

//--------------------数据接收逻辑---------------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        rd_data <= 0;
    else if(add_cnt_bit)
        rd_data <= {rd_data[FRAM_BIT_NUM-2:0],mosi_r[5]};
end

always @(posedge sys_clk) begin
    if(sys_rst)
        rd_datav <= 0;
    else
        rd_datav <= end_cnt_bit;
end
// ila_spi_recv u_ila_spi_recv (
// 	.clk(sys_clk), // input wire clk
// 	.probe0(cs_n_r[5]), // input wire [0:0]  probe0  
// 	.probe1(scl_r[5] ), // input wire [0:0]  probe1 
// 	.probe2(mosi_r[5]), // input wire [0:0]  probe2 
// 	.probe3(rd_datav), // input wire [0:0]  probe3 
// 	.probe4(rd_data), // input wire [105:0]  probe4 
// 	.probe5(cnt_bit), // input wire [6:0]  probe5
// 	.probe6(cs_n_neg), // input wire [6:0]  probe5
// 	.probe7(cs_n_neg_rm_bur) // input wire [6:0]  probe5
// );
endmodule

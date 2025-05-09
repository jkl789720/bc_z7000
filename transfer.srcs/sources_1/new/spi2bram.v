`timescale 1ns / 1ps
module spi2bram#
(
    parameter FRAM_BIT_NUM   = 45        ,
    parameter RAM_ADDR_WITDH = 13        ,
    parameter SYS_HZ         = 50_000_000,
    parameter SCL_HZ         = 10_000_000
)
(
    input                               sys_clk                     ,
    input                               sys_rst                     ,
    
    input                               cs_n                        ,
    input                               scl                         ,
    input                               mosi                        ,

    output                              ram_clk                     ,
    output                              ram_en                      ,
    output                              ram_wren                    ,
    output [RAM_ADDR_WITDH - 1:0]       ram_addr                    ,
    output [31:0]                       ram_din
);


reg [1:0]   cs_n_r  ;
reg [1:0]   scl_r ;
reg [1:0]   mosi_r;

wire cs_n_neg;

wire        scl_pos;

reg [$clog2(FRAM_BIT_NUM)-1:0]   cnt_bit;//6
wire        add_cnt_bit,end_cnt_bit;

reg [FRAM_BIT_NUM-1:0]  shift_reg;
reg         data_valid;

assign scl_pos = ~scl_r[1] && scl_r[0];


//-------------------异步信号同步-----------------------//
always @(posedge sys_clk) begin
    if(sys_rst)begin
        cs_n_r   <= 0;
        scl_r  <= 0;
        mosi_r <= 0;
    end
    else begin
        cs_n_r   <= {cs_n_r[0],cs_n};
        scl_r  <= {scl_r [0],scl };
        mosi_r <= {mosi_r[0],mosi};
    end
end

assign cs_n_neg = ~cs_n_r[0] && cs_n_r[1];


//-------------------数据接收计数器生成-----------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_bit <= 0;
    else if(cs_n_neg)
        cnt_bit <= 0;
    else if(add_cnt_bit)begin
        if(end_cnt_bit)
            cnt_bit <= 0;
        else
            cnt_bit <= cnt_bit + 1;
    end  
end

assign add_cnt_bit = (!cs_n_r[1]) && scl_pos;
assign end_cnt_bit = add_cnt_bit && cnt_bit == FRAM_BIT_NUM - 1;

//--------------------数据接收逻辑---------------------------//
always @(posedge sys_clk) begin
    if(sys_rst)
        shift_reg <= 0;
    else if(add_cnt_bit)
        shift_reg <= {shift_reg[FRAM_BIT_NUM-2:0],mosi_r[1]};
end

always @(posedge sys_clk) begin
    if(sys_rst)
        data_valid <= 0;
    else
        data_valid <= end_cnt_bit;
end


assign ram_clk  =  sys_clk                          ;
assign ram_en   =  1                                ;
assign ram_wren =  data_valid                       ;
assign ram_addr =  shift_reg[FRAM_BIT_NUM - 1:32]   ;
assign ram_din  =  shift_reg[31:0]                  ;

endmodule

`timescale 1ns / 1ps
module bram2spi#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 10_000_000
)(
    input           sys_clk     , 
    input           sys_rst     , 

    input           ram_clk     ,
    input           ram_en      ,
    input           ram_wren    ,
    input [7:0]     ram_addr    ,
    input [15:0]    ram_din     ,

    input  [31:0] 	app_param0	 ,
    input  [31:0] 	app_param1	 ,
    input  [31:0] 	app_param2	 ,

    output          cs_n        ,
    output          scl         ,
    output          mosi        
);

wire valid;

assign valid = app_param1[1];

wire   [FRAM_BIT_NUM-1:0]   data_in     ;
reg                         trig_in     ;
wire                        send_done   ;

wire                        ram_rd_en   ;
reg    [7:0]                ram_rd_addr ;
wire    [15:0]              ram_dout    ;

reg                         init_done   ;
reg                         valid_r;
wire valid_pos;

reg [7:0] cnt_delay;

reg rd_en_dis;

always @(posedge sys_clk) begin
    if(sys_rst)
        valid_r <= 0;
    else
        valid_r <= valid;
end
assign valid_pos = ~valid_r && valid;

//bram数据写入完成
always @(posedge sys_clk) begin
    if(sys_rst)
        init_done <= 0;
    else if(valid_pos)
        init_done <= 1;
end


//延迟计数器生成
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_delay <= 100;
    else if(send_done)
        cnt_delay <= 0;
    else if(cnt_delay == 100)
        cnt_delay <= 100;
    else
        cnt_delay <= cnt_delay + 1;
end

//ram都使能生成
assign ram_rd_en = valid_pos | (cnt_delay == 99 && ram_rd_addr < 256) && (!rd_en_dis);//256次数据读取


//计数到255之后保持在256
always@(posedge sys_clk)begin
    if(sys_rst)begin
        ram_rd_addr <= 0;
        rd_en_dis   <= 0;
    end
        
    else if(ram_rd_en)begin
        if(ram_rd_addr == 255)begin
            ram_rd_addr <= 0;
            rd_en_dis   <= 1;
        end
            
        else
            ram_rd_addr <= ram_rd_addr + 1;
    end
end

//数据发送控制
assign data_in = {ram_rd_addr-1'b1,ram_dout};
always @(posedge sys_clk) begin
    if(sys_rst)
        trig_in <= 0;
    else
        trig_in <= ram_rd_en;
end

bram_out u_bram_out (
  .clka (ram_clk    ),      // input wire clka
  .ena  (ram_en     ),      // input wire ena
  .wea  (ram_wren   ),      // input wire [0 : 0] wea
  .addra(ram_addr   ),      // input wire [7 : 0] addra
  .dina (ram_din    ),      // input wire [15 : 0] dina
  .douta(           ),      // output wire [15 : 0] douta
  .clkb (sys_clk    ),      // input wire clkb
  .enb  (ram_rd_en  ),      // input wire enb
  .web  (0          ),      // input wire [0 : 0] web
  .addrb(ram_rd_addr),      // input wire [7 : 0] addrb
  .dinb (0          ),      // input wire [15 : 0] dinb
  .doutb(ram_dout   )       // output wire [15 : 0] doutb
);


spi_o#
(
    . FRAM_BIT_NUM  (FRAM_BIT_NUM),
    . SYS_HZ        (SYS_HZ      ),
    . SCL_HZ        (SCL_HZ      )
)
u_spi_o(
    . sys_clk    (sys_clk  ) ,
    . sys_rst    (sys_rst  ) ,
    . data_in    (data_in  ) ,
    . trig_in    (trig_in  ) ,
    . cs_n       (cs_n     ) ,
    . scl        (scl      ) ,
    . mosi       (mosi     ) ,
    . send_done  (send_done)
);

endmodule

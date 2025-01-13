`timescale 1ns / 1ps
module bram2spi#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 10_000_000
)(
    input           sys_clk     , 
    input           sys_rst     , 

    input           rama_clk     ,
    input           rama_en      ,
    input  [3:0]    rama_wren    ,
    input  [31:0]   rama_addr    ,
    input  [31:0]   rama_din     ,
    output [31:0]   rama_dout    ,

    input  [31:0] 	app_param0	 ,
    input  [31:0] 	app_param1	 ,
    input  [31:0] 	app_param2	 ,

    output          cs_n        ,
    output          scl         ,
    output          mosi        
);

localparam DELAY_VAULE = 10;
localparam CTRL_REG_OFFSET = 244;
localparam CTRL_REG_MAX = 244 + 5;

wire        valid;
wire [31:0] bean_pos_num;

reg [31:0] 	app_param1_r [1:0];
reg [31:0] 	app_param2_r [1:0];

wire   [FRAM_BIT_NUM-1:0]   data_in     ;
reg    [7:0]                data_addr   ;
reg                         trig_in     ;
wire                        send_done   ;

wire                        ramb_rd_en   ;
reg    [9:0]                ramb_rd_addr ;
wire    [15:0]              ramb_dout    ;

reg                         init_done   ;
reg                         valid_r;
wire valid_pos;

reg [7:0] cnt_delay;

reg rd_en_dis;

reg [9:0] cnt_send_done;

//寄存器打拍寄存
always@(posedge sys_clk)begin
    if(sys_rst)begin
        app_param1_r[0] <= 0;
        app_param1_r[1] <= 0;
        app_param2_r[0] <= 0;
        app_param2_r[1] <= 0;
    end
    else begin
        app_param1_r[0] <= app_param1;
        app_param1_r[1] <= app_param1_r[0];
        app_param2_r[0] <= app_param2;
        app_param2_r[1] <= app_param2_r[0];
    end
end

assign valid = app_param1_r[1][0];
assign bean_pos_num = app_param2_r[1];

//有效信号上升沿生成
always @(posedge sys_clk) begin
    if(sys_rst)
        valid_r <= 0;
    else
        valid_r <= valid;
end
assign valid_pos = ~valid_r && valid;


//延迟计数器生成
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt_delay <= DELAY_VAULE;
    else if(send_done)
        cnt_delay <= 0;
    else if(cnt_delay == DELAY_VAULE)
        cnt_delay <= DELAY_VAULE;
    else
        cnt_delay <= cnt_delay + 1;
end



//ram都使能生成
assign ramb_rd_en = valid_pos | (cnt_delay == DELAY_VAULE - 1 && (ramb_rd_addr >= 1 && ramb_rd_addr <= CTRL_REG_MAX));


//计数到255之后保持在256
always@(posedge sys_clk)begin
    if(sys_rst)
        ramb_rd_addr <= 0;
    else if(ramb_rd_en)begin
        if(ramb_rd_addr == (bean_pos_num << 1) - 1)
            ramb_rd_addr <= CTRL_REG_OFFSET;
        else if(ramb_rd_addr == CTRL_REG_MAX)//note that there no need to minus 1
            ramb_rd_addr <= 0;
        else
            ramb_rd_addr <= ramb_rd_addr + 1;
    end
end

//读地址打拍作为spi的地址
always@(posedge sys_clk)begin
    if(sys_rst)
        data_addr <= 0;
    else 
        data_addr <= ramb_rd_addr;
end

//数据发送控制
assign data_in = {data_addr,ramb_dout};
always @(posedge sys_clk) begin
    if(sys_rst)
        trig_in <= 0;
    else
        trig_in <= ramb_rd_en;
end

bram_out u_bram_out (
  .clka (rama_clk    ),      // input wire clka
  .ena  (rama_en     ),      // input wire ena
  .wea  (rama_wren[0]),      // input wire [3 : 0] wea
  .addra(rama_addr >> 2),      // input wire [31] : 0] addra
  .dina (rama_din    ),      // input wire [31 : 0] dina
  .douta(rama_dout   ),      // output wire [31 : 0] douta
  .clkb (sys_clk    ),      // input wire clkb
  .enb  (ramb_rd_en  ),      // input wire enb
  .web  (0          ),      // input wire [0 : 0] web
  .addrb(ramb_rd_addr),      // input wire [7 : 0] addrb
  .dinb (0          ),      // input wire [15 : 0] dinb
  .doutb(ramb_dout   )       // output wire [15 : 0] doutb
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

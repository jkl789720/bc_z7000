`timescale 1ns / 1ps
module tb_b2b_intfce#(    
parameter FRAM_BIT_NUM  = 24        ,
parameter SYS_HZ        = 50_000_000,
parameter SCL_HZ        = 10_000_000
)
();

localparam CTRL_REG_OFFSET = 122;//32bit
localparam CTRL_REG_MAX = 122 + 2;//32bit
localparam TOTAL_NUM = 128;

reg            sys_clk         ;
reg            sys_rst           ;

//
wire           ram_out_clk     ;
wire           ram_out_en      ;
reg  [3:0]     ram_out_wren    ;
wire [31:0]    ram_out_addr    ;
wire [31:0]    ram_out_din     ;

wire  [31:0] 	app_param0	 ;
wire  [31:0] 	app_param1	 ;
wire  [31:0] 	app_param2	 ;



wire            cs_n           ;
wire            scl            ;
wire            mosi           ;

//
wire        ram_clk ;
wire        ram_en  ;
wire        ram_wren;
wire [7:0]  ram_addr;
wire [15:0] ram_din ;
wire [15:0] douta;


reg             valid          ;
wire [31:0]     beam_pos_num   ;//需要发送的波位数


reg [31:0] cnt_send_data;

assign beam_pos_num = 2; 
assign app_param2 = beam_pos_num;
assign app_param1 = {31'b0,valid};


initial begin
    sys_clk = 0;
    sys_rst   = 1;
    #100
    sys_rst   = 0;
end

always # 10 sys_clk = ~sys_clk;

assign ram_out_clk = sys_clk;
assign ram_out_en   = 1;
assign ram_out_din  = 32'h5555_5555;

//write enable
always @(posedge sys_clk) begin
    if(sys_rst)
        ram_out_wren <= 4'hf;
    else if(ram_out_wren && ram_out_addr == CTRL_REG_MAX * 4)
        ram_out_wren <= 0;
end

//write count
always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_send_data <= 0;
    else if(ram_out_wren)begin
        if(cnt_send_data == beam_pos_num - 1)
            cnt_send_data <= CTRL_REG_OFFSET;
        else if(cnt_send_data == CTRL_REG_MAX)
            cnt_send_data <= 0;
        else
            cnt_send_data <= cnt_send_data + 1;
    end
end

assign ram_out_addr = cnt_send_data << 2;


//valid signal generation
always@(posedge sys_clk)begin
    if(sys_rst)
        valid <= 0;
    else if(ram_out_wren && ram_out_addr == CTRL_REG_MAX * 4)
        valid <= 1;
    else
        valid <= 0;
end

bram2spi#
(
    . FRAM_BIT_NUM  (FRAM_BIT_NUM),
    . SYS_HZ        (SYS_HZ      ),
    . SCL_HZ        (SCL_HZ      )
)
u_bram2spi(
    . sys_clk    (sys_clk        )  , 
    . sys_rst    (sys_rst        )  , 
    . rama_clk   (ram_out_clk    )  ,
    . rama_en    (ram_out_en     )  ,
    . rama_wren  (ram_out_wren   )  ,
    . rama_addr  (ram_out_addr   )  ,
    . rama_din   (ram_out_din    )  ,
    . rama_dout  (ram_dout       )  ,
    . app_param0 (app_param0     )  ,
    . app_param1 (app_param1     )  ,
    . app_param2 (app_param2     )  ,
    . cs_n       (cs_n           )  ,
    . scl        (scl            )  ,
    . mosi       (mosi           )  
);

spi2bram#
(
    . FRAM_BIT_NUM (FRAM_BIT_NUM)
)
u_spi2bram(
    .  sys_clk   (sys_clk ) ,
    .  sys_rst   (sys_rst ) ,
    .  cs_n      (cs_n    ) ,
    .  scl       (scl     ) ,
    .  mosi      (mosi    ) ,
    .  ram_clk   (ram_clk ) ,
    .  ram_en    (ram_en  ) ,
    .  ram_wren  (ram_wren) ,
    .  ram_addr  (ram_addr) ,
    .  ram_din   (ram_din ) 
);


bram_in u_bram_in (
  .clka     (ram_clk   ) ,      // input wire clka
  .ena      (ram_en    ) ,      // input wire ena
  .wea      (ram_wren  ) ,      // input wire [0 : 0] wea
  .addra    (ram_addr  ) ,      // input wire [7 : 0] addra
  .dina     (ram_din   ) ,      // input wire [15 : 0] dina
  .douta    (douta     ) ,      // output wire [15 : 0] douta
  .clkb     (clkb      ) ,      // input wire clkb
  .enb      (enb       ) ,      // input wire enb
  .web      (web       ) ,      // input wire [0 : 0] web
  .addrb    (addrb     ) ,      // input wire [6 : 0] addrb
  .dinb     (dinb      ) ,      // input wire [31 : 0] dinb
  .doutb    (doutb     )        // output wire [31 : 0] doutb
);


endmodule

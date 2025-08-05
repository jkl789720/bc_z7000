`timescale 1ns / 1ps
module test_master#
(
    parameter FRAM_BIT_NUM  = 24        ,
    parameter SYS_HZ        = 50_000_000,
    parameter SCL_HZ        = 1_000_000 ,
    parameter SPI_CHANNEL      = 8,
    parameter SPI_LANE      = 4
    )(
    input                           sys_clk     ,
    input                           sys_rst     ,

    input                	        rama_clk    ,
	input                           rama_en     ,
	input   [3 : 0]                 rama_we     ,
	input   [31 : 0]                rama_addr   ,
	input   [31 : 0]                rama_din    ,
	output  [31 : 0]                rama_dout   ,
	input                           rama_rst    ,

    input                           clka_check    ,
    input                           ena_check     ,
    input   [3 : 0]                 wea_check     ,
    input   [31 : 0]                addra_check   ,
    input   [31 : 0]                dina_check    ,
    output  [31 : 0]                douta_check   ,
    input                           rama_rst_check,

    input   [31 : 0]                app_param1  ,

    output       [SPI_CHANNEL - 1: 0]  cs_n        ,
    output       [SPI_CHANNEL - 1: 0]  scl         ,
    output       [SPI_CHANNEL - 1: 0]  mosi        ,
    output       [SPI_CHANNEL - 1:0]   send_done

);

reg valid_r;
wire valid_pos;
reg [FRAM_BIT_NUM - 1:0] data_in[SPI_CHANNEL - 1:0];
reg trig_in_pre;
reg trig_in;


reg [$clog2(SPI_CHANNEL)-1:0] cnt;
reg add_cnt;
wire end_cnt;


wire rd_en;
wire [31:0] rd_addr;
wire [127:0] rd_data;

reg rd_en_r;
reg [$clog2(SPI_CHANNEL)-1:0] rd_addr_r;
wire valid;

reg [31:0] app_param1_r [1:0];

wire        bram_clk    ;
wire        bram_we     ;
wire [31:0] bram_addr   ;
wire [31:0] bram_data   ;


//寄存寄存器
always@(posedge sys_clk)begin
    if(sys_rst)begin
        app_param1_r[0] <= 0;
        app_param1_r[1] <= 0;
    end
    else begin
        app_param1_r[0] <= app_param1;
        app_param1_r[1] <= app_param1_r[0];
    end
end

assign valid = app_param1_r[1][0];//打拍
//--------------------检测valid上升沿----------------//
always@(posedge sys_clk)begin
    if(sys_rst)
        valid_r <= 0;
    else
        valid_r = valid;
end
assign valid_pos = !valid_r && valid;

//---生成计数器
always@(posedge sys_clk)begin
    if(sys_rst)
        add_cnt <= 0;
    else if(valid_pos)
        add_cnt <= 1;
    else if(end_cnt)
        add_cnt <= 0;
end
assign end_cnt = add_cnt && cnt == SPI_CHANNEL - 1;
always@(posedge sys_clk)begin
    if(sys_rst)
        cnt <= 0;
    else if(add_cnt)begin
        if(end_cnt)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end
end

assign rd_en = add_cnt;
assign rd_addr = cnt;


//--打拍和rd_data同步
always@(posedge sys_clk)begin
    if(sys_rst)begin
        rd_en_r     <= 0;
        rd_addr_r   <= 0;
    end
    else begin
        rd_en_r     <= rd_en;
        rd_addr_r   <= rd_addr;
    end
end

always@(posedge sys_clk)begin
    if(sys_rst)begin
        trig_in_pre <= 0;
        trig_in     <= 0;
    end
        
    else begin
        trig_in_pre <= end_cnt;
        trig_in     <= trig_in_pre;
    end
end

integer i;
always@(posedge sys_clk)begin
    if(sys_rst)begin
        for(i = 0;i< SPI_CHANNEL;i = i + 1)
            data_in[i] <= 0;
    end
    else if(rd_en_r)
        data_in[rd_addr_r] <= rd_data;
end


bram_mimo_debug u_bram_mimo_debug (
  .clka(rama_clk),    // input wire clka
  .ena(rama_en),      // input wire ena
  .wea(rama_we[0]),      // input wire [0 : 0] wea
  .addra(rama_addr >> 2),  // input wire [6 : 0] addra
  .dina(rama_din),    // input wire [31 : 0] dina
  .douta(rama_dout),  // output wire [31 : 0] douta
  .clkb(sys_clk),    // input wire clkb
  .enb(rd_en),      // input wire enb
  .web(0),      // input wire [0 : 0] web
  .addrb(rd_addr),  // input wire [6 : 0] addrb
  .dinb(0),    // input wire [31 : 0] dinb
  .doutb(rd_data)  // output wire [31 : 0] doutb
);

genvar cc;
generate
    for(cc = 0;cc < SPI_CHANNEL;cc = cc + 1)begin:gen_spi_o
        spi_o#
        (
            . FRAM_BIT_NUM (FRAM_BIT_NUM),
            . SYS_HZ       (SYS_HZ      ),
            . SCL_HZ       (SCL_HZ      )
        )u_spi_o(
            .  sys_clk    (sys_clk  )   ,
            .  sys_rst    (sys_rst  )   ,
            .  data_in    (data_in[cc]  )   ,//
            .  trig_in    (trig_in  )   ,
            .  cs_n       (cs_n[cc]     )   ,//
            .  scl        (scl[cc]      )   ,//
            .  mosi       (mosi[cc]     )   ,//
            .  send_done  (send_done[cc])    //
        );
    end
endgenerate

// //----回环
//  bram_bc_code_spi u_bram_bc_code_spi (
//   .clka (clka_check             ),// input  wire clka
//   .ena  (ena_check              ),// input  wire ena
//   .wea  (wea_check              ),// input  wire [0 : 0] wea
//   .addra(addra_check >> 2       ),// input  wire [10 : 0] addra
//   .dina (dina_check             ),// input  wire [31 : 0] dina
//   .douta(douta_check            ),// output wire [31 : 0] douta
//   .clkb (bram_clk         ),// input wire clkb
//   .enb  (1                ),// input wire enb
//   .web  (bram_we          ),// input wire [0 : 0] web
//   .addrb(bram_addr        ),// input wire [10 : 0] addrb
//   .dinb (bram_data        ),// input wire [31 : 0] dinb
//   .doutb(                 ) // output wire [31 : 0] doutb
// );

// test_slave#
// (
//     . FRAM_BIT_NUM (FRAM_BIT_NUM),
//     . SYS_HZ       (SYS_HZ      ),
//     . SCL_HZ       (SCL_HZ      ),
//     . SPI_CHANNEL     (SPI_CHANNEL    ),
//     . SPI_LANE     (SPI_LANE    )
// )u_test_slave(
//     .  sys_clk      (sys_clk     ),
//     .  sys_rst      (sys_rst     ),
//     .  cs_n         (cs_n        ),
//     .  scl          (scl         ),
//     .  mosi         (mosi        ),
//     .  bram_clk     (bram_clk    ),
//     .  bram_we      (bram_we     ),
//     .  bram_addr    (bram_addr   ),
//     .  bram_data    (bram_data   ),
//     .  bram_wr_done (bram_wr_done)
// );

endmodule

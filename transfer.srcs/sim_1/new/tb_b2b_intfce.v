`timescale 1ns / 1ps
module tb_b2b_intfce#(    
parameter FRAM_BIT_NUM  = 24        ,
parameter SYS_HZ        = 50_000_000,
parameter SCL_HZ        = 10_000_000
)
();

localparam BEAM_POS_NUM = 16;
localparam BEAM_POS_REG_NUM = 4;
localparam BEAM_POS_REG_TOTAL_NUM  = BEAM_POS_NUM * BEAM_POS_REG_NUM;
localparam CTRL_REG_BASE_ADDR = 32'H1E8;//32bit
localparam CTRL_REG_HIGH_ADDR = 32'H1EC;//32bit

reg            sys_clk         ;
reg            sys_rst           ;

//
wire           ram_out_clk     ;
wire           ram_out_en      ;
reg  [3:0]     ram_out_wren    ;
reg [31:0]     ram_out_addr    ;
wire [31:0]    ram_out_din     ;

wire  [31:0] 	app_param0	 ;
wire  [31:0] 	app_param1	 ;
wire  [31:0] 	app_param2	 ;



wire            cs_n           ;
wire            scl            ;
wire            mosi           ;

wire            ram_rfsoc_clk  ;
wire            ram_rfsoc_en   ; 
wire            ram_rfsoc_wren ;
wire [7:0]      ram_rfsoc_addr ;
wire [15:0]     ram_rfsoc_din  ;

wire bc_data_done;


reg             valid          ;
wire [31:0]     beam_pos_num   ;//需要发送的波位数



assign beam_pos_num = BEAM_POS_NUM; 
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
    else if(ram_out_wren && ram_out_addr == CTRL_REG_HIGH_ADDR)
        ram_out_wren <= 0;
end

//write count
always @(posedge sys_clk) begin
    if(sys_rst)
        ram_out_addr <= 0;
    else if(ram_out_wren)begin
        if(ram_out_addr == (BEAM_POS_REG_TOTAL_NUM - 1) * 4)
            ram_out_addr <= CTRL_REG_BASE_ADDR;
        else if(ram_out_addr == CTRL_REG_HIGH_ADDR)
            ram_out_addr <= 0;
        else
            ram_out_addr <= ram_out_addr + 4;
    end
end



//valid signal generation
always@(posedge sys_clk)begin
    if(sys_rst)
        valid <= 0;
    else if(ram_out_wren && ram_out_addr == CTRL_REG_HIGH_ADDR)
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
    . sys_clk               (sys_clk        )  , 
    . sys_rst               (sys_rst        )  , 
    . rama_clk              (ram_out_clk    )  ,
    . rama_en               (ram_out_en     )  ,
    . rama_wren             (ram_out_wren   )  ,
    . rama_addr             (ram_out_addr   )  ,
    . rama_din              (ram_out_din    )  ,
    . rama_dout             (ram_dout       )  ,
    . app_param0            (app_param0     )  ,
    . app_param1            (app_param1     )  ,
    . app_param2            (app_param2     )  ,
    . cs_n                  (cs_n           )  ,
    . scl                   (scl            )  ,
    . mosi                  (mosi           )  ,     
    . bc_data_done          (bc_data_done   )  
);

rfsoc_2z7000 u_rfsoc_2z7000(
.   sys_clk        (sys_clk       ) ,
.   sys_rst        (sys_rst       ) ,
.   cs_n           (cs_n          ) ,
.   scl            (scl           ) ,
.   mosi           (mosi          ) ,
.   bc_data_done   (bc_data_done  ) ,
.   ram_rfsoc_clk  (ram_rfsoc_clk ) ,
.   ram_rfsoc_en   (ram_rfsoc_en  ) ,
.   ram_rfsoc_wren (ram_rfsoc_wren) ,
.   ram_rfsoc_addr (ram_rfsoc_addr) ,
.   ram_rfsoc_din  (ram_rfsoc_din )

);


bram_in u_bram_in (
  .clka     (ram_rfsoc_clk  ) ,      // input wire clka
  .ena      (ram_rfsoc_en   ) ,      // input wire ena
  .wea      (ram_rfsoc_wren ) ,      // input wire [0 : 0] wea
  .addra    (ram_rfsoc_addr ) ,      // input wire [7 : 0] addra
  .dina     (ram_rfsoc_din  ) ,      // input wire [15 : 0] dina
  .douta    (douta          ) ,      // output wire [15 : 0] douta
  .clkb     (clkb           ) ,      // input wire clkb
  .enb      (enb            ) ,      // input wire enb
  .web      (web            ) ,      // input wire [0 : 0] web
  .addrb    (addrb          ) ,      // input wire [6 : 0] addrb
  .dinb     (dinb           ) ,      // input wire [31 : 0] dinb
  .doutb    (doutb          )        // output wire [31 : 0] doutb
);


endmodule

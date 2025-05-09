`include "configure.vh"
`timescale 1ns / 1ps
module init_fsm#(
    parameter SYSHZ             = 50_000_000        ,
    parameter SCLHZ             = 10_000_000        ,
    parameter INIT_REG_NUM      = 16
)(
    input                       sys_clk             ,
    input                       sys_rst             ,

    input                       init_start          ,
    input                       init_read_req       ,//加入顶层

    input                       ram_bc_init_clk        ,
    input                       ram_bc_init_en         ,
    input [3:0]                 ram_bc_init_we         ,
    input [31:0]                ram_bc_init_addr       ,
    input [31:0]                ram_bc_init_din        ,
    output[31:0]                ram_bc_init_dout       ,
    output                      ram_bc_init_rst        ,

    input                       ram_bc_init_clk_back        ,//加入顶层
    input                       ram_bc_init_en_back         ,
    input [3:0]                 ram_bc_init_we_back         ,
    input [31:0]                ram_bc_init_addr_back       ,
    input [31:0]                ram_bc_init_din_back        ,
    output[31:0]                ram_bc_init_dout_back       ,
    output                      ram_bc_init_rst_back        ,

    output reg [7:0]            chip_reset          ,
    output reg [7:0]            cs_n                ,
    output reg [7:0]            sclk                ,
    input  [7:0]                miso                ,
    output reg [31:0]           mosi                ,

    output reg                  init_done   
);

localparam TIME_1200NS          = (SYSHZ * 12) / 10_000_000;//60
localparam  TIME_3000NS         = (SYSHZ * 30) / 10_000_000;//150
localparam  CYCLE               = SYSHZ / SCLHZ ;//5
localparam  CYCLE_MID           = CYCLE/2;//2
localparam  EFUSE_START_BIT     = 8 ;//8
localparam  EFUSE_INT_BIT       = TIME_3000NS/CYCLE;//30
localparam  EFUSE_END_BIT       = 10 ;//
localparam  EFUSE_TOTAL_BIT     = EFUSE_START_BIT + EFUSE_INT_BIT+ EFUSE_END_BIT;//48
localparam  DELAY_VALUE         = TIME_1200NS;
localparam  GROUP_NUM           = 8;


//-------------状态切换相关变量------------------//
wire Chip_reset_Done,Efuse_reset_Done,Bc2spi_Done,
        Spi_init_Done,Read_Done,Spi2bc_Done,Delay_Done;
reg [31:0] cnt_chip_reset,cnt_cycle;
reg [7:0]  cnt_bit;
reg [4:0] cstate,nstate;

reg  wr_en_init   ;
reg [27:0] wr_data_init ;
wire  cs_n_init     ;
wire  sclk_init    ;
wire  mosi_init    ;
wire  wr_done_init ;
reg [5:0] wr_done_init_r;

reg wr_en_mode   ;
reg [2:0] wr_data_mode ;
wire cs_n_mode    ;
wire sclk_mode    ;
wire mosi_mode    ;
wire wr_done_mode ;

reg [7:0] cnt_init;
reg [$clog2(TIME_1200NS)-1:0] cnt_delay;
reg [31:0] usr_init_ram_addr;
wire [31:0] usr_init_ram_data;
reg [2:0] init_start_r;
wire init_start_pos;
wire [23:0] recv_data ;

reg [31:0] usr_init_addr_back;
reg [31:0] usr_init_addr_back_pre;
reg [0:0] usr_init_en_back  ;
reg [0:0] usr_init_we_back  ;
reg [31:0] usr_init_din_back ;

reg miso_vld;

reg trig;

reg wr_back_flag;


localparam IDLE          = 0    ;
localparam DELAY0        = 1    ;
localparam CHIP_RESET    = 2    ;
localparam DELAY1        = 3    ;
localparam EFUSE_RESET   = 4    ;
localparam DELAY2        = 5    ;
localparam BC2SPI        = 6    ;
localparam DELAY3        = 7    ;
localparam SPI_INIT      = 8    ;
localparam DELAY4        = 9    ;
localparam READ          = 10   ;
localparam DELAY5        = 11   ;
localparam SPI2BC        = 12   ;
localparam DELAY6        = 13   ;
localparam DONE          = 14   ;


//初始化ram读地址生成
always@(*)begin
    if(sys_rst)
        usr_init_ram_addr = 0;
    if(cstate == SPI_INIT)
        usr_init_ram_addr = cnt_init;
    else if(cstate == READ)begin
        if(cnt_init <= 16)
            usr_init_ram_addr = cnt_init;
        else if(cnt_init <= 33)
            usr_init_ram_addr = cnt_init - 1;
        else if(cnt_init <= 50)
            usr_init_ram_addr = cnt_init - 2;
        else if(cnt_init <= 67)
            usr_init_ram_addr = cnt_init - 3;
        else if(cnt_init <= 84)
            usr_init_ram_addr = cnt_init - 4;
        else if(cnt_init <= 101)
            usr_init_ram_addr = cnt_init - 5;
        else if(cnt_init <= 118)
            usr_init_ram_addr = cnt_init - 6;
        else
            usr_init_ram_addr = cnt_init - 7;
    end
    else
        usr_init_ram_addr = 0;
end


//初始化ram读地址生成
always@(*)begin
    if(sys_rst)
        wr_back_flag = 0;
    else if(cnt_init >= 1 && cnt_init <= 16)
        wr_back_flag = 1;
    else if(cnt_init >= 18 && cnt_init <= 33)
        wr_back_flag = 1;
    else if(cnt_init >= 35 && cnt_init <= 50)
        wr_back_flag = 1;
    else if(cnt_init >= 52 && cnt_init <= 67)
        wr_back_flag = 1;
    else if(cnt_init >= 69 && cnt_init <= 84)
        wr_back_flag = 1;
    else if(cnt_init >= 86 && cnt_init <= 101)
        wr_back_flag = 1;
    else if(cnt_init >= 103 && cnt_init <= 118)
        wr_back_flag = 1;
    else if(cnt_init >= 120 && cnt_init <= 135)
        wr_back_flag = 1;
    else
        wr_back_flag = 0;
end


assign Chip_reset_Done = cnt_chip_reset == TIME_1200NS - 1;
assign Efuse_reset_Done = cnt_cycle == CYCLE - 1 && cnt_bit == EFUSE_TOTAL_BIT - 1;
assign Bc2spi_Done = wr_done_mode;
assign Spi_init_Done = wr_done_init && cnt_init == (INIT_REG_NUM*GROUP_NUM) - 1;//8个都一样，用一个就行
assign Read_Done = wr_done_init && cnt_init == (INIT_REG_NUM + 1) * GROUP_NUM - 1;//，目前只能读一个"半阵"；读指令需要多发一个周期
assign Spi2bc_Done = wr_done_mode;
assign Delay_Done = cnt_delay == DELAY_VALUE - 1;
always@(posedge sys_clk) init_start_r <= {init_start_r[1:0],init_start};
// assign init_start_pos = ~init_start_r[2] && init_start_r[1];//注debug
assign init_start_pos = 1;//注debug

always @(posedge sys_clk) begin
    if(sys_rst) begin
        cstate <= IDLE;
    end else begin
        cstate <= nstate;
    end
end

// 统一状态转移逻辑
always @(*) begin
    case (cstate)
        IDLE:        nstate     =   init_start_pos     ? DELAY0                             : cstate; // 保持IDLE直到触发
        DELAY0:      nstate     =   (Delay_Done)       ? CHIP_RESET                         : cstate; 
        CHIP_RESET:  nstate     =   Chip_reset_Done    ? DELAY1                             : cstate;
        DELAY1:      nstate     =   (Delay_Done)       ? EFUSE_RESET                        : cstate; 
        EFUSE_RESET: nstate     =   Efuse_reset_Done   ? DELAY2                             : cstate;
        DELAY2:      nstate     =   (Delay_Done)       ? BC2SPI                             : cstate;
        BC2SPI:      nstate     =   Bc2spi_Done        ? DELAY3                             : cstate;
        DELAY3:      nstate     =   (Delay_Done)       ? SPI_INIT                           : cstate;
        SPI_INIT:    nstate     =   Spi_init_Done      ? DELAY4                             : cstate;
        DELAY4:      nstate     =   (Delay_Done)       ? (init_read_req ? READ : SPI2BC)    : cstate;
        READ:        nstate     =   Read_Done          ? DELAY5                             : cstate;//回读初始化值
        DELAY5:      nstate     =   (Delay_Done)       ? SPI2BC                             : cstate;
        SPI2BC:      nstate     =   Spi2bc_Done        ? DELAY6                             : cstate;
        DELAY6:      nstate     =   (Delay_Done)       ? DONE                               : cstate;
        DONE: begin
            nstate = DONE; // 最终状态锁定
        end
        default: nstate = IDLE; // 容错处理
    endcase
end

integer cc;
always @(posedge sys_clk) begin
    if(sys_rst)begin
        cnt_chip_reset <= 0;
        cnt_cycle      <= 0;
        cnt_bit        <= 0;
        chip_reset     <= 0;
        wr_data_mode   <= 0;
        wr_en_mode     <= 0;
        
        wr_en_init     <= 0;
        cnt_init       <= 0;
        wr_done_init_r <= 0;
        cnt_delay      <= 0;

        wr_data_init[0] <= 0;
        miso_vld        <= 0;

        usr_init_addr_back <= 0;
        usr_init_addr_back_pre <= 0;
        usr_init_en_back   <= 0;
        usr_init_we_back   <= 0;
        usr_init_din_back  <= 0;

        trig        <= 0;

        cs_n           <= 8'hff;
        sclk           <= 0;
        mosi           <= 0;
        init_done      <= 0;
    end
    else begin
        case (cstate)
            IDLE:begin
                cnt_chip_reset <= 0;
                cnt_cycle      <= 0;
                cnt_bit        <= 0;
                chip_reset     <= 0;
                wr_data_mode   <= 0;
                wr_en_mode     <= 0;
                wr_en_init     <= 0;
                cnt_init       <= 0;
                wr_done_init_r <= 0;
                cnt_delay      <= 0;

                wr_data_init[0] <= 0;
                miso_vld        <= 0;
                usr_init_addr_back <= 0;
                usr_init_addr_back_pre <= 0;
                usr_init_en_back   <= 0;
                usr_init_we_back   <= 0;
                usr_init_din_back  <= 0;

                trig        <= 0;

                cs_n           <= 8'hff;
                sclk           <= 0;
                mosi           <= 0;
                init_done      <= 0;
            end
            CHIP_RESET:begin
                if(Chip_reset_Done)begin
                    cnt_chip_reset <= 0;
                    chip_reset     <= 0;
                end
                else begin
                    cnt_chip_reset <=  cnt_chip_reset + 1;  
                    chip_reset     <= 8'hff;
                end
            end
            EFUSE_RESET:begin
                //-----------------last_state-----------------//
                
                //-----------------cur_state---------------//
                //cnt_cycle_generate
                if(cnt_cycle == CYCLE - 1)
                    cnt_cycle      <= 0;
                else
                    cnt_cycle      <= cnt_cycle + 1;
                //cnt_bit_generate
                if(cnt_cycle == CYCLE - 1)begin
                    if(cnt_bit == EFUSE_TOTAL_BIT - 1)
                        cnt_bit <= 0;
                    else 
                        cnt_bit <= cnt_bit + 1;
                end
                //cs_generate
                    if(cnt_cycle == 0 && (cnt_bit == 0 | (cnt_bit == EFUSE_TOTAL_BIT -EFUSE_END_BIT)))//38
                        cs_n <= 0;
                    else if(cnt_cycle == CYCLE - 1  && (cnt_bit == EFUSE_START_BIT - 1 | (cnt_bit == EFUSE_TOTAL_BIT - 1)))//cnt能否到EFUSE_BIT？仿真确认
                        cs_n <= 8'hff;
                    else
                        cs_n <= cs_n;
                
                //sclk_generate
                if((cnt_bit > 0 && cnt_bit < EFUSE_START_BIT - 1) | (cnt_bit > EFUSE_START_BIT + EFUSE_INT_BIT && cnt_bit < EFUSE_TOTAL_BIT - 1))begin//1-6 39-46
                    if(cnt_cycle == 0)
                        sclk <= 0;
                    else if(cnt_cycle == CYCLE_MID)
                        sclk <= 8'hff;
                end
                else
                    sclk <= 0;
            end
            BC2SPI,SPI2BC:begin
                //-----------------cur_state-----------------//
                wr_en_mode <= Bc2spi_Done | Spi2bc_Done  ? 0 : 1;
                wr_data_mode <= 0;

                cs_n <= {8{cs_n_mode}};
                sclk <= {8{sclk_mode}};
                mosi <= 0;
            end
            SPI_INIT:begin
                //-----------------cur_state-----------------//
                trig <= 1;
                if(wr_done_init)begin
                    if(Spi_init_Done)
                        cnt_init <= 0;
                    else
                        cnt_init <= cnt_init + 1;
                end
                wr_done_init_r <= Spi_init_Done ? 0 : {wr_done_init_r[5:0],wr_done_init};
                //----------spi模块信息输入-----------//
                wr_en_init <= wr_done_init_r[5] | (trig == 0);
                wr_data_init <= {4'b0100,usr_init_ram_data[23:0]};
                // wr_data_init <= {4'b0100,24'h555555};
                //----------spi接口赋值-----------//
                if(cnt_init <= 15)begin//第一组
                    mosi[3:0] <= {4{mosi_init}};
                    cs_n[0] <= cs_n_init;
                    sclk[0] <= sclk_init;
                end
                else if(cnt_init <= 31)begin//第二组
                    mosi[7:4] <= {4{mosi_init}};
                    cs_n[1] <= cs_n_init;
                    sclk[1] <= sclk_init;
                end
                else if(cnt_init <= 47)begin//第三组
                    mosi[11:8] <= {4{mosi_init}};
                    cs_n[2] <= cs_n_init;
                    sclk[2] <= sclk_init;
                end
                else if(cnt_init <= 63)begin//第四组
                    mosi[15:12] <= {4{mosi_init}};
                    cs_n[3] <= cs_n_init;
                    sclk[3] <= sclk_init;
                end
                else if(cnt_init <= 79)begin//第五组
                    mosi[19:16] <= {4{mosi_init}};
                    cs_n[4] <= cs_n_init;
                    sclk[4] <= sclk_init;
                end
                else if(cnt_init <= 95)begin//第六组
                    mosi[23:20] <= {4{mosi_init}};
                    cs_n[5] <= cs_n_init;
                    sclk[5] <= sclk_init;
                end
                else if(cnt_init <= 111)begin//第七组
                    mosi[27:24] <= {4{mosi_init}};
                    cs_n[6] <= cs_n_init;
                    sclk[6] <= sclk_init;
                end
                else begin//第八组
                    mosi[31:28] <= {4{mosi_init}};
                    cs_n[7] <= cs_n_init;
                    sclk[7] <= sclk_init;
                end
                
            end
            READ:begin
                trig        <= 1;
                if(wr_done_init)begin
                    if(Read_Done)
                        cnt_init <= 0;
                    else
                        cnt_init <= cnt_init + 1;
                end
                wr_done_init_r <= {wr_done_init_r[5:0],wr_done_init};
                //----------spi模块信息输入-----------//
                wr_en_init <= wr_done_init_r[5] | (trig == 0);
                wr_data_init <= {4'b0110,usr_init_ram_data[23:0]};
                
                /*
              cnt_init          组      RAM地址         
                0-16            G1      0-16            
                17-33           G2      16-32           
                34-50           G3      32-48           
                51-67           G4      48-64           
                68-84           G5      64-80           
                85-101          G6      80-96           
                102-118         G7      96-112          
                119-135         G8      112-128(0)      
                */
                // wr_data_init <= {4'b0100,24'h555555};
                //----------spi接口赋值-----------//
                if(cnt_init <= 16)begin//第一组
                    mosi[3:0] <= {4{mosi_init}};
                    cs_n[0] <= cs_n_init;
                    sclk[0] <= sclk_init;
                end
                else if(cnt_init <= 33)begin//第二组
                    mosi[7:4] <= {4{mosi_init}};
                    cs_n[1] <= cs_n_init;
                    sclk[1] <= sclk_init;
                end
                else if(cnt_init <= 50)begin//第三组
                    mosi[11:8] <= {4{mosi_init}};
                    cs_n[2] <= cs_n_init;
                    sclk[2] <= sclk_init;
                end
                else if(cnt_init <= 67)begin//第四组
                    mosi[15:12] <= {4{mosi_init}};
                    cs_n[3] <= cs_n_init;
                    sclk[3] <= sclk_init;
                end
                else if(cnt_init <= 84)begin//第五组
                    mosi[19:16] <= {4{mosi_init}};
                    cs_n[4] <= cs_n_init;
                    sclk[4] <= sclk_init;
                end
                else if(cnt_init <= 101)begin//第六组
                    mosi[23:20] <= {4{mosi_init}};
                    cs_n[5] <= cs_n_init;
                    sclk[5] <= sclk_init;
                end
                else if(cnt_init <= 118)begin//第七组
                    mosi[27:24] <= {4{mosi_init}};
                    cs_n[6] <= cs_n_init;
                    sclk[6] <= sclk_init;
                end
                else begin//第八组 
                    mosi[31:28] <= {4{mosi_init}};
                    cs_n[7] <= cs_n_init;
                    sclk[7] <= sclk_init;
                end

                //------------回读数据源切换-------------//
                //注design:这段逻辑在仿真的时候没测试，因此上板需要针对性测试，如果能仿真测试更好
                if(cnt_init <= 16)//第一组
                    miso_vld <= miso[0];
                else if(cnt_init <= 33)//第二组
                    miso_vld <= miso[1];
                else if(cnt_init <= 50)//第二组
                    miso_vld <= miso[2];
                else if(cnt_init <= 67)//第二组
                    miso_vld <= miso[3];
                else if(cnt_init <= 84)//第二组
                    miso_vld <= miso[4];
                else if(cnt_init <= 101)//第二组
                    miso_vld <= miso[5];
                else if(cnt_init <= 118)//第二组
                    miso_vld <= miso[6];
                else
                    miso_vld <= miso[7];
                //------------写入BRAM------------//
                usr_init_en_back     <= 1;
                usr_init_we_back     <= wr_done_init && wr_back_flag;//标记回读数据有效阶段，即addr:1-16 17-32 33-48 49-64 65-80 81-96 97-112 113-128 
                usr_init_addr_back   <= usr_init_ram_addr - 1 ;//减去1才是回写地址
                usr_init_din_back    <=  recv_data;//注:寄存器地址需要寄存
            end
            DONE:begin
                //-----------------cur_state-----------------//
                init_done <= 1;
            end
            DELAY0,DELAY1,DELAY2,DELAY3,DELAY4,DELAY5,DELAY6:begin
                //-----------------last_state-----------------//
                usr_init_en_back     <= 0;
                usr_init_we_back     <= 0;
                usr_init_addr_back   <= 0;
                usr_init_din_back    <= 0;
                trig <= 0;
                //-----------------cur_state-----------------//;
                if(cnt_delay == DELAY_VALUE - 1)
                    cnt_delay <= 0;
                else
                    cnt_delay <= cnt_delay + 1;

                cs_n <= 8'hff;
                sclk <= 0;
                mosi <= 0;
                // chip_reset <= 0;
            end
            default:begin
                cnt_chip_reset <= 0;
                cnt_cycle      <= 0;
                cnt_bit        <= 0;
                chip_reset     <= 0;
                wr_data_mode   <= 0;
                wr_en_mode     <= 0;
                wr_en_init     <= 0;
                cnt_init       <= 0;
                wr_done_init_r <= 0;
                cnt_delay      <= 0;

                cs_n           <= 8'hff;
                sclk           <= 0;
                mosi           <= 0;
                for(cc=0;cc<8;cc=cc+1)
                    wr_data_init[cc] <= 0;
            end
            
        endcase
    end
end

spi_wrp#(
    . SYSHZ         (SYSHZ     ) ,
    . SCLHZ         (SCLHZ     ) ,
    . DATA_WIDTH    (28) 
)u_spi_wrp_init(
    . sys_clk   (sys_clk        ) ,
    . sys_rst   (sys_rst        ) ,
    . wr_en     (wr_en_init     ) ,
    . wr_data   (wr_data_init   ) ,
    . cs_n      (cs_n_init      ) ,
    . sclk      (sclk_init      ) ,
    . miso      (miso_vld       ) ,
    . mosi      (mosi_init      ) ,
    . wr_done   (wr_done_init   ) ,
    . recv_data (recv_data      ) 
);

spi_wrp#(
    . SYSHZ         (SYSHZ     ) ,
    . SCLHZ         (SCLHZ     ) ,
    . DATA_WIDTH    (3) 
)u_spi_wrp_mode(
    . sys_clk   (sys_clk      ) ,
    . sys_rst   (sys_rst      ) ,
    . wr_en     (wr_en_mode   ) ,
    . wr_data   (wr_data_mode ) ,
    . cs_n      (cs_n_mode    ) ,
    . sclk      (sclk_mode    ) ,
    . mosi      (mosi_mode    ) ,
    . wr_done   (wr_done_mode )
);

// initial begin
//         $readmemh("D:/code/verilog/data/mem_value.txt", mem_value);  // 从 hex 文件加载数据
// end

// initial begin
//         $readmemh("D:/code/verilog/data/mem_addr.txt", mem_addr);  // 从 hex 文件加载数据
// end

init_bram u_init_bram (
  .clka  (ram_bc_init_clk       ),
  .ena   (ram_bc_init_en        ),
  .wea   (ram_bc_init_we        ),
  .addra (ram_bc_init_addr >> 2 ),
  .dina  (ram_bc_init_din       ),
  .douta (ram_bc_init_dout      ),
  .clkb  (sys_clk               ),
  .enb   (1                     ),
  .web   (0                     ),
  .addrb (usr_init_ram_addr         ),
  .dinb  (0                     ),
  .doutb (usr_init_ram_data         ) 
);

ram_init_back u_ram_init_back (
  .clka (ram_bc_init_clk_back      ),    // input wire clka
  .ena  (ram_bc_init_en_back       ),      // input wire ena
  .wea  (ram_bc_init_we_back[0]    ),      // input wire [0 : 0] wea
  .addra(ram_bc_init_addr_back >> 2),  // input wire [5 : 0] addra
  .dina (ram_bc_init_din_back      ),    // input wire [31 : 0] dina
  .douta(ram_bc_init_dout_back     ),  // output wire [31 : 0] douta
  .clkb (sys_clk                ),    // input wire clkb
  .enb  (usr_init_en_back       ),      // input wire enb
  .web  (usr_init_we_back       ),      // input wire [0 : 0] web
  .addrb(usr_init_addr_back     ),  // input wire [5 : 0] addrb
  .dinb (usr_init_din_back      ),    // input wire [31 : 0] dinb
  .doutb(                       )  // output wire [31 : 0] doutb
);

`ifdef DEBUG   
ila_init_fsm u_ila_init_fsm (
    .clk	        (sys_clk	                ),// 
    .probe0	        (cstate	                    ),//4  
    .probe1	        (nstate	                    ),//4 
    .probe2         (cnt_cycle                  ),//32
    .probe3         (cnt_bit                    ),//8 
    .probe4         (cnt_init                   ),//8 
    .probe5         (cs_n                       ),//8 
    .probe6         (sclk                       ),//8 
    .probe7         (mosi                       ),//32 
    .probe8         (chip_reset                 ),//8
    .probe9         (miso                       ),//8
    .probe10        (init_done                  ),//1 
    .probe11        (usr_init_en_back           ),//1 
    .probe12        (usr_init_we_back           ),//1 
    .probe13        (usr_init_addr_back[6:0]    ),//7
    .probe14        (usr_init_din_back          ), //32 
    .probe15        (recv_data                  )  //24 
);

ila_init_ram u_ila_init_ram (
    .clk	        (ram_bc_init_clk     ),//
    .probe0	        (ram_bc_init_en       ),//1  
    .probe1	        (ram_bc_init_we       ),//4  
    .probe2         (ram_bc_init_addr     ),//32  
    .probe3         (ram_bc_init_din      ),//32   
    .probe4         (ram_bc_init_dout     ) //32   
);

ila_init_ram u_ila_init_ram_bak (
    .clk	        (ram_bc_init_clk_back  	 ),//
    .probe0	        (ram_bc_init_en_back     ),//1  
    .probe1	        (ram_bc_init_we_back     ),//4  
    .probe2         (ram_bc_init_addr_back   ),//32  
    .probe3         (ram_bc_init_din_back    ),//32   
    .probe4         (ram_bc_init_dout_back   ) //32   
);


`endif

endmodule

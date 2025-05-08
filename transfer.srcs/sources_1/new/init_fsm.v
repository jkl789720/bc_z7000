`timescale 1ns / 1ps
module init_fsm#(
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 10_000_000                      ,
    parameter INIT_REG_NUM     = 16
)(
    input       sys_clk     ,
    input       sys_rst     ,
    output reg  chip_reset  ,
    output reg  cs_n        ,
    output reg  sclk        ,
    output reg  mosi        ,
    output reg  init_done   
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


//-------------状态切换相关变量------------------//
wire Chip_reset_Done,Efuse_reset_Done,Bc2spi_Done,Spi_init_Done,Spi2bc_Done;
reg [31:0] cnt_chip_reset,cnt_cycle;
reg [7:0]  cnt_bit;
reg [3:0] cstate,nstate;

reg wr_en_init   ;
reg [27:0] wr_data_init ;
wire cs_n_init    ;
wire sclk_init    ;
wire mosi_init    ;
wire wr_done_init ;
reg [5:0] wr_done_init_r;

reg wr_en_mode   ;
reg [2:0] wr_data_mode ;
wire cs_n_mode    ;
wire sclk_mode    ;
wire mosi_mode    ;
wire wr_done_mode ;
reg [15:0] mem_value [0:31];
reg [7:0] mem_addr [0:31];
wire [15:0] now_value;
wire [7:0] now_addr;
reg [7:0] cnt_init;
reg [$clog2(TIME_1200NS)-1:0] cnt_delay;

localparam IDLE          = 0;
localparam DELAY0        = 1;
localparam CHIP_RESET    = 2;
localparam DELAY1        = 3;
localparam EFUSE_RESET   = 4;
localparam DELAY2        = 5;
localparam BC2SPI        = 6;
localparam DELAY3        = 7;
localparam SPI_INTIT     = 8;
localparam DELAY4        = 9;
localparam SPI2BC        = 10;
localparam DELAY5        = 11;
localparam DONE          = 12;

assign now_value = mem_value[cnt_init];
assign now_addr  = mem_addr[cnt_init];

assign Chip_reset_Done = cnt_chip_reset == TIME_1200NS - 1;
assign Efuse_reset_Done = cnt_cycle == CYCLE - 1 && cnt_bit == EFUSE_TOTAL_BIT - 1;
assign Bc2spi_Done = wr_done_mode;
assign Spi_init_Done = wr_done_init && cnt_init == INIT_REG_NUM - 1;
assign Spi2bc_Done = wr_done_mode;
always @(posedge sys_clk) begin
    if(sys_rst) begin
        cstate <= IDLE;
    end else begin
        cstate <= nstate;
    end
end

always@(*)begin
    if(sys_rst)
        nstate = IDLE;
    else begin
        case(cstate)
            IDLE: begin
                nstate = DELAY0;
            end
            DELAY0:begin
                if(cnt_delay == DELAY_VALUE - 1)
                    nstate = CHIP_RESET;
                else
                    nstate = cstate;
            end
            CHIP_RESET: begin
                if(Chip_reset_Done)
                    nstate = DELAY1;
                else
                    nstate = cstate;
            end
            DELAY1: begin
                if(cnt_delay == DELAY_VALUE - 1)
                    nstate = EFUSE_RESET;
                else
                    nstate = cstate;
            end
            EFUSE_RESET: begin
                if(Efuse_reset_Done)
                    nstate = DELAY2;
                else
                    nstate = cstate;
            end
            DELAY2: begin
                if(cnt_delay == DELAY_VALUE - 1)
                    nstate = BC2SPI;
                else
                    nstate = cstate;
            end
            BC2SPI: begin
                if(Bc2spi_Done)
                    nstate = DELAY3;
                else
                    nstate = cstate;
            end
            DELAY3: begin
                if(cnt_delay == DELAY_VALUE - 1)
                    nstate = SPI_INTIT;
                else
                    nstate = cstate;
            end
            SPI_INTIT: begin
                if(Spi_init_Done)
                    nstate = DELAY4;
                else
                    nstate = cstate;
            end
            DELAY4: begin
                if(cnt_delay == DELAY_VALUE - 1)
                    nstate = SPI2BC;
                else
                    nstate = cstate;
            end
            SPI2BC: begin
                if(Spi2bc_Done)
                    nstate = DELAY5;
                else
                    nstate = cstate;
            end
            DELAY5: begin
                if(cnt_delay == DELAY_VALUE - 1)
                    nstate = DONE;
                else
                    nstate = cstate;
            end
            DONE: begin
                nstate = DONE;
            end
        endcase
    end
end

always @(posedge sys_clk) begin
    if(sys_rst)begin
        cnt_chip_reset <= 0;
        cnt_cycle      <= 0;
        cnt_bit        <= 0;
        chip_reset     <= 0;
        wr_data_mode   <= 0;
        wr_en_mode     <= 0;
        wr_data_init   <= 0;
        wr_en_init     <= 0;
        cnt_init       <= 0;
        wr_done_init_r <= 0;
        cnt_delay      <= 0;

        cs_n           <= 1;
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
                wr_data_init   <= 0;
                wr_en_init     <= 0;
                cnt_init       <= 0;
                wr_done_init_r <= 0;
                cnt_delay      <= 0;

                cs_n           <= 1;
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
                    chip_reset     <= 1;
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
                        cs_n <= 1;
                    else
                        cs_n <= cs_n;
                
                //sclk_generate
                if((cnt_bit > 0 && cnt_bit < EFUSE_START_BIT - 1) | (cnt_bit > EFUSE_START_BIT + EFUSE_INT_BIT && cnt_bit < EFUSE_TOTAL_BIT - 1))begin//1-6 39-46
                    if(cnt_cycle == 0)
                        sclk <= 0;
                    else if(cnt_cycle == CYCLE_MID)
                        sclk <= 1;
                end
                else
                    sclk <= 0;
            end
            BC2SPI,SPI2BC:begin
                //-----------------cur_state-----------------//
                wr_en_mode <= Bc2spi_Done | Spi2bc_Done  ? 0 : 1;
                wr_data_mode <= 0;

                cs_n <= cs_n_mode;
                sclk <= sclk_mode;
                mosi <= 0;
            end
            SPI_INTIT:begin

                //-----------------cur_state-----------------//
                if(wr_done_init)begin
                    if(cnt_init == INIT_REG_NUM - 1)
                        cnt_init <= 0;
                    else
                        cnt_init <= cnt_init + 1;
                end
                wr_done_init_r <= {wr_done_init_r[5:0],wr_done_init};

                wr_en_init <= wr_done_init_r[5];
                wr_data_init <= {4'b0100,now_addr,now_value};
                // wr_data_init <= {4'b0100,24'h555555};

                cs_n <= cs_n_init;
                sclk <= sclk_init;
                mosi <= mosi_init;
            end
            DONE:begin
                //-----------------cur_state-----------------//
                init_done <= 1;
            end
            DELAY0,DELAY1,DELAY2,DELAY3,DELAY4,DELAY5:begin
                //-----------------cur_state-----------------//
                if(cnt_delay == DELAY_VALUE - 1)
                    cnt_delay <= 0;
                else
                    cnt_delay <= cnt_delay + 1;

                cs_n <= 1;
                sclk <= 0;
                mosi <= 0;
                // chip_reset <= 0;
                
                //-----------------next_state-----------------//
                if(cstate == DELAY3 && cnt_delay == DELAY_VALUE - 1)begin
                    wr_en_init <= 1;
                    wr_data_init <= {4'b0100,now_addr,now_value};
                end
                else begin 
                    wr_en_init <= 0;
                    wr_data_init <= 0;
                end
            end
            default:begin
                cnt_chip_reset <= 0;
                cnt_cycle      <= 0;
                cnt_bit        <= 0;
                chip_reset     <= 0;
                wr_data_mode   <= 0;
                wr_en_mode     <= 0;
                wr_data_init   <= 0;
                wr_en_init     <= 0;
                cnt_init       <= 0;
                wr_done_init_r <= 0;
                cnt_delay      <= 0;

                cs_n           <= 1;
                sclk           <= 0;
                mosi           <= 0;
            end
            
        endcase
    end
end

spi_wrp#(
    . SYSHZ         (SYSHZ     ) ,
    . SCLHZ         (SCLHZ     ) ,
    . DATA_WIDTH    (28) 
)u_spi_wrp_init(
    . sys_clk   (sys_clk      ) ,
    . sys_rst   (sys_rst      ) ,
    . wr_en     (wr_en_init   ) ,
    . wr_data   (wr_data_init ) ,
    . cs_n      (cs_n_init    ) ,
    . sclk      (sclk_init    ) ,
    . mosi      (mosi_init    ) ,
    . wr_done   (wr_done_init )
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

initial begin
        $readmemh("D:/code/verilog/data/mem_value.txt", mem_value);  // 从 hex 文件加载数据
end

initial begin
        $readmemh("D:/code/verilog/data/mem_addr.txt", mem_addr);  // 从 hex 文件加载数据
end


`ifdef DEBUG   
ila_init_fsm u_ila_init_fsm (
    .clk	        (sys_clk	        ),// 
    .probe0	        (cstate	            ),//4  
    .probe1	        (nstate	            ),//4 
    .probe2         (cnt_cycle          ),//32
    .probe3         (cnt_bit            ),//8 
    .probe4         (cnt_init           ),//8 
    .probe5         (cnt_delay          ),//6 
    .probe6         (cnt_chip_reset     ),//32 
    .probe7         (cs_n               ),//1 
    .probe8         (sclk               ),//1 
    .probe9         (mosi               ),//1 
    .probe10        (init_done          ),//1 
    .probe11        (chip_reset         ) //1 
);
`endif

endmodule

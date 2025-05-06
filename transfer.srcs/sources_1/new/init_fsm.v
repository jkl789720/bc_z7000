`timescale 1ns / 1ps
module init_fsm#(
    parameter SYSHZ            = 50_000_000                      ,
    parameter SCLHZ            = 10_000_000                      
)(
    input       sys_clk     ,
    input       sys_rst     ,
    output reg  chip_reset  ,
    output reg  cs_init     ,
    output reg  sclk_init   ,
    output reg  mosi_init   ,
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


//-------------状态切换相关变量------------------//
wire chip_reset2efuse_reset,efuse_reset2bc2spi,bc2spi2spi_init,spi_init2spi2bc,spi2bc2done;
reg [31:0] cnt_chip_reset,cnt_cycle;
reg [7:0]  cnt_bit;
reg [3:0] cstate,nstate;


localparam IDLE          = 0;
localparam CHIP_RESET    = 1;
localparam EFUSE_RESET   = 2;
localparam BC2SPI        = 3;
localparam SPI_INTIT     = 4;
localparam SPI2BC        = 5;
localparam DONE          = 6;

assign chip_reset2efuse_reset = cnt_chip_reset == TIME_1200NS - 1;
assign efuse_reset2bc2spi = cnt_cycle == CYCLE - 1 && cnt_bit == EFUSE_TOTAL_BIT - 1;
assign bc2spi2spi_init = cnt_cycle == CYCLE - 1 && cnt_bit == 12 - 1;
assign spi_init2spi2bc = cnt_cycle == CYCLE - 1 && cnt_bit == 12 - 1;

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
                nstate = CHIP_RESET;
            end
            CHIP_RESET: begin
                if(chip_reset2efuse_reset)
                    nstate = EFUSE_RESET;
                else
                    nstate = CHIP_RESET;
            end
            EFUSE_RESET: begin
                if(efuse_reset2bc2spi)
                    nstate = BC2SPI;
                else
                    nstate = EFUSE_RESET;
            end
            BC2SPI: begin
                if(bc2spi2spi_init)
                    nstate = SPI_INTIT;
                else
                    nstate = BC2SPI;
            end
            SPI_INTIT: begin
                if(spi_init2spi2bc)
                    nstate = SPI2BC;
                else
                    nstate = SPI_INTIT;
            end
            SPI2BC: begin
                if(spi2bc2done)
                    nstate = DONE;
                else
                    nstate = SPI_INTIT;
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
        cs_init        <= 1;
        sclk_init      <= 0;
        mosi_init      <= 0;
        init_done      <= 0;
    end
    else begin
        case (cstate)
            IDLE:begin
                cnt_chip_reset <= 0;
                cnt_cycle      <= 0;
                cnt_bit        <= 0;

                chip_reset     <= 0;
                cs_init        <= 1;
                sclk_init      <= 0;
                mosi_init      <= 0;
                init_done      <= 0;
            end
            CHIP_RESET:begin
                cnt_chip_reset <= cnt_chip_reset + 1;  
                chip_reset     <= 1;
            end
            EFUSE_RESET:begin
                cnt_chip_reset <= 0;
                chip_reset     <= 0;
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
                //cs_init_generate
                    if(cnt_cycle == 0 && (cnt_bit == 0 | (cnt_bit == EFUSE_TOTAL_BIT -EFUSE_END_BIT)))//38
                        cs_init <= 0;
                    else if(cnt_cycle == CYCLE - 1  && (cnt_bit == EFUSE_START_BIT - 1 | (cnt_bit == EFUSE_TOTAL_BIT - 1)))//cnt能否到EFUSE_BIT？仿真确认
                        cs_init <= 1;
                    else
                        cs_init <= cs_init;
                
                //sclk_init_generate
                if((cnt_bit > 0 && cnt_bit < EFUSE_START_BIT - 1) | (cnt_bit > EFUSE_START_BIT + EFUSE_INT_BIT && cnt_bit < EFUSE_TOTAL_BIT - 1))begin//1-6 39-46
                    if(cnt_cycle == 0)
                        sclk_init <= 0;
                    else if(cnt_cycle == CYCLE_MID)
                        sclk_init <= 1;
                end
                else
                    sclk_init <= 0;
            end
            BC2SPI,SPI2BC:begin
                 if(cnt_cycle == CYCLE - 1)
                    cnt_cycle      <= 0;
                else
                    cnt_cycle      <= cnt_cycle + 1;
                //cnt_bit_generate
                if(cnt_cycle == CYCLE - 1)begin
                    if(cnt_bit == 12 - 1)
                        cnt_bit <= 0;
                    else 
                        cnt_bit <= cnt_bit + 1;
                end
                //cs_init_generate
                if(cnt_cycle == 0 && (cnt_bit == 0 | (cnt_bit == 12)))//11
                    cs_init <= 0;
                else if(cnt_cycle == CYCLE - 1  && ((cnt_bit == 6) | (cnt_bit == 12)))//
                    cs_init <= 1;
                else
                    cs_init <= cs_init;
                //sclk_init_generate
                if((cnt_bit > 0 && cnt_bit < 4) | (cnt_bit > 5 && cnt_bit < 10))begin//1-3 6-9
                    if(cnt_cycle == 0)
                        sclk_init <= 0;
                    else if(cnt_cycle == CYCLE_MID)
                        sclk_init <= 1;
                end
                else if(cnt_bit == 4)
                    sclk_init <= 0;
                else if(cnt_bit == 5)
                    sclk_init <= 1;
                else
                    sclk_init <= 0;
            end
            
        endcase
    end
end

spi_wrp#(
    . SYSHZ         (SYSHZ     ) ,
    . SCLHZ         (SCLHZ     ) ,
    . DATA_WIDTH    (3) 
)u_spi_wrp_mode(
    . sys_clk   (sys_clk ) ,
    . sys_rst   (sys_rst ) ,
    . wr_en     (wr_en   ) ,
    . wr_data   (wr_data ) ,
    . cs_n      (cs_n    ) ,
    . sclk      (sclk    ) ,
    . mosi      (mosi    ) ,
    . wr_done   (wr_done )
);

spi_wrp#(
    . SYSHZ         (SYSHZ     ) ,
    . SCLHZ         (SCLHZ     ) ,
    . DATA_WIDTH    (28) 
)u_spi_wrp_init(
    . sys_clk   (sys_clk ) ,
    . sys_rst   (sys_rst ) ,
    . wr_en     (wr_en   ) ,
    . wr_data   (wr_data ) ,
    . cs_n      (cs_n    ) ,
    . sclk      (sclk    ) ,
    . mosi      (mosi    ) ,
    . wr_done   (wr_done )
);

endmodule

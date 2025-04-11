// Module: spi_to_bram_top
// 功能  : 顶层模块，例化16个SPI接收模块和1个SPI转BRAM模块。
//         输入为16路SPI接口（spi_clk、spi_cs_n、spi_mosi），输出为BRAM接口信号及写完成标志。
// ============================================================================
module check_spi_to_bram_top#(
   parameter CHANNEL_NUM    = 32 ,// SPI通道数
   parameter BIT_NUM        = 106 //单spi通道bit数 
) (
    input             clk,
    input             rst_n,
    // 16路SPI接口，均采用独立的信号（均为异步信号，需要同步）
    input  [CHANNEL_NUM - 1:0]     spi_clk,
    input  [CHANNEL_NUM - 1:0]     spi_cs_n,
    input  [CHANNEL_NUM - 1:0]     spi_mosi,
    input  [31:0]                  beam_pos_num,
    // BRAM写接口输出
    output            bram_we,
    output [31:0]     bram_addr,
    output [31:0]     bram_data,
    output            done
);

    // 内部连线：16个spi_rx模块的输出数据与valid信号打包
    wire [CHANNEL_NUM*BIT_NUM-1:0] rx_data;
    wire [CHANNEL_NUM-1:0]       rx_valid;
    
    genvar i;
    generate
        for (i = 0; i < CHANNEL_NUM; i = i+1) begin : gen_spi_rx
            check_spi_rx #(
                .BIT_NUM(BIT_NUM)
            ) u_check_spi_rx (
                .clk       (clk),
                .rst_n     (rst_n),
                .spi_clk_in(spi_clk[i]),
                .spi_cs_n_in(spi_cs_n[i]),
                .spi_mosi  (spi_mosi[i]),
                .data_out  (rx_data[i*BIT_NUM +: BIT_NUM]),
                .valid     (rx_valid[i])
            );
        end
    endgenerate

    // 实例化SPI转BRAM模块，将16路接收数据转为BRAM写数据
    check_spi2bram #(
        .CHANNEL_NUM(CHANNEL_NUM)
    ) u_check_spi2bram (
        .clk      (clk),
        .rst_n    (rst_n),
        .spi_data (rx_data),
        .spi_valid(rx_valid),
        .beam_pos_num(beam_pos_num),
        .bram_we  (bram_we),
        .bram_addr(bram_addr),
        .bram_data(bram_data),
        .done     (done)
    );

    ila_check_back_spi u_u_ila_check_back_spi (
        .clk(clk), // input wire clk
    
    
        .probe0(spi_clk         ),//32
        .probe1(spi_cs_n        ),//32
        .probe2(spi_mosi        ),//32
        .probe3(beam_pos_num    ),//32
        .probe4(rx_data[31:0]   ) //32
    );

endmodule
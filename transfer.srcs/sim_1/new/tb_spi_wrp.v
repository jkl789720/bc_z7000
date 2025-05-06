`timescale 1ns / 1ps

module tb_spi_wrp();

// 模块参数
parameter SYSHZ    = 50_000_000;  // 50MHz 系统时钟
parameter SCLHZ    = 10_000_000;  // 10MHz SPI 时钟
parameter DATA_WIDTH = 28;         // 28位数据宽度

// 模块输入信号
reg         sys_clk;
reg         sys_rst;
reg         wr_en;
reg  [DATA_WIDTH-1:0] wr_data;

// 模块输出信号
wire        cs_n;
wire        sclk;
wire        mosi;
wire        wr_done;

// 实例化被测模块
spi_wrp #(
    .SYSHZ     (SYSHZ),
    .SCLHZ     (SCLHZ),
    .DATA_WIDTH (DATA_WIDTH)
) u_spi_wrp (
    .sys_clk  (sys_clk),
    .sys_rst  (sys_rst),
    .wr_en    (wr_en),
    .wr_data  (wr_data),
    .cs_n     (cs_n),
    .sclk     (sclk),
    .mosi     (mosi),
    .wr_done  (wr_done)
);

// 时钟生成 (50MHz)
initial begin
    sys_clk = 0;
    forever #10 sys_clk = ~sys_clk;  // 20ns周期 = 50MHz
end

// 测试激励
initial begin
    // 初始化
    sys_rst = 1;
    wr_en   = 0;
    wr_data = 0;
    
    // 复位释放
    #100;
    sys_rst = 0;
    
    // 测试1: 发送一个28位数据 (0x1234567)
    #20;
    wr_data = 28'h1234567;
    wr_en   = 1;
    #20;
    wr_en   = 0;
    
    // 等待传输完成
    wait(wr_done == 1);
    #200;
    
    // 测试2: 发送另一个数据 (0xABCDEF0)
    wr_data = 28'hABCDEF0;
    wr_en   = 1;
    #20;
    wr_en   = 0;
    
    // 等待传输完成
    wait(wr_done == 1);
    #200;
    
    // 结束仿真
    $display("Simulation finished");
    $finish;
end

// 监测信号变化
initial begin
    $monitor("Time=%0t: cs_n=%b sclk=%b mosi=%b wr_done=%b cnt_bit=%0d cnt_cycle=%0d",
             $time, cs_n, sclk, mosi, wr_done, u_spi_wrp.cnt_bit, u_spi_wrp.cnt_cycle);
end

// 生成波形文件 (用于GTKWave或其他波形查看器)
initial begin
    $dumpfile("spi_wrp.vcd");
    $dumpvars(0, tb_spi_wrp);
end

endmodule
`timescale 1ns/1ps

//------------------------------------------------------------------------------ // Testbench: tb_spi_writer // Function: Verify spi_writer behavior for both short and long frames //           with parameterized SPI clock frequency //------------------------------------------------------------------------------ 
module tb_spi_writer; // Parameters for DUT instantiation parameter SYS_CLK_FREQ_HZ = 100_000_000; parameter SPI_CLK_FREQ_HZ = 10_000_000;
    parameter integer SHORT_BITS       = 16;        // 短帧数据位宽
    parameter integer LONG_BITS        = 106;       // 长帧数据位宽
    parameter integer SYS_CLK_FREQ_HZ  = 100_000_000; // 系统时钟频率，Hz
    parameter integer SPI_CLK_FREQ_HZ  = 5_000_000;    // 目标 SPI 时钟频率，Hz
// Clock and reset
reg clk = 0;
reg rst_n = 0;
always #5 clk = ~clk;  // 100MHz system clock

// DUT inputs
reg start;
reg frame_type;
reg rw;
reg op;
reg [7:0] addr;
reg [105:0] data_in;

// DUT outputs
wire csb;
wire sclk;
wire sdi;
wire done;

// Instantiate DUT
spi_writer #(
    .SYS_CLK_FREQ_HZ(SYS_CLK_FREQ_HZ),
    .SPI_CLK_FREQ_HZ(SPI_CLK_FREQ_HZ)
) u_u_spi_writer (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .frame_type(frame_type),
    .rw(rw),
    .op(op),
    .addr(addr),
    .data_in(data_in),
    .csb(csb),
    .sclk(sclk),
    .sdi(sdi),
    .done(done)
);

// Task: issue an SPI write transaction
task spi_write;
    input t_frame_type;
    input t_rw;
    input t_op;
    input [7:0] t_addr;
    input [105:0] t_data;
begin
    frame_type = t_frame_type;
    rw         = t_rw;
    op         = t_op;
    addr       = t_addr;
    data_in    = t_data;
    start      = 1'b1;
    @(posedge clk);
    start      = 1'b0;
    // wait for completion
    wait(done == 1'b1);
    @(posedge clk);
end
endtask

initial begin
    // Reset sequence
    rst_n = 0;
    start = 0;
    frame_type = 0;
    rw = 0;
    op = 0;
    addr = 8'h00;
    data_in = 106'd0;
    #100;
    rst_n = 1;
    #20;

    // Short frame write example
    spi_write(1'b0,  // short frame
              1'b0,  // write
              1'b1,  // op = 1
              8'h5A, // addr
              106'h00000000000000A55A);
    #50;

    // Long frame write example
    spi_write(1'b1,  // long frame
              1'b0,  // write
              1'b0,  // op = 0
              8'hA5, // addr
              106'h123456789ABCDEF0123456789ABCDEF0123456);
    #50;

    $display("%0t: Simulation complete", $time);
    $stop;
end

endmodule


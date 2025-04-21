//------------------------------------------------------------------------------
// spi_writer: 支持短/长帧写；CSB 两次上升沿；目标 SPI 频率参数化；下降沿发 MSB
//------------------------------------------------------------------------------
module spi_writer #(
    parameter integer SHORT_BITS       = 16,        // 短帧数据位宽
    parameter integer LONG_BITS        = 106,       // 长帧数据位宽
    parameter integer SYS_CLK_FREQ_HZ  = 100_000_000, // 系统时钟频率，Hz
    parameter integer SPI_CLK_FREQ_HZ  = 5_000_000    // 目标 SPI 时钟频率，Hz
)(
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 异步复位（低有效）
    input  wire        start,        // 启动，异步打两拍同步
    input  wire        frame_type,   // 0=短帧，1=长帧
    input  wire        rw,           // R/W
    input  wire        op,           // OP
    input  wire [7:0]  addr,         // Address[7:0]
    input  wire [105:0] data_in,     // Data 输入

    output reg         csb,          // 片选（低有效）
    output reg         sclk,         // SPI 时钟，空闲低
    output reg         sdi,          // MOSI 数据
    output reg         done          // 完成脉冲，高一 clk 周期
);

    //—— 计算分频因子，使得 sclk ≈ SPI_CLK_FREQ_HZ ——//
    localparam integer DIV = SYS_CLK_FREQ_HZ / (2 * SPI_CLK_FREQ_HZ);
    // DIV 必须 >= 1
    initial begin
        if (DIV < 1) begin
            $error("Invalid DIV (%0d): ensure SYS_CLK_FREQ_HZ/(2*SPI_CLK_FREQ_HZ)>=1", DIV);
        end
    end

    // 状态编码
    localparam IDLE     = 3'd0,
               LOAD     = 3'd1,
               TRANS    = 3'd2,
               FIRST_CS = 3'd3,
               WAIT4    = 3'd4,
               FINAL_CS = 3'd5,
               DONE     = 3'd6;

    // 状态寄存
    reg [2:0]   state, next_state;
    // 移位寄存器 & 位计数
    reg [127:0] shift_reg;
    reg [7:0]   bit_cnt, total_bits;
    // 分频计数 & 使能
    reg [31:0]  clk_div_cnt;
    reg         spi_clk_en;

    //—— start 异步打两拍 ——//
    reg start_ff1, start_ff2;
    wire start_posedge;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_ff1 <= 1'b0;
            start_ff2 <= 1'b0;
        end else begin
            start_ff1 <= start;
            start_ff2 <= start_ff1;
        end
    end
    assign start_posedge = start_ff1 & ~start_ff2;

    //—— 三段式状态机 ——//
    // 1) 状态寄存
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // 2) 下一状态组合
    always @(*) begin
        case (state)
            IDLE:     next_state = start_posedge ? LOAD : IDLE;
            LOAD:     next_state = TRANS;
            TRANS:    next_state = (bit_cnt == total_bits) ? FIRST_CS : TRANS;
            FIRST_CS: next_state = WAIT4;
            WAIT4:    next_state = FINAL_CS;
            FINAL_CS: next_state = DONE;
            DONE:     next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // 3) 时序逻辑 & 输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // ——— 异步复位 ———
            csb         <= 1'b1;
            sclk        <= 1'b0;       // 空闲低电平
            sdi         <= 1'b0;
            done        <= 1'b0;
            bit_cnt     <= 8'd0;
            total_bits  <= 8'd0;
            shift_reg   <= 128'd0;
            clk_div_cnt <= DIV - 1;
            spi_clk_en  <= 1'b0;
        end else begin
            done <= 1'b0;  // 默认清除完成脉冲

            // —— 分频计数 ——//
            if (clk_div_cnt == 0) begin
                clk_div_cnt <= DIV - 1;
                spi_clk_en  <= 1'b1;
            end else begin
                clk_div_cnt <= clk_div_cnt - 1;
                spi_clk_en  <= 1'b0;
            end

            case (state)
                IDLE: begin
                    csb  <= 1'b1;
                    sclk <= 1'b0;
                end

                LOAD: begin
                    csb       <= 1'b0;  // 拉低 CS，准备发
                    sclk      <= 1'b0;
                    bit_cnt   <= 8'd0;
                    // “枕头”放前：{mode, rw, op, addr}，数据放后
                    shift_reg <= {
                        2'b01,
                        rw,
                        op,
                        addr,
                        frame_type
                            ? data_in
                            : {{(106-SHORT_BITS){1'b0}}, data_in[15:0]}
                    };
                    total_bits <= 11 + (frame_type ? LONG_BITS : SHORT_BITS);
                end

                TRANS: begin
                    if (spi_clk_en) begin
                        if (sclk) begin
                            // sclk 从 1→0：下降沿，输出当前最高位
                            sclk <= 1'b0;
                            sdi  <= shift_reg[total_bits-1];
                        end else begin
                            // sclk 从 0→1：上升沿，移位计数
                            sclk      <= 1'b1;
                            shift_reg <= shift_reg << 1;
                            bit_cnt   <= bit_cnt + 1;
                        end
                    end
                end

                FIRST_CS: begin
                    csb  <= 1'b1; // 第一次上升沿，加载寄存器
                    sclk <= 1'b0;
                end

                WAIT4: begin
                    csb  <= 1'b0; // 等待 4 个系统时钟，不产生新 sclk
                end

                FINAL_CS: begin
                    csb <= 1'b1;  // 第二次上升沿，配置生效
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule

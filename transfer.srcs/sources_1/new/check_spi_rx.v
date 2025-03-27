// ============================================================================
// Module: spi_rx
// 功能  : SPI数据接收模块，支持可配置接收位数（默认106位）。
// 接口  : 异步输入spi_clk_in与spi_cs_n_in（均采用两拍同步），采样spi_mosi。
// 说明  : 当片选信号(cs_n)拉低时进入接收状态，利用同步后的spi_clk上升沿依次移入数据，
//         当片选恢复高电平时，如果已接收完整则产生valid信号并输出data_out。
// ============================================================================
module check_spi_rx #(
    parameter BIT_NUM = 106  // 接收位数参数（包括无效位）
)(
    input                clk,         // 本地系统时钟（适合FPGA内部）
    input                rst_n,       // 异步复位（低有效）
    // 异步SPI信号，需两拍同步
    input                spi_clk_in,  // SPI时钟（异步）
    input                spi_cs_n_in, // SPI片选（异步，低有效）
    input                spi_mosi,    // SPI数据信号
    // 接收输出
    output reg [BIT_NUM-1:0] data_out, // 接收到的数据
    output reg               valid    // 接收完成标志（1个时钟周期有效）
);

    // -------------------------------------------------------------------------
    // 异步信号两拍同步（适用于spi_clk_in与spi_cs_n_in）
    // -------------------------------------------------------------------------
    reg spi_clk_sync_0, spi_clk_sync_1;
    reg spi_cs_sync_0,  spi_cs_sync_1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk_sync_0 <= 1'b0;
            spi_clk_sync_1 <= 1'b0;
            spi_cs_sync_0  <= 1'b1; // 片选初始为不使能状态
            spi_cs_sync_1  <= 1'b1;
        end else begin
            spi_clk_sync_0 <= spi_clk_in;
            spi_clk_sync_1 <= spi_clk_sync_0;
            spi_cs_sync_0  <= spi_cs_n_in;
            spi_cs_sync_1  <= spi_cs_sync_0;
        end
    end

    // -------------------------------------------------------------------------
    // spi_clk上升沿检测（利用额外寄存器保存上一拍采样值）
    // -------------------------------------------------------------------------
    reg spi_clk_sync_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            spi_clk_sync_d <= 1'b0;
        else
            spi_clk_sync_d <= spi_clk_sync_1;
    end
    wire spi_clk_rising = (spi_clk_sync_1 & ~spi_clk_sync_d);

    // -------------------------------------------------------------------------
    // 三段式状态机定义
    // 状态定义：S_IDLE-空闲状态，等待片选；S_RECEIVE-数据接收中；S_DONE-接收完成
    // -------------------------------------------------------------------------
    localparam S_IDLE    = 2'b00,
               S_RECEIVE = 2'b01,
               S_DONE    = 2'b10;
               
    reg [1:0] state, next_state;
    // 位计数器：统计已接收位数
    reg [$clog2(BIT_NUM+1)-1:0] bit_cnt;
    // 数据移位寄存器
    reg [BIT_NUM-1:0] shift_reg;
    
    // -------------------------------
    // 状态寄存：当前状态更新
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // -------------------------------
    // 组合逻辑：计算下一状态（默认赋值防止锁存器）
    // -------------------------------
    always @(*) begin
        next_state = state;  // 默认保持当前状态
        case (state)
            S_IDLE: begin
                if (spi_cs_sync_1 == 1'b0)  // 片选拉低，开始接收
                    next_state = S_RECEIVE;
                else
                    next_state = S_IDLE;
            end
            S_RECEIVE: begin
                // 当片选恢复高电平时，若已接收完整则进入DONE，否则丢弃数据返回空闲
                if (spi_cs_sync_1 == 1'b1) begin
                    if (bit_cnt == BIT_NUM)
                        next_state = S_DONE;
                    else
                        next_state = S_IDLE;
                end else begin
                    next_state = S_RECEIVE;
                end
            end
            S_DONE: begin
                next_state = S_IDLE; // DONE状态只持续一个时钟周期
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // -------------------------------
    // 输出逻辑：状态机功能实现
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt   <= 0;
            shift_reg <= {BIT_NUM{1'b0}};
            data_out  <= {BIT_NUM{1'b0}};
            valid     <= 1'b0;
        end else begin
            // 默认清除valid
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    // 当进入接收状态前清零计数器与移位寄存器
                    if (spi_cs_sync_1 == 1'b0) begin
                        bit_cnt   <= 0;
                        shift_reg <= {BIT_NUM{1'b0}};
                    end
                end
                S_RECEIVE: begin
                    // 在同步后的SPI时钟上升沿采样spi_mosi数据
                    if (spi_clk_rising) begin
                        shift_reg <= {shift_reg[BIT_NUM-2:0], spi_mosi};
                        bit_cnt   <= bit_cnt + 1;
                    end
                end
                S_DONE: begin
                    // 接收完成，输出数据，并拉高valid一个周期
                    data_out <= shift_reg;
                    valid    <= 1'b1;
                end
                default: begin
                    // 默认分支
                end
            endcase
        end
    end

endmodule

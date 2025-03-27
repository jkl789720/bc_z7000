// ============================================================================
// Module: check_spi2bram
// 功能  : 多波位写入BRAM。
//         - 一次写入称为“一波位”，包含 CHANNEL_NUM * 4 次写操作。
//         - beam_pos_num 表示本次需要写入的总波位数，
//           可以是1(单波位)或更大(多波位)。
//         - 每写完一波位，就判断 wave_count 是否达到 beam_pos_num_reg：
//           如果未到达，继续等待下一波位数据；如果到达或超过，则输出done，
//           并回到初始状态等待下一次写入。
// ============================================================================
module check_spi2bram #(
    parameter CHANNEL_NUM = 32,  // SPI通道数
    parameter BEAM_POS_NUM = 10  // 默认的波位数上限（也可仅作参考）
)(
    input                                   clk,
    input                                   rst_n,
    // SPI数据及有效标志（打包为宽总线）
    input  [CHANNEL_NUM*106-1:0]            spi_data,  
    input  [CHANNEL_NUM-1:0]                spi_valid,
    
    // 输入的波位数（本轮要写多少波位）
    input  [31:0]                           beam_pos_num,
    
    // BRAM写接口
    output reg                              bram_we,    // BRAM写使能
    output reg [31:0]                       bram_addr,  // 写地址
    output reg [31:0]                       bram_data,  // 写数据(32bit, 低26有效)
    output reg                              done        // 本轮所有波位写完标志
);

    // 每个波位包含 CHANNEL_NUM*4 次写
    localparam LANE_NUM = CHANNEL_NUM * 4;

    // 缓存：存储当前波位的 SPI 数据
    reg [105:0] spi_data_buf [0:CHANNEL_NUM-1];

    // 状态机定义
    localparam STATE_IDLE  = 2'b00,  // 等待下一次波位写入开始
               STATE_WRITE = 2'b01,  // 正在写当前波位
               STATE_DONE  = 2'b10;  // 当前波位写完，判断是否还要继续

    reg [1:0] state, next_state;

    // 记录本轮要写的总波位数
    reg [31:0] beam_pos_num_reg;
    // 记录已写完的波位计数
    reg [31:0] wave_count;

    // 单个波位内部的写地址计数器：0 ~ (LANE_NUM - 1)
    reg [$clog2(LANE_NUM)-1:0] write_counter;

    // 分段数据(26bit)
    reg [25:0] seg_data;

    // 计算当前写操作对应的通道、段号
    wire [$clog2(CHANNEL_NUM)-1:0] channel_index = write_counter[$clog2(LANE_NUM)-1:2]; 
    wire [1:0]                     seg_index     = write_counter[1:0];   

    // 提取 26bit 分段（忽略高2位）
    always @(*) begin
        case (seg_index)
            2'b00: seg_data = spi_data_buf[channel_index][25:0];
            2'b01: seg_data = spi_data_buf[channel_index][51:26];
            2'b10: seg_data = spi_data_buf[channel_index][77:52];
            2'b11: seg_data = spi_data_buf[channel_index][103:78];
            default: seg_data = 26'd0;
        endcase
    end

    // ----------------------------------------------------------------------------
    // 状态机：三段式
    // ----------------------------------------------------------------------------
    // 1) 状态寄存
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= STATE_IDLE;
        else
            state <= next_state;
    end

    // 2) 组合逻辑：计算下一状态
    integer i;
    // 当所有通道 spi_valid=1，表示当前波位数据已准备就绪
    wire all_valid = &spi_valid;

    always @(*) begin
        next_state = state;
        case (state)
            // STATE_IDLE：等待下一波位数据到来
            STATE_IDLE: begin
                // 如果侦测到所有通道有效，则开始写当前波位
                if (all_valid) 
                    next_state = STATE_WRITE;
                else
                    next_state = STATE_IDLE;
            end

            // STATE_WRITE：单波位内部写操作（LANE_NUM 次）
            STATE_WRITE: begin
                if (write_counter == LANE_NUM - 1)
                    next_state = STATE_DONE;
                else
                    next_state = STATE_WRITE;
            end

            // STATE_DONE：单波位写完后，判断是否继续下一波位或结束
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // 3) 输出逻辑：在每个状态下更新寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bram_we         <= 1'b0;
            bram_addr       <= 32'd0;
            bram_data       <= 32'd0;
            done            <= 1'b0;

            beam_pos_num_reg<= 32'd0;
            wave_count      <= 32'd0;
            write_counter   <= 0;

            // 初始化缓存
            for (i = 0; i < CHANNEL_NUM; i=i+1) begin
                spi_data_buf[i] <= 106'd0;
            end
        end else begin
            // 默认值
            bram_we <= 1'b0;
            done    <= 1'b0;

            case (state)
            //--------------------------------------------------------------------------
            // 等待新的波位数据
            //--------------------------------------------------------------------------
            STATE_IDLE: begin
                // 如果是新一轮写（wave_count=0），则锁存 beam_pos_num
                // 表示本轮最多要写多少波位
                if (wave_count == 0) begin
                    beam_pos_num_reg <= beam_pos_num;
                end

                // 检测到所有通道数据有效，则缓存到 spi_data_buf
                if (all_valid) begin
                    for (i = 0; i < CHANNEL_NUM; i=i+1) begin
                        spi_data_buf[i] <= spi_data[i*106 +: 106];
                    end
                    write_counter <= 0;
                end
            end

            //--------------------------------------------------------------------------
            // 写当前波位
            //--------------------------------------------------------------------------
            STATE_WRITE: begin
                bram_we   <= 1'b1;
                // 若要区分不同波位写不同地址段，可加 offset:
                // bram_addr = wave_count * LANE_NUM + write_counter
                // 此处简单示例，地址直接从 0 ~ LANE_NUM-1，每波位都写同一段
                bram_addr <= wave_count * LANE_NUM + write_counter;
                bram_data <= {6'd0, seg_data};

                if (write_counter < LANE_NUM - 1)
                    write_counter <= write_counter + 1;
            end

            //--------------------------------------------------------------------------
            // 当前波位写完，判断是否继续或结束
            //--------------------------------------------------------------------------
            STATE_DONE: begin
                // 当前波位结束，wave_count+1
                wave_count <= wave_count + 1;

                // 如果已经写到的波位数 >= beam_pos_num_reg，表示本轮结束
                if (wave_count + 1 >= beam_pos_num_reg) begin
                    done            <= 1'b1;         // 拉高done一个周期
                    wave_count      <= 0;            // 清零波位计数
                    beam_pos_num_reg<= 0;            // 清零波位上限
                    bram_addr       <= 0;            // 清零地址
                    // 如果还需要清缓存可在此处执行
                end
            end

            default: ;
            endcase
        end
    end

endmodule

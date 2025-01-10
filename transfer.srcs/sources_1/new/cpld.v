module BC_TRANS(
    input SYSCLK,	// 25MHz
    
    output              LED,
    
    input 				BC_CLK,
    input [3:0] 		BC_TXD,
    input 				BC_CS,//mode
    input 				BC_RXEN,//mode
    input 				BC_TXEN,//tr
    input 				BC_LATCH,//ld
    
    output 				BC_RXD
    );

    //--------------变量定义---------------//
    //计数器
    reg [7:0] cnt = 0;
    wire add_flag_cnt,end_flag_cnt;
    //数据接收寄存器
    reg [106*4-1:0] data_g_now;
    reg group_data_valid;
    //数据LATCH相关的信号
    reg [106*4-1:0] data_g_latch;
    reg latch_time = 0;
    //组ID信号
    reg [3:0] group_id;
    //打拍寄存信号
    reg [2:0] BC_CLK_r,BC_CS_r;
    reg [1:0] BC_RXEN_r;
    reg [3:0] BC_TXD_r0,BC_TXD_r1;
    //上升沿信号
    wire BC_CLK_pos,BC_CS_pos;
    //闪烁灯计数器
    reg [24:0] cnt_led=0;
    //led闪烁灯信号
    reg led_flicker = 0;
    //数据匹配标志信号
    wire data_match_flag;
    //出错标志信号，error_cnt大于等于一
    reg error_flag = 0;

    //---------------------------打拍---------------------------------//
    always@(posedge SYSCLK)BC_CLK_r <= {BC_CLK_r[1:0],BC_CLK};
    assign BC_CLK_pos = ~BC_CLK_r[2] && BC_CLK_r[1];

    always@(posedge SYSCLK)BC_CS_r <= {BC_CS_r[1:0],BC_CS};
    assign BC_CS_pos = ~BC_CS_r[2] && BC_CS_r[1];

    always@(posedge SYSCLK)BC_RXEN_r <= {BC_RXEN_r[0],BC_RXEN};

    always@(posedge SYSCLK)begin
        BC_TXD_r0 <= BC_TXD;
        // BC_TXD_r1 <= BC_TXD_r0;
    end

    //---------------------------数据捕获逻辑-------------------------------//
    //计数器生成
    always @(posedge SYSCLK) begin
        if(add_flag_cnt)begin
            if(end_flag_cnt || BC_CS_pos)
                cnt <= 0;
            else
                cnt <= cnt + 1;
        end
    end

    assign add_flag_cnt = (BC_CS_r[1] ~^ BC_RXEN_r[1]) && BC_CLK_pos;
    assign end_flag_cnt = add_flag_cnt && cnt == 116 - 1;

    //锁存组id
    always@(posedge SYSCLK)begin
        if(cnt == 0 && add_flag_cnt)
            group_id <= BC_TXD;
    end

    //接收数据
    always@(posedge SYSCLK)begin
        if(add_flag_cnt && cnt > 9)
            data_g_now <= {{data_g_now[422:318],BC_TXD_r0[3]},{data_g_now[316:212],BC_TXD_r0[2]},{data_g_now[210:106],BC_TXD_r0[1]},{data_g_now[104:0],BC_TXD_r0[0]}};
    end
    //生成组数据有效标志信号
    always@(posedge SYSCLK)begin
        if(end_flag_cnt)
            group_data_valid = 1;
        else 
            group_data_valid = 0;
    end

    //上电latch一次组数据
    wire latch_valid;
    assign latch_valid = group_data_valid && group_id == 0 && latch_time == 0;
    always@(posedge SYSCLK)begin
        if(latch_valid)begin
            latch_time <= 1;
            data_g_latch <= data_g_now;
        end
    end

    //-----------------数据比较-------------------//
    //错误标志生成
    assign data_match_flag = data_g_now == 424'h1555555555555555555555555545555555555555555555555555515555555555555555555555555455555555555555555555555555;
    always@(posedge SYSCLK)begin
        if(group_data_valid && latch_time == 1)begin
            if(!data_match_flag)
                error_flag <= 1;
            else
                error_flag <= error_flag;
        end
    end

    //闪烁灯生成
    always@(posedge SYSCLK)begin
        if(cnt_led == 12_500_000 - 1)
            cnt_led <= 0;
        else
            cnt_led <= cnt_led + 1;
    end
    always@(posedge SYSCLK)begin
        if(cnt_led == 12_500_000 - 1)
            led_flicker <= ~led_flicker;
        else
            led_flicker <= led_flicker;
    end

    //LED逻辑输出
    assign LED = error_flag ? 1 : led_flicker;

    // integer file_handle;
    // initial begin
    //     wait(latch_time == 1);
    //     #200
    //     file_handle = $fopen("D:/code/verilog/cpld/output.txt", "w");
       
    //     $fwrite(file_handle, "%x\n",data_g_latch);
    //     $fclose(file_handle);
    // end

    endmodule
    
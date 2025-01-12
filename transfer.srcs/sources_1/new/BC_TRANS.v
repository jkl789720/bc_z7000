module BC_TRANS(
    input SYSCLK,	// 25MHz
    
    output reg          LED,
    
    input 				BC_CLK,
    input [3:0] 		BC_TXD,
    input 				BC_CS,//mode
    input 				BC_RXEN,//mode
    input 				BC_TXEN,//tr
    input 				BC_LATCH,//ld
    
    output 				BC_RXD
    );
//this is a differ in 30345's local
    //--------------变量定义---------------//
    //计数器
    reg [7:0] cnt = 0;
    wire add_flag_cnt,end_flag_cnt;
    //数据接收寄存器
    reg [104*4-1:0] data_g0;
    reg [104*4-1:0] data_g1;
    reg [104*4-1:0] data_g2;
    reg [104*4-1:0] data_g3;
    //数据校准、比较数据相关的信号
    wire [128*4-1:0] data_g0_ajst,compare_data_g0;
    wire [128*4-1:0] data_g1_ajst,compare_data_g1;
    wire [128*4-1:0] data_g2_ajst,compare_data_g2;
    wire [128*4-1:0] data_g3_ajst,compare_data_g3;
    //组ID信号
    reg [3:0] group_id;
    //打拍寄存信号
    reg [2:0] BC_CLK_r,BC_CS_r;
    reg [1:0] BC_RXEN_r;
    reg [3:0] BC_TXD_r0,BC_TXD_r1;
    //上升沿信号
    wire BC_CLK_pos,BC_CS_pos;
    //配置结束信号
    reg end_flag_congfig;

    //---------------------------打拍---------------------------------//
    always@(posedge SYSCLK)BC_CLK_r <= {BC_CLK_r[1:0],BC_CLK};
    assign BC_CLK_pos = ~BC_CLK_r[2] && BC_CLK_r[1];

    always@(posedge SYSCLK)BC_CS_r <= {BC_CS_r[1:0],BC_CS};
    assign BC_CS_pos = ~BC_CS_r[2] && BC_CS_r[1];

    always@(posedge SYSCLK)BC_RXEN_r <= {BC_RXEN_r[0],BC_RXEN};

    always@(posedge SYSCLK)begin
        BC_TXD_r0 <= BC_TXD;
        BC_TXD_r1 <= BC_TXD_r0;
    end

    //---------------------------数据捕获逻辑-------------------------------//
    //计数器生成
    always @(posedge SYSCLK) begin
        if(add_flag_cnt)begin
            if(end_flag_cnt)
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
        if(!(BC_CS_r[1] || BC_RXEN_r[1]) && BC_CLK_pos && cnt > 1)
            case(group_id)
            0:data_g0 <= {{data_g0[414:312],BC_TXD_r1[3]},{data_g0[310:208],BC_TXD_r1[2]},{data_g0[206:104],BC_TXD_r1[1]},{data_g0[102:0],BC_TXD_r1[0]}};
            1:data_g1 <= {{data_g1[414:312],BC_TXD_r1[3]},{data_g1[310:208],BC_TXD_r1[2]},{data_g1[206:104],BC_TXD_r1[1]},{data_g1[102:0],BC_TXD_r1[0]}};
            2:data_g2 <= {{data_g2[414:312],BC_TXD_r1[3]},{data_g2[310:208],BC_TXD_r1[2]},{data_g2[206:104],BC_TXD_r1[1]},{data_g2[102:0],BC_TXD_r1[0]}};
            3:data_g3 <= {{data_g3[414:312],BC_TXD_r1[3]},{data_g3[310:208],BC_TXD_r1[2]},{data_g3[206:104],BC_TXD_r1[1]},{data_g3[102:0],BC_TXD_r1[0]}};
            endcase
    end

    //数据移位到32bit对齐，生成基准数据
    genvar kk;
    generate
        for(kk = 0;kk < 16;kk = kk + 1)begin:blk
            assign data_g0_ajst[(kk+1)*32-1:kk*32] = {6'b0,data_g0[(kk+1)*26-1:kk*26]};
            assign data_g1_ajst[(kk+1)*32-1:kk*32] = {6'b0,data_g1[(kk+1)*26-1:kk*26]};
            assign data_g2_ajst[(kk+1)*32-1:kk*32] = {6'b0,data_g2[(kk+1)*26-1:kk*26]};
            assign data_g3_ajst[(kk+1)*32-1:kk*32] = {6'b0,data_g3[(kk+1)*26-1:kk*26]};

            assign compare_data_g0[(kk+1)*32-1:kk*32] = kk;
            assign compare_data_g1[(kk+1)*32-1:kk*32] = kk + 16;
            assign compare_data_g2[(kk+1)*32-1:kk*32] = kk + 32;
            assign compare_data_g3[(kk+1)*32-1:kk*32] = kk + 48;

        end
    endgenerate

    // integer file_handle;
    // initial begin
    //     #100
    //     file_handle = $fopen("D:/code/verilog/cpld/output.txt", "w");
       
    //     $fwrite(file_handle, "%x\n",compare_data_g0);
    //     $fwrite(file_handle, "%x\n",compare_data_g1);
    //     $fwrite(file_handle, "%x\n",compare_data_g2);
    //     $fwrite(file_handle, "%x\n",compare_data_g3);
    //     $fclose(file_handle);
    // end
    //生成结束的标志信号
    always@(posedge SYSCLK)begin
        if(end_flag_cnt && group_id == 3)
            end_flag_congfig = 1;
        else 
            end_flag_congfig = 0;
    end

    //每一组开始的时候清零，全部数据发完校验
    wire right_flag;
    // always@(posedge SYSCLK)begin
    //     if(add_flag_cnt && group_id == 0)
    //         LED <= 1;
    //     else if(end_flag_congfig)begin
    //         if(right_flag)
    //             LED <= 0;
    //         else
    //             LED <= 1;
    //     end
    //     else
    //         LED <= LED;
    // end

    always@(posedge SYSCLK)begin
        if(add_flag_cnt && group_id == 0)
            LED <= 1;
        else if(end_flag_congfig)begin
            if(right_flag)
                LED <= 0;
            else
                LED <= 1;
        end
        else
            LED <= LED;
    end

    assign right_flag = data_g0_ajst == 512'h0000000f0000000e0000000d0000000c0000000b0000000a00000009000000080000000700000006000000050000000400000003000000020000000100000000 &&
                        data_g1_ajst == 512'h0000001f0000001e0000001d0000001c0000001b0000001a00000019000000180000001700000016000000150000001400000013000000120000001100000010 && 
                        data_g2_ajst == 512'h0000002f0000002e0000002d0000002c0000002b0000002a00000029000000280000002700000026000000250000002400000023000000220000002100000020 && 
                        data_g3_ajst == 512'h0000003f0000003e0000003d0000003c0000003b0000003a00000039000000380000003700000036000000350000003400000033000000320000003100000030;

    endmodule
    
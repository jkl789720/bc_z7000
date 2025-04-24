module bc_mode#(
    parameter DWIDTH        = 4  ,
    parameter EXPAND_PERIOD = 5
)(
input       sys_clk    ,
input       sys_rst    ,

input       prf_in     ,       

input       tr_en      ,

input [3:0] bc_mode    ,
input       sel_param  ,

input       image_start,

input [15:0] receive_period,


output reg  trt_o_p_0  ,//v0
output reg  trr_o_p_0  ,//v0
output reg  trt_o_p_1  ,//v1
output reg  trr_o_p_1  ,//v1
output reg  trt_o_p_2  ,//h0
output reg  trr_o_p_2  ,//h0
output reg  trt_o_p_3  ,//h1
output reg  trr_o_p_3   //h1

);

reg [2:0] prf_dff;
wire prf_pos;
reg [2:0] image_start_dff;
wire image_start_pos;
reg cnt_prf;
reg [1:0] sel_dff;
wire trt_o;
wire trr_o;
//----------------------------------//

always@(posedge sys_clk)begin
    if(sys_rst)
        prf_dff <= 0;
    else
        prf_dff <= {prf_dff[1:0],prf_in};
end
assign prf_pos = ~prf_dff[2] && prf_dff[1];


always@(posedge sys_clk)begin
    if(sys_rst)
        image_start_dff <= 0;
    else
        image_start_dff <= {image_start_dff[1:0],image_start};
end

assign image_start_pos = (~image_start_dff[2]) && image_start_dff[1];


always @(posedge sys_clk) begin
    if(sys_rst)
        cnt_prf <= 0;//2024/12/24改动 初始化设置为0，这样第一个prf计数器递增为1，模式6，7，8才能按照需求出信号
    else if(image_start_pos)
        cnt_prf <= 0;
    else if(prf_pos)
        cnt_prf <= cnt_prf + 1;
end


always @(posedge sys_clk) begin
    if(sys_rst)
        sel_dff <= 0;
    else
        sel_dff <= {sel_dff[0],sel_param};
end

always @(posedge sys_clk) begin
    if(sys_rst)begin
        trt_o_p_0 = 1 ;
        trr_o_p_0 = 0 ;
        trt_o_p_1 = 1 ;
        trr_o_p_1 = 0 ;
        trt_o_p_2 = 1 ;
        trr_o_p_2 = 0 ;
        trt_o_p_3 = 1 ;
        trr_o_p_3 = 0 ;
    end
    else begin
        case (bc_mode)
            0: begin
                trt_o_p_0 = trt_o ;
                trr_o_p_0 = trr_o ;
                trt_o_p_1 = trt_o ;
                trr_o_p_1 = trr_o ;

                trt_o_p_2 = trt_o ;
                trr_o_p_2 = trr_o ;
                trt_o_p_3 = trt_o ;
                trr_o_p_3 = trr_o ;
            end
            1: begin
                //2024/12/19改动 PS给HH(sel == 0)出信号1  PS给VV(sel == 1)出信号0  0:h 1:v
                trt_o_p_0 = trt_o;//v
                trr_o_p_0 = sel_dff[1] && trr_o;
                trt_o_p_1 = trt_o;
                trr_o_p_1 = sel_dff[1] && trr_o;

                trt_o_p_2 = trt_o;//h
                trr_o_p_2 = (sel_dff[1] == 0 ) && trr_o ;
                trt_o_p_3 = trt_o;
                trr_o_p_3 = (sel_dff[1] == 0) &&  trr_o ;
            end
            2: begin//保留，后续补全
                //2025/02/20改动 PS给HH(sel == 0)出信号2  PS给VV(sel == 1)出信号0      0:h 1:v
                trt_o_p_0 = trt_o;//v
                trr_o_p_0 = sel_dff[1] && trr_o ;
                trt_o_p_1 = trt_o ;
                trr_o_p_1 = 0 ;

                trt_o_p_2 = trt_o;//h
                trr_o_p_2 = (sel_dff[1] == 0) && trr_o ;
                trt_o_p_3 = trt_o ;
                trr_o_p_3 = 0 ;
            end
            // 3: begin
            //     trt_o_p_0 = 1 ;
            //     trr_o_p_0 = 0 ;
            //     trt_o_p_1 = trt_o ;
            //     trr_o_p_1 = trr_o ;

            //     trt_o_p_2 = 1 ;
            //     trr_o_p_2 = 0 ;
            //     trt_o_p_3 = 1 ;
            //     trr_o_p_3 = 0 ;
            // end
            // 4: begin
            //     trt_o_p_0 = trt_o ;
            //     trr_o_p_0 = trr_o ;
            //     trt_o_p_1 = trt_o ;
            //     trr_o_p_1 = trr_o ;

            //     trt_o_p_2 = 1 ;
            //     trr_o_p_2 = 0 ;
            //     trt_o_p_3 = 1 ;
            //     trr_o_p_3 = 0 ;
            // end
            // 5: begin//详细待定
            //     trt_o_p_0 = 1 ;
            //     trr_o_p_0 = 0 ;
            //     trt_o_p_1 = trt_o ;
            //     trr_o_p_1 = trr_o ;

            //     trt_o_p_2 = 1 ;
            //     trr_o_p_2 = 0 ;
            //     trt_o_p_3 = 1 ;
            //     trr_o_p_3 = 0 ;
            // end
            // 6: begin
            //     trt_o_p_0 = trt_o;
            //     trr_o_p_0 = (cnt_prf == 1) && trr_o;

            //     trt_o_p_1 = trt_o;
            //     trr_o_p_1 = (cnt_prf == 0) && trr_o;

            //     trt_o_p_2 = 1 ;
            //     trr_o_p_2 = 0 ;

            //     trt_o_p_3 = 1 ;
            //     trr_o_p_3 = 0 ;
            // end
            7: begin
                trt_o_p_0 = trt_o;
                trr_o_p_0 = cnt_prf & trr_o;
                trt_o_p_1 = trt_o ;
                trr_o_p_1 = 0 ;

                trt_o_p_2 = trt_o ;
                trr_o_p_2 = (cnt_prf == 0) && trr_o ;
                trt_o_p_3 = trt_o ;
                trr_o_p_3 = 0 ;
            end
            8:begin
                trt_o_p_0 = trt_o ;//先出V再出H
                trr_o_p_0 = cnt_prf & trr_o; 
                trt_o_p_1 = trt_o ;
                trr_o_p_1 = cnt_prf & trr_o ;

                trt_o_p_2 = trt_o ;
                trr_o_p_2 = (cnt_prf == 0) & trr_o ;
                trt_o_p_3 = trt_o ;
                trr_o_p_3 = (cnt_prf == 0) & trr_o ;
            end
            default: begin
                trt_o_p_0 = 1 ;
                trr_o_p_0 = 0 ;
                trt_o_p_1 = 1 ;
                trr_o_p_1 = 0 ;

                trt_o_p_2 = 1 ;
                trr_o_p_2 = 0 ;
                trt_o_p_3 = 1 ;
                trr_o_p_3 = 0 ;
            end
        endcase
    end
end

single2double#(
    . DWIDTH        (DWIDTH       )  ,
    . EXPAND_PERIOD (EXPAND_PERIOD)
)u_single2double(
.  sys_clk        (sys_clk       ) ,
.  sys_rst        (sys_rst       ) ,
.  tr_en          (tr_en         ) ,
.  receive_period (receive_period) ,
.  trt_o          (trt_o         ) ,
.  trr_o          (trr_o         ) 
);

endmodule
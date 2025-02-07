`timescale 1ns / 1ps
module tb_ram_z7_check();


reg               sys_clk         ; 
reg               sys_rst         ; 
wire              rama_clk        ;
reg               rama_en         ;
reg               rama_wren       ;
reg  [31:0]       rama_addr       ;
reg  [15:0]       rama_din        ;
wire [31:0]       rama_dout       ;
wire [31:0]       check_fail_times;
reg [15:0] azi_angle;
reg [15:0] pitch_angle;

initial begin
    sys_clk     = 0;  
    rama_en     = 1;  
    rama_addr   = 0;
    rama_wren   = 0;
    rama_din    = 0;
    azi_angle   = 0;
    pitch_angle = 0;
    sys_rst     = 1;
    #30 sys_rst = 0;
    repeat(3721)begin
        //方位角
        @(posedge sys_clk);
        rama_addr   = 0;
        rama_din    = azi_angle;
        rama_wren   = 1;
        #21
        rama_wren   = 0;
        #200
        
        //俯仰角
        @(posedge sys_clk);
        rama_addr   = 1;
        rama_din    = pitch_angle;
        rama_wren   = 1;
        #21
        rama_wren   = 0;
        if(azi_angle == 60)
            azi_angle = 0;
        else
            azi_angle = azi_angle + 1;
        if(azi_angle == 0)begin
            if(pitch_angle == 60)
                pitch_angle = 0;
            else
                pitch_angle = pitch_angle + 1;
        end
        #(200);
    end
end

always #10 sys_clk = ~sys_clk;
assign rama_clk = sys_clk;

ram_z7_check u_ram_rfsoc_check(
. sys_clk          (sys_clk          )  , 
. sys_rst          (sys_rst          )  , 
. rama_clk         (rama_clk         )  ,
. rama_en          (rama_en          )  ,
. rama_wren        (rama_wren        )  ,
. rama_addr        (rama_addr        )  ,
. rama_din         (rama_din         )  ,
. rama_dout        (rama_dout        )  ,
. check_fail_times (check_fail_times )  
);


endmodule

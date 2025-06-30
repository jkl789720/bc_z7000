create_clock -period 20.000 -name sys_clk [get_ports sys_clk]
set_clock_groups -asynchronous -group [get_clocks sys_clk] -group [get_clocks clk_fpga_0]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]


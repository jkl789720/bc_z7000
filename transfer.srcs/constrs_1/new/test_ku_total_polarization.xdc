##sys
set_property PACKAGE_PIN U18 [get_ports {sys_clk}]
set_property PACKAGE_PIN W9 [get_ports {prf_pin_in}]

##uart_adjust_data
set_property PACKAGE_PIN U8 [get_ports BC_UART_ADJUST_RX]
set_property PACKAGE_PIN U9 [get_ports BC_UART_ADJUST_TX]

##--------------------bc-----------------------##
##---bc1----##
##g1
set_property PACKAGE_PIN D20 [get_ports {BC1_SEL[0] }  ]
set_property PACKAGE_PIN E17 [get_ports {BC1_CLK[0] }  ]
set_property PACKAGE_PIN D18 [get_ports {BC1_DATA[0]}  ]
set_property PACKAGE_PIN L20 [get_ports {BC1_DATA[1]}  ]
set_property PACKAGE_PIN E18 [get_ports {BC1_DATA[2]}  ]
set_property PACKAGE_PIN L19 [get_ports {BC1_DATA[3]}  ]
set_property PACKAGE_PIN F20 [get_ports {BC1_LD[0]  }  ]
set_property PACKAGE_PIN F19 [get_ports {BC1_TRT[0] }  ]
set_property PACKAGE_PIN E19 [get_ports {BC1_TRR[0] }  ]
##g2
set_property PACKAGE_PIN W15 [get_ports {BC1_SEL[1] }  ]
set_property PACKAGE_PIN U20 [get_ports {BC1_CLK[1] }  ]
set_property PACKAGE_PIN T16 [get_ports {BC1_DATA[4]}  ]
set_property PACKAGE_PIN U17 [get_ports {BC1_DATA[5]}  ]
set_property PACKAGE_PIN U19 [get_ports {BC1_DATA[6]}  ]
set_property PACKAGE_PIN T20 [get_ports {BC1_DATA[7]}  ]
set_property PACKAGE_PIN W20 [get_ports {BC1_LD[1]  }  ]
set_property PACKAGE_PIN P20 [get_ports {BC1_TRT[1] }  ]
set_property PACKAGE_PIN N20 [get_ports {BC1_TRR[1] }  ]
##g3
set_property PACKAGE_PIN J19 [get_ports {BC1_SEL[2] }  ]
set_property PACKAGE_PIN G20 [get_ports {BC1_CLK[2] }  ]
set_property PACKAGE_PIN C20 [get_ports {BC1_DATA[8]}  ]
set_property PACKAGE_PIN M17 [get_ports {BC1_DATA[9]}  ]
set_property PACKAGE_PIN B19 [get_ports {BC1_DATA[10]} ]
set_property PACKAGE_PIN M20 [get_ports {BC1_DATA[11]} ]
set_property PACKAGE_PIN A20 [get_ports {BC1_LD[2]  }  ]
set_property PACKAGE_PIN K19 [get_ports {BC1_TRT[2] }  ]
set_property PACKAGE_PIN B20 [get_ports {BC1_TRR[2] }  ]
##g3
set_property PACKAGE_PIN Y17 [get_ports {BC1_SEL[3] }  ]
set_property PACKAGE_PIN Y18 [get_ports {BC1_CLK[3] }  ]
set_property PACKAGE_PIN Y19 [get_ports {BC1_DATA[12]} ]
set_property PACKAGE_PIN W14 [get_ports {BC1_DATA[13]} ]
set_property PACKAGE_PIN V13 [get_ports {BC1_DATA[14]} ]
set_property PACKAGE_PIN U13 [get_ports {BC1_DATA[15]} ]
set_property PACKAGE_PIN V17 [get_ports {BC1_LD[3]  }  ]
set_property PACKAGE_PIN Y14 [get_ports {BC1_TRT[3] }  ]
set_property PACKAGE_PIN V18 [get_ports {BC1_TRR[3] }  ]
##---bc2----##
##g1
set_property PACKAGE_PIN J16 [get_ports {BC2_SEL[0] }  ]
set_property PACKAGE_PIN K18 [get_ports {BC2_CLK[0] }  ]
set_property PACKAGE_PIN H15 [get_ports {BC2_DATA[0]}  ]
set_property PACKAGE_PIN H20 [get_ports {BC2_DATA[1]}  ]
set_property PACKAGE_PIN G15 [get_ports {BC2_DATA[2]}  ]
set_property PACKAGE_PIN J20 [get_ports {BC2_DATA[3]}  ]
set_property PACKAGE_PIN N15 [get_ports {BC2_LD[0]  }  ]
set_property PACKAGE_PIN K17 [get_ports {BC2_TRT[0] }  ]
set_property PACKAGE_PIN N16 [get_ports {BC2_TRR[0] }  ]
##g2
set_property PACKAGE_PIN V16 [get_ports {BC2_SEL[1] }  ]
set_property PACKAGE_PIN N17 [get_ports {BC2_CLK[1] }  ]
set_property PACKAGE_PIN P19 [get_ports {BC2_DATA[4]}  ]
set_property PACKAGE_PIN U15 [get_ports {BC2_DATA[5]}  ]
set_property PACKAGE_PIN N18 [get_ports {BC2_DATA[6]}  ]
set_property PACKAGE_PIN T15 [get_ports {BC2_DATA[7]}  ]
set_property PACKAGE_PIN T14 [get_ports {BC2_LD[1]  }  ]
set_property PACKAGE_PIN P18 [get_ports {BC2_TRT[1] }  ]
set_property PACKAGE_PIN U14 [get_ports {BC2_TRR[1] }  ]
##g3
set_property PACKAGE_PIN P15 [get_ports {BC2_SEL[2] }  ]
set_property PACKAGE_PIN R17 [get_ports {BC2_CLK[2] }  ]
set_property PACKAGE_PIN R18 [get_ports {BC2_DATA[8]}  ]
set_property PACKAGE_PIN W19 [get_ports {BC2_DATA[9]}  ]
set_property PACKAGE_PIN W18 [get_ports {BC2_DATA[10]} ]
set_property PACKAGE_PIN V20 [get_ports {BC2_DATA[11]} ]
set_property PACKAGE_PIN W13 [get_ports {BC2_LD[2]  }  ]
set_property PACKAGE_PIN R16 [get_ports {BC2_TRT[2] }  ]
set_property PACKAGE_PIN V12 [get_ports {BC2_TRR[2] }  ]
##g4
set_property PACKAGE_PIN Y8  [get_ports {BC2_SEL[3] }  ]
set_property PACKAGE_PIN W6  [get_ports {BC2_CLK[3] }  ]
set_property PACKAGE_PIN V8  [get_ports {BC2_DATA[12]} ]
set_property PACKAGE_PIN Y12 [get_ports {BC2_DATA[13]} ]
set_property PACKAGE_PIN W8  [get_ports {BC2_DATA[14]} ]
set_property PACKAGE_PIN Y13 [get_ports {BC2_DATA[15]} ]
set_property PACKAGE_PIN V11 [get_ports {BC2_LD[3]  }  ]
set_property PACKAGE_PIN V6  [get_ports {BC2_TRT[3] }  ]
set_property PACKAGE_PIN Y9  [get_ports {BC2_TRR[3] }  ]

set_property PACKAGE_PIN G17 [get_ports {BC_RST     }  ]

##RFSOC

set_property PACKAGE_PIN V7   [get_ports {scl   }   ]
set_property PACKAGE_PIN Y6   [get_ports {cs_n   }   ]
set_property PACKAGE_PIN L14  [get_ports {mosi  }   ]

set_property PACKAGE_PIN L15  [get_ports {prf_rf_in }   ]
set_property PACKAGE_PIN Y7   [get_ports {tr_en     }   ]
set_property PACKAGE_PIN M15  [get_ports {bc_data_done}   ]


##--------------------IOSTANDARD-------------------//
##sys
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {prf_pin_in}]

##bc
set_property IOSTANDARD LVCMOS33 [get_ports BC*]

##RFSOC
set_property IOSTANDARD LVCMOS33 [get_ports {scl  }   ]
set_property IOSTANDARD LVCMOS33 [get_ports {cs_n }   ]
set_property IOSTANDARD LVCMOS33 [get_ports {mosi }   ]
set_property IOSTANDARD LVCMOS33 [get_ports {prf_rf_in }   ]
set_property IOSTANDARD LVCMOS33 [get_ports {tr_en     }   ]
set_property IOSTANDARD LVCMOS33 [get_ports {bc_data_done}   ]



##test
set_property PACKAGE_PIN W10  [get_ports valid        ]
set_property PACKAGE_PIN T5  [get_ports tr_en_o      ]
set_property PACKAGE_PIN U5  [get_ports bc_data_done_o      ]
set_property IOSTANDARD LVCMOS33 [get_ports valid   ]
set_property IOSTANDARD LVCMOS33 [get_ports tr_en_o     ]
set_property IOSTANDARD LVCMOS33 [get_ports bc_data_done_o     ]
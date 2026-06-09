set xsa "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/design_1_wrapper.xsa"
set bsp_dir "D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/board/vitis_bsp"

hsi open_hw_design $xsa
hsi generate_bsp -dir $bsp_dir -proc ps7_cortexa9_0 -os standalone -compile
puts "BSP compiled"

exit

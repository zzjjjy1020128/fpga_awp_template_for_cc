hsi open_hw_design D:/AGENT_WORK_SPACE_FOR_CLAUDE/fpga_awp_template/vivado/shift_2d_ax7010_260608/design_1_wrapper.xsa
puts "=== AXI STREAM PORTS ==="
set ports [hsi get_intf_ports -filter {NAME =~ *axis* || NAME =~ *AXIS*}]
foreach p $ports {
    set name [hsi get_property NAME $p]
    set mode [hsi get_property MODE $p]
    set nets [hsi get_intf_nets -of_objects $p]
    puts "  $name ($mode) nets=[llength $nets]"
    foreach net $nets {
        set pins [hsi get_intf_pins -of_objects $net]
        puts "    net: [hsi get_property NAME $net]"
        foreach pin $pins {
            set cell [hsi get_cells -of_objects $pin]
            puts "      [hsi get_property NAME $cell]/[hsi get_property MODE $pin]_[hsi get_property NAME $pin]"
        }
    }
}

puts ""
puts "=== DMA CELLS ==="
set cells [hsi get_cells -filter {NAME =~ *dma* || NAME =~ *axil* || NAME =~ *shift*}]
foreach c $cells {
    set name [hsi get_property NAME $c]
    set vlnv [hsi get_property VLNV $c]
    puts "  $name ($vlnv)"
}

exit

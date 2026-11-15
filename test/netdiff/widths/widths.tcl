# vivado -mode batch -source widths.tcl -tclargs <out.v>   (after gen_widths.py)
set out [expr {[llength $argv] ? [lindex $argv 0] : "widths_funcsim.v"}]
read_verilog [file join [file dirname [info script]] widths.v]
synth_design -top widths -part xcvu37p-fsvh2892-2L-e -mode out_of_context -flatten_hierarchy none
write_verilog -force -mode funcsim $out

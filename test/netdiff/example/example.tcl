# vivado -mode batch -source example.tcl -tclargs <out.v>
# Synthesizes example.v for an UltraScale+ part and writes its funcsim netlist.
set out [expr {[llength $argv] ? [lindex $argv 0] : "example_funcsim.v"}]
read_verilog [file join [file dirname [info script]] example.v]
synth_design -top example -part xczu7ev-ffvc1156-2-e -mode out_of_context
write_verilog -force -mode funcsim $out

# vivado -mode batch -source hw/usdr/build.tcl -tclargs OUT ROLE JOBS
# ROLE is explicit: ram, operational, or golden. No programming is performed.
if {$argc < 2 || $argc > 3} {error "Expected output directory, role, optional jobs"}
set output [file normalize [lindex $argv 0]]
set role [lindex $argv 1]
set jobs [expr {$argc == 3 ? [lindex $argv 2] : 4}]
if {$role ni {ram operational golden}} {error "Invalid bitstream role"}
if {![string is integer -strict $jobs] || $jobs < 1} {error "Invalid job count"}
set here [file dirname [file normalize [info script]]]
set usdr_project_dir "$output/project"
if {[file exists "$usdr_project_dir/usdr.xpr"]} {error "Output project exists; choose a new output directory"}
file mkdir $output
set manifest [open "$output/build.txt" w]
puts $manifest "Vivado: [version -short]"
puts $manifest "Part: xc7a35tcpg236-2"
puts $manifest "Role: $role"
puts $manifest "Interface: PCIe receive; original USB core and startup fallback retained"
puts $manifest "Source: $here"
puts $manifest "UTC: [clock format [clock seconds] -gmt 1 -format {%Y-%m-%dT%H:%M:%SZ}]"
close $manifest
source "$here/usdr_top.tcl"
set role_xdc "$output/role.xdc"
set f [open $role_xdc w]
if {$role ne "golden"} {
    puts $f {set_property BITSTREAM.CONFIG.NEXT_CONFIG_REBOOT DISABLE [current_design]}
    puts $f {set_property BITSTREAM.CONFIG.NEXT_CONFIG_ADDR 0 [current_design]}
    if {$role eq "ram"} {
        puts $f {set_property BITSTREAM.CONFIG.TIMER_CFG 0 [current_design]}
    } else {
        puts $f {set_property BITSTREAM.CONFIG.TIMER_CFG 0x4001fbd0 [current_design]}
    }
}
close $f
add_files -norecurse -fileset constrs_1 $role_xdc
set_property PROCESSING_ORDER LATE [get_files $role_xdc]
update_compile_order -fileset sources_1
report_ip_status -file "$output/ip_status.rpt"
generate_target all [get_ips]
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
open_run synth_1
report_utilization -hierarchical -file "$output/synth_utilization.rpt"
report_cdc -details -file "$output/synth_cdc.rpt"
check_timing -verbose -file "$output/synth_check_timing.rpt"
close_design
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
launch_runs impl_1 -to_step route_design -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
phys_opt_design -directive AggressiveExplore
report_timing_summary -delay_type min_max -report_unconstrained -file "$output/timing.rpt"
set skew_report [report_bus_skew -return_string -file "$output/bus_skew.rpt"]
report_cdc -details -file "$output/cdc.rpt"
report_drc -file "$output/drc.rpt"
report_methodology -file "$output/methodology.rpt"
report_utilization -hierarchical -file "$output/utilization.rpt"
report_clock_interaction -file "$output/clocks.rpt"
check_timing -verbose -file "$output/check_timing.rpt"
write_checkpoint "$output/usdr_${role}_routed.dcp"
# Keep failed timing results reviewable, but never label their bitstream ready.
foreach delay {max min} {
    set paths [get_timing_paths -delay_type $delay -max_paths 1]
    if {![llength $paths] || [get_property SLACK $paths] < 0} {error "$delay timing failed; inspect reports"}
}
if {[string match "*No bus skew constraints*" $skew_report] || [string match "*VIOLATED*" $skew_report]} {
    error "Gray CDC skew constraints missing or failed; inspect reports"
}
set final_timing [report_timing_summary -return_string]
if {[string match "*Timing constraints are not met*" $final_timing]} {
    error "Timing or pulse-width checks failed; inspect reports"
}
write_bitstream -bin_file "$output/usdr_${role}.bit"
puts "Built $output/usdr_${role}.bit. Review CDC, skew, DRC and unconstrained RF I/O before target use."

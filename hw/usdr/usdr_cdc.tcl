# Bound each registered Gray counter's skew independently. These assertions
# remain effective despite asynchronous clock false paths (AMD UG903).
# Query the synthesized netlist; fail rather than silently constrain no buses.
set gray_groups [dict create]
foreach reg [get_cells -hier -filter {NAME =~ */iclk_counter_gray_reg*}] {
    set name [get_property NAME $reg]
    set parent [file dirname $name]
    dict lappend gray_groups $parent $reg
}
set constrained 0
foreach parent [dict keys $gray_groups] {
    set regs [dict get $gray_groups $parent]
    if {[llength $regs] < 2} {continue}
    set from [get_pins -of_objects $regs -filter {REF_PIN_NAME == Q}]
    set endpoints [all_fanout -flat -endpoints_only -from $from]
    set sync_cells [get_cells -of_objects $endpoints -filter {ASYNC_REG == TRUE}]
    set to [get_pins -of_objects $sync_cells -filter {REF_PIN_NAME == D}]
    if {[llength $to] != [llength $from]} {
        error "Gray CDC endpoint mismatch at $parent: [llength $from] sources, [llength $to] synchronizer inputs"
    }
    set clocks [get_clocks -of_objects [get_pins -of_objects $regs -filter {REF_PIN_NAME == C}]]
    if {![llength $clocks]} {error "Unclocked Gray counter: $parent"}
    set bound 1.0e6
    foreach clk $clocks {set bound [expr {min($bound, [get_property PERIOD $clk])}]}
    # Half a source period leaves margin against overlapping successive changes.
    set_bus_skew [expr {$bound / 2.0}] -from $regs -to $to
    incr constrained
}
if {!$constrained} {error "No Gray CDC buses constrained"}
puts "Constrained $constrained Gray CDC buses"

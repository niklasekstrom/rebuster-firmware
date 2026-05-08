create_clock -name {CPUCLK} -period 40.000 -waveform {0.000 20.000} [get_ports {CPUCLK}]
create_clock -name {REBUSTER_OUTCLK} -period 40.000 -waveform {10.000 30.000}

derive_pll_clocks
derive_clock_uncertainty

# First-pass board timing budget for the Buster replacement pins.
#
# CPUCLK is the only external clock currently wired into the RTL timing model.
# REBUSTER_OUTCLK is a virtual board-side capture clock for outputs that are
# observed after the Buster pin transition, not on the same CPUCLK edge that
# launches internal state.
#
# The values below intentionally give TimeQuest full I/O coverage without
# pretending to replace per-signal validation against the 68030, Fat Buster, and
# Zorro timing diagrams.
set REBUSTER_INPUT_MAX  1.000
set REBUSTER_INPUT_MIN  1.000
set REBUSTER_OUTPUT_MAX -1.125
set REBUSTER_OUTPUT_MIN 0.000

set sync_inputs [remove_from_collection [all_inputs] [get_ports {CPUCLK}]]
set sync_inputs [remove_from_collection $sync_inputs [get_ports {RESET_n}]]
set sync_inputs [remove_from_collection $sync_inputs [get_ports {C7M}]]

set_false_path -from [get_ports {RESET_n}]
set_false_path -from [get_ports {C7M}]
set_false_path -from [get_registers {*reset_n_sync*}] -to [all_outputs]

set_input_delay -clock CPUCLK -max $REBUSTER_INPUT_MAX $sync_inputs
set_input_delay -clock CPUCLK -min $REBUSTER_INPUT_MIN $sync_inputs

set_output_delay -clock REBUSTER_OUTCLK -max $REBUSTER_OUTPUT_MAX [all_outputs]
set_output_delay -clock REBUSTER_OUTCLK -min $REBUSTER_OUTPUT_MIN [all_outputs]

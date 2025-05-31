create_clock -name {CPUCLK} -period 40.000 -waveform { 0.000 20.000 } [get_ports {CPUCLK}]
derive_pll_clocks

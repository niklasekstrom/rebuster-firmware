module rebuster_core(
    input clk100,

    input cpuclk_rising,
    input cpuclk_falling,

    input c7m_in,

    input reset_n_in,

    output br_n_out,
    output br_n_oe,

    input bg_n_in,

    input bgack_n_in,
    output bgack_n_out,
    output bgack_n_oe,

    input sbr_n_in,

    output sbg_n_out,
    output sbg_n_oe,

    input [4:0] ebr_n_in,

    output [4:0] ebg_n_out,
    output [4:0] ebg_n_oe,

    input ebgack_n_in,

    input own_n_in,
    output own_n_out,
    output own_n_oe,

    input addrz3_n_in,
    input memz2_n_in,
    input ioz2_n_in,

    output [2:0] aboe_n_out,
    output [2:0] aboe_n_oe,

    output [1:0] dboe_n_out,
    output [1:0] dboe_n_oe,

    output db16_n_out,
    output db16_n_oe,

    output d2p_n_out,
    output d2p_n_oe,

    output dblt_out,
    output dblt_oe,

    output bigz_n_out,
    output bigz_n_oe,

    input [3:0] a_in,
    output [3:0] a_out,
    output reg [3:0] a_oe,

    input [1:0] siz_in,
    output [1:0] siz_out,
    output reg [1:0] siz_oe,

    input rw_in,
    output rw_out,
    output reg rw_oe,

    input as_n_in,
    output as_n_out,
    output reg as_n_oe,

    input ds_n_in,
    output ds_n_out,
    output reg ds_n_oe,

    input [1:0] dsack_n_in,
    output [1:0] dsack_n_out,
    output [1:0] dsack_n_oe,

    input sterm_n_in,
    output sterm_n_out,
    output sterm_n_oe,

    input ciin_n_in,
    output ciin_n_out,
    output ciin_n_oe,

    input [3:1] ea_in,
    output [3:1] ea_out,
    output reg [3:1] ea_oe,

    input read_in,
    output read_out,
    output reg read_oe,

    input fcs_n_in,
    output fcs_n_out,
    output reg fcs_n_oe,

    input ccs_n_in,
    output ccs_n_out,
    output reg ccs_n_oe,

    input doe_in,
    output doe_out,
    output reg doe_oe,

    input [3:0] eds_n_in,
    output [3:0] eds_n_out,
    output reg [3:0] eds_n_oe,

    input dtack_n_in,
    output dtack_n_out,
    output dtack_n_oe,

    input cinh_n_in,
    output cinh_n_out,
    output cinh_n_oe,

    input mtcr_n_in
);

/*
Notes:
- Doesn't handle EBCLR_n. The pin is likely not used by any Z2 or Z3 boards.
- Doesn't handle Multiple Transfer Cycles.
- No handling of bus error (BERR/BINT).
- No handling of slave collisions (SLAVE).
- No handling of Read-Modify-Write cycles (RMC/LOCK).
*/

// Synchronize asynchronous signals.
reg [2:0] reset_n_sync;

always @(posedge clk100) begin
    reset_n_sync <= {reset_n_sync[1:0], reset_n_in};
end

// State for bus arbitration.
wire [1:0] bm_state;

// State for access handling.
wire access_state_idle;

bus_arbitration bus_arbitration(
    .clk100(clk100),

    .cpuclk_rising(cpuclk_rising),
    .cpuclk_falling(cpuclk_falling),

    .c7m_in(c7m_in),

    .reset_n_in(reset_n_in),

    .access_state_idle(access_state_idle),

    .bm_state(bm_state),

    .br_n_out(br_n_out),
    .br_n_oe(br_n_oe),

    .bg_n_in(bg_n_in),

    .bgack_n_in(bgack_n_in),
    .bgack_n_out(bgack_n_out),
    .bgack_n_oe(bgack_n_oe),

    .sbr_n_in(sbr_n_in),

    .sbg_n_out(sbg_n_out),
    .sbg_n_oe(sbg_n_oe),

    .ebr_n_in(ebr_n_in),

    .ebg_n_out(ebg_n_out),
    .ebg_n_oe(ebg_n_oe),

    .ebgack_n_in(ebgack_n_in),

    .own_n_in(own_n_in),
    .own_n_out(own_n_out),
    .own_n_oe(own_n_oe)
);

wire zorro_ctrl_oe = reset_n_sync[2] && own_n_in;
wire cpu_ctrl_oe = reset_n_sync[2] && !own_n_in;

always @(*) begin
    ea_oe <= {3{zorro_ctrl_oe}};
    read_oe <= zorro_ctrl_oe;
    doe_oe <= zorro_ctrl_oe;
    fcs_n_oe <= zorro_ctrl_oe;
    ccs_n_oe <= zorro_ctrl_oe;
    eds_n_oe <= {4{zorro_ctrl_oe}};

    a_oe <= {4{cpu_ctrl_oe}};
    siz_oe <= {2{cpu_ctrl_oe}};
    rw_oe <= cpu_ctrl_oe;
    as_n_oe <= cpu_ctrl_oe;
    ds_n_oe <= cpu_ctrl_oe;
end

access access(
    .clk100(clk100),

    .cpuclk_rising(cpuclk_rising),
    .cpuclk_falling(cpuclk_falling),

    .c7m_in(c7m_in),

    .reset_n_in(reset_n_in),

    .bm_state(bm_state),

    .access_state_idle(access_state_idle),

    .addrz3_n_in(addrz3_n_in),
    .memz2_n_in(memz2_n_in),
    .ioz2_n_in(ioz2_n_in),

    .aboe_n_out(aboe_n_out),
    .aboe_n_oe(aboe_n_oe),

    .dboe_n_out(dboe_n_out),
    .dboe_n_oe(dboe_n_oe),

    .db16_n_out(db16_n_out),
    .db16_n_oe(db16_n_oe),

    .d2p_n_out(d2p_n_out),
    .d2p_n_oe(d2p_n_oe),

    .dblt_out(dblt_out),
    .dblt_oe(dblt_oe),

    .bigz_n_out(bigz_n_out),
    .bigz_n_oe(bigz_n_oe),

    // CPU control.
    .a_in(a_in),
    .a_out(a_out),

    .siz_in(siz_in),
    .siz_out(siz_out),

    .rw_in(rw_in),
    .rw_out(rw_out),

    .as_n_in(as_n_in),
    .as_n_out(as_n_out),

    .ds_n_in(ds_n_in),
    .ds_n_out(ds_n_out),

    // CPU access termination.
    .dsack_n_in(dsack_n_in),
    .dsack_n_out(dsack_n_out),
    .dsack_n_oe(dsack_n_oe),

    .sterm_n_in(sterm_n_in),
    .sterm_n_out(sterm_n_out),
    .sterm_n_oe(sterm_n_oe),

    .ciin_n_in(ciin_n_in),
    .ciin_n_out(ciin_n_out),
    .ciin_n_oe(ciin_n_oe),

    // Zorro control.
    .ea_in(ea_in),
    .ea_out(ea_out),

    .read_in(read_in),
    .read_out(read_out),

    .fcs_n_in(fcs_n_in),
    .fcs_n_out(fcs_n_out),

    .ccs_n_in(ccs_n_in),
    .ccs_n_out(ccs_n_out),

    .doe_in(doe_in),
    .doe_out(doe_out),

    .eds_n_in(eds_n_in),
    .eds_n_out(eds_n_out),

    // Zorro access termination.
    .dtack_n_in(dtack_n_in),
    .dtack_n_out(dtack_n_out),
    .dtack_n_oe(dtack_n_oe),

    .cinh_n_in(cinh_n_in),
    .cinh_n_out(cinh_n_out),
    .cinh_n_oe(cinh_n_oe),

    .mtcr_n_in(mtcr_n_in)
);

endmodule

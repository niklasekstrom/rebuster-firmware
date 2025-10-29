/*
Written by Niklas Ekström, 2025-07-18.

This is an implementation of Buster, Level II.

References:
- [1] https://www.devili.iki.fi/mirrors/haynie/chips/buster/docs/buster2.pdf
- [2] https://www.lysator.liu.se/amiga/hard/guide/A4000Hardware.guide, section "Definitive Buster"
- [3] https://www.amigawiki.org/dnl/schematics/A3000.pdf#page=14
- [4] https://www.nxp.com/docs/en/reference-manual/MC68030UM-P1.pdf
- [5] http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node02C9.html
- [6] https://github.com/niklasekstrom/rebuster-firmware/blob/main/docs/buster-timings.md
*/
module rebuster_top(
    // The signal names are taken from:
    // https://www.amigawiki.org/dnl/schematics/A3000.pdf#page=14
    // https://www.devili.iki.fi/mirrors/haynie/chips/buster/docs/buster2.pdf#page=9

    // Clocks
    input CPUCLK,
    input C7M,

    // System reset
    input RESET_n,          // Reset, cannot be driven

    // Address decode, from U714 based on EAD[31:18]
    input ADDRZ3_n,         // Z3 Address Decode
    input MEMZ2_n,          // Z2 Mem Address Decode
    input IOZ2_n,           // Z2 IO Address Decode

    // Address bus buffers control
    output [2:0] ABOE_n,    // Address bus output enables
    inout OWN_n,            // Address bus direction, also driven by Z2 master

    // Data bus buffers control
    output [1:0] DBOE_n,    // Data bus output enables
    output D2P_n,           // Data bus direction, 0=zorro-to-cpu, 1=cpu-to-zorro
    output DBLT,            // Data Bus Latch

    // MC68030 bus interface
    // Cf.: https://www.nxp.com/docs/en/reference-manual/MC68030UM-P1.pdf#page=118
    inout [3:0] A,          // Address, low nybble
    inout [1:0] SIZ,        // Transfer Size
    inout RW,               // Read/Write
    inout AS_n,             // Address Strobe
    inout DS_n,             // Data Strobe

    inout [1:0] DSACK_n,    // Data Transfer and Size Acknowledge
    inout STERM_n,          // Synchronous Termination
    inout CIIN_n,           // Cache Inhibit In

    // Zorro interface
    // http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node02C9.html
    inout [3:1] EA,         // Zx Low address bits / Z3 LOCK_n
    inout READ,             // Zx Read/Write
    inout FCS_n,            // Z3 Full Cycle Strobe
    inout DOE,              // Zx Data Output Enable
    inout [3:0] EDS_n,      // Zx Data Strobes

    inout DTACK_n,          // Zx Data Acknowledge
    inout CINH_n,           // Z3 Cache Inhibit / Z2 OVR_n

    // -- Bus arbitration --

    // Bus arbitration signals to/from CPU
    output BR_n,            // Bus Request
    input BG_n,             // Bus Grant
    inout BGACK_n,          // Bus Grant Acknowledge

    // DMAC
    input SBR_n,            // DMAC Bus Request
    output SBG_n,           // DMAC Bus Grant

    // Zorro bus master control
    input [4:0] EBR_n,      // Zx Bus Request
    output [4:0] EBG_n      // Zx Bus Grant
);

wire cpuclk_in;
assign cpuclk_in = CPUCLK;

wire c7m_in;
assign c7m_in = C7M;

wire reset_n_in;
assign reset_n_in = RESET_n;

wire addrz3_n_in;
assign addrz3_n_in = ADDRZ3_n;

wire memz2_n_in;
assign memz2_n_in = MEMZ2_n;

wire ioz2_n_in;
assign ioz2_n_in = IOZ2_n;

wire [2:0] aboe_n_out;
wire [2:0] aboe_n_oe;
assign ABOE_n[2] = aboe_n_oe[2] ? aboe_n_out[2] : 1'bz;
assign ABOE_n[1] = aboe_n_oe[1] ? aboe_n_out[1] : 1'bz;
assign ABOE_n[0] = aboe_n_oe[0] ? aboe_n_out[0] : 1'bz;

wire own_n_in;
wire own_n_out;
wire own_n_oe;
assign own_n_in = OWN_n;
assign OWN_n = own_n_oe ? own_n_out : 1'bz;

wire [1:0] dboe_n_out;
wire [1:0] dboe_n_oe;
assign DBOE_n[1] = dboe_n_oe[1] ? dboe_n_out[1] : 1'bz;
assign DBOE_n[0] = dboe_n_oe[0] ? dboe_n_out[0] : 1'bz;

wire d2p_n_out;
wire d2p_n_oe;
assign D2P_n = d2p_n_oe ? d2p_n_out : 1'bz;

wire dblt_out;
wire dblt_oe;
assign DBLT = dblt_oe ? dblt_out : 1'bz;

wire [3:0] a_in;
wire [3:0] a_out;
wire [3:0] a_oe;
assign a_in = A;
assign A[3] = a_oe[3] ? a_out[3] : 1'bz;
assign A[2] = a_oe[2] ? a_out[2] : 1'bz;
assign A[1] = a_oe[1] ? a_out[1] : 1'bz;
assign A[0] = a_oe[0] ? a_out[0] : 1'bz;

wire [1:0] siz_in;
wire [1:0] siz_out;
wire [1:0] siz_oe;
assign siz_in = SIZ;
assign SIZ[1] = siz_oe[1] ? siz_out[1] : 1'bz;
assign SIZ[0] = siz_oe[0] ? siz_out[0] : 1'bz;

wire rw_in;
wire rw_out;
wire rw_oe;
assign rw_in = RW;
assign RW = rw_oe ? rw_out : 1'bz;

wire as_n_in;
wire as_n_out;
wire as_n_oe;
assign as_n_in = AS_n;
assign AS_n = as_n_oe ? as_n_out : 1'bz;

wire ds_n_in;
wire ds_n_out;
wire ds_n_oe;
assign ds_n_in = DS_n;
assign DS_n = ds_n_oe ? ds_n_out : 1'bz;

wire [1:0] dsack_n_in;
wire [1:0] dsack_n_out;
wire [1:0] dsack_n_oe;
assign dsack_n_in = DSACK_n;
assign DSACK_n[1] = dsack_n_oe[1] ? dsack_n_out[1] : 1'bz;
assign DSACK_n[0] = dsack_n_oe[0] ? dsack_n_out[0] : 1'bz;

wire sterm_n_in;
wire sterm_n_out;
wire sterm_n_oe;
assign sterm_n_in = STERM_n;
assign STERM_n = sterm_n_oe ? sterm_n_out : 1'bz;

wire ciin_n_in;
wire ciin_n_out;
wire ciin_n_oe;
assign ciin_n_in = CIIN_n;
assign CIIN_n = ciin_n_oe ? ciin_n_out : 1'bz;

wire [3:1] ea_in;
wire [3:1] ea_out;
wire [3:1] ea_oe;
assign ea_in = EA;
assign EA[3] = ea_oe[3] ? ea_out[3] : 1'bz;
assign EA[2] = ea_oe[2] ? ea_out[2] : 1'bz;
assign EA[1] = ea_oe[1] ? ea_out[1] : 1'bz;

wire read_in;
wire read_out;
wire read_oe;
assign read_in = READ;
assign READ = read_oe ? read_out : 1'bz;

wire fcs_n_in;
wire fcs_n_out;
wire fcs_n_oe;
assign fcs_n_in = FCS_n;
assign FCS_n = fcs_n_oe ? fcs_n_out : 1'bz;

wire doe_in;
wire doe_out;
wire doe_oe;
assign doe_in = DOE;
assign DOE = doe_oe ? doe_out : 1'bz;

wire [3:0] eds_n_in;
wire [3:0] eds_n_out;
wire [3:0] eds_n_oe;
assign eds_n_in = EDS_n;
assign EDS_n[3] = eds_n_oe[3] ? eds_n_out[3] : 1'bz;
assign EDS_n[2] = eds_n_oe[2] ? eds_n_out[2] : 1'bz;
assign EDS_n[1] = eds_n_oe[1] ? eds_n_out[1] : 1'bz;
assign EDS_n[0] = eds_n_oe[0] ? eds_n_out[0] : 1'bz;

wire dtack_n_in;
wire dtack_n_out;
wire dtack_n_oe;
assign dtack_n_in = DTACK_n;
assign DTACK_n = dtack_n_oe ? dtack_n_out : 1'bz;

wire cinh_n_in;
wire cinh_n_out;
wire cinh_n_oe;
assign cinh_n_in = CINH_n;
assign CINH_n = cinh_n_oe ? cinh_n_out : 1'bz;

wire br_n_out;
wire br_n_oe;
assign BR_n = br_n_oe ? br_n_out : 1'bz;

wire bg_n_in;
assign bg_n_in = BG_n;

wire bgack_n_in;
wire bgack_n_out;
wire bgack_n_oe;
assign bgack_n_in = BGACK_n;
assign BGACK_n = bgack_n_oe ? bgack_n_out : 1'bz;

wire sbr_n_in;
assign sbr_n_in = SBR_n;

wire sbg_n_out;
wire sbg_n_oe;
assign SBG_n = sbg_n_oe ? sbg_n_out : 1'bz;

wire [4:0] ebr_n_in;
assign ebr_n_in = EBR_n;

wire [4:0] ebg_n_out;
wire [4:0] ebg_n_oe;
assign EBG_n[4] = ebg_n_oe[4] ? ebg_n_out[4] : 1'bz;
assign EBG_n[3] = ebg_n_oe[3] ? ebg_n_out[3] : 1'bz;
assign EBG_n[2] = ebg_n_oe[2] ? ebg_n_out[2] : 1'bz;
assign EBG_n[1] = ebg_n_oe[1] ? ebg_n_out[1] : 1'bz;
assign EBG_n[0] = ebg_n_oe[0] ? ebg_n_out[0] : 1'bz;

// Logic to synchronize the clk100 clock to CPUCLK.
// Relies on the source synchronous mode of the PLL for this to work:
// https://www.intel.com/content/www/us/en/docs/programmable/683047/21-1/source-synchronous-mode.html
wire clk100;
wire clk100_inv;

mypll mypll_inst(
    .inclk0(CPUCLK),
    .c0(clk100),
    .c1(clk100_inv)
);

reg [1:0] cpuclk_sync;

always @(posedge clk100_inv) begin
    cpuclk_sync <= {cpuclk_sync[0], CPUCLK};
end

reg [1:0] cpuclk_phase;

always @(posedge clk100) begin
    case (cpuclk_sync)
        2'b00: cpuclk_phase <= 2'd0;
        2'b01: cpuclk_phase <= 2'd1;
        2'b11: cpuclk_phase <= 2'd2;
        2'b10: cpuclk_phase <= 2'd3;
    endcase
end

wire cpuclk_rising = cpuclk_phase == 2'd3;
wire clk90_rising = cpuclk_phase == 2'd0;
wire cpuclk_falling = cpuclk_phase == 2'd1;
wire clk90_falling = cpuclk_phase == 2'd2;

rebuster_core core(
    .clk100(clk100),

    .cpuclk_rising(cpuclk_rising),
    .cpuclk_falling(cpuclk_falling),

    .cpuclk_in(cpuclk_in),

    .c7m_in(c7m_in),

    .reset_n_in(reset_n_in),

    .addrz3_n_in(addrz3_n_in),

    .memz2_n_in(memz2_n_in),

    .ioz2_n_in(ioz2_n_in),

    .aboe_n_out(aboe_n_out),
    .aboe_n_oe(aboe_n_oe),

    .own_n_in(own_n_in),
    .own_n_out(own_n_out),
    .own_n_oe(own_n_oe),

    .dboe_n_out(dboe_n_out),
    .dboe_n_oe(dboe_n_oe),

    .d2p_n_out(d2p_n_out),
    .d2p_n_oe(d2p_n_oe),

    .dblt_out(dblt_out),
    .dblt_oe(dblt_oe),

    .a_in(a_in),
    .a_out(a_out),
    .a_oe(a_oe),

    .siz_in(siz_in),
    .siz_out(siz_out),
    .siz_oe(siz_oe),

    .rw_in(rw_in),
    .rw_out(rw_out),
    .rw_oe(rw_oe),

    .as_n_in(as_n_in),
    .as_n_out(as_n_out),
    .as_n_oe(as_n_oe),

    .ds_n_in(ds_n_in),
    .ds_n_out(ds_n_out),
    .ds_n_oe(ds_n_oe),

    .dsack_n_in(dsack_n_in),
    .dsack_n_out(dsack_n_out),
    .dsack_n_oe(dsack_n_oe),

    .sterm_n_in(sterm_n_in),
    .sterm_n_out(sterm_n_out),
    .sterm_n_oe(sterm_n_oe),

    .ciin_n_in(ciin_n_in),
    .ciin_n_out(ciin_n_out),
    .ciin_n_oe(ciin_n_oe),

    .ea_in(ea_in),
    .ea_out(ea_out),
    .ea_oe(ea_oe),

    .read_in(read_in),
    .read_out(read_out),
    .read_oe(read_oe),

    .fcs_n_in(fcs_n_in),
    .fcs_n_out(fcs_n_out),
    .fcs_n_oe(fcs_n_oe),

    .doe_in(doe_in),
    .doe_out(doe_out),
    .doe_oe(doe_oe),

    .eds_n_in(eds_n_in),
    .eds_n_out(eds_n_out),
    .eds_n_oe(eds_n_oe),

    .dtack_n_in(dtack_n_in),
    .dtack_n_out(dtack_n_out),
    .dtack_n_oe(dtack_n_oe),

    .cinh_n_in(cinh_n_in),
    .cinh_n_out(cinh_n_out),
    .cinh_n_oe(cinh_n_oe),

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
    .ebg_n_oe(ebg_n_oe)
);

endmodule

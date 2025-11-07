module rebuster_core(
    input clk100,

    input cpuclk_rising,
    input cpuclk_falling,

    input c7m_in,

    input reset_n_in,

    input addrz3_n_in,
    input memz2_n_in,
    input ioz2_n_in,

    output [2:0] aboe_n_out,
    output [2:0] aboe_n_oe,

    input own_n_in,
    output reg own_n_out,
    output reg own_n_oe,

    output [1:0] dboe_n_out,
    output [1:0] dboe_n_oe,

    output db16_n_out,
    output db16_n_oe,

    output d2p_n_out,
    output d2p_n_oe,

    output dblt_out,
    output dblt_oe,

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

    output bigz_n_out,
    output bigz_n_oe,

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

    input mtcr_n_in,

    output reg br_n_out,
    output reg br_n_oe,

    input bg_n_in,

    input bgack_n_in,
    output reg bgack_n_out,
    output reg bgack_n_oe,

    input sbr_n_in,

    output reg sbg_n_out,
    output reg sbg_n_oe,

    input [4:0] ebr_n_in,

    output reg [4:0] ebg_n_out,
    output reg [4:0] ebg_n_oe,

    input ebgack_n_in
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
reg [2:0] c7m_sync;
reg [2:0] reset_n_sync;

reg [2:0] fcs_n_sync;
reg [2:0] ccs_n_sync;
reg [2:0] dtack_n_sync;
reg [2:0] all_eds_n_sync;
reg [3:0] all_dsack_n_sync;

reg [2:0] sbr_n_sync;
reg [2:0] bg_n_sync;
reg [2:0] bgack_n_sync;
reg [2:0] ebgack_n_sync;
reg [2:0] own_n_sync;

always @(posedge clk100) begin
    c7m_sync <= {c7m_sync[1:0], c7m_in};
    reset_n_sync <= {reset_n_sync[1:0], reset_n_in};

    fcs_n_sync <= {fcs_n_sync[1:0], fcs_n_in};
    ccs_n_sync <= {ccs_n_sync[1:0], ccs_n_in};
    dtack_n_sync <= {dtack_n_sync[1:0], dtack_n_in};
    all_eds_n_sync <= {all_eds_n_sync[1:0], &eds_n_in};
    all_dsack_n_sync <= {all_dsack_n_sync[2:0], &dsack_n_in};

    sbr_n_sync <= {sbr_n_sync[1:0], sbr_n_in};
    bg_n_sync <= {bg_n_sync[1:0], bg_n_in};
    bgack_n_sync <= {bgack_n_sync[1:0], bgack_n_in};
    ebgack_n_sync <= {ebgack_n_sync[1:0], ebgack_n_in};
    own_n_sync <= {own_n_sync[1:0], own_n_in};
end

wire c7m_rising = c7m_sync[2:1] == 2'b01;
wire c7m_falling = c7m_sync[2:1] == 2'b10;

reg [4:0] ebr_n_sync_0;
reg [4:0] ebr_n_sync_1;

reg [4:0] ebr_n_falling_0;
reg [4:0] ebr_n_falling_1;

always @(posedge clk100) begin
    ebr_n_sync_1 <= ebr_n_sync_0;
    ebr_n_sync_0 <= ebr_n_in;

    if (c7m_falling) begin
        ebr_n_falling_1 <= ebr_n_falling_0;
        ebr_n_falling_0 <= ebr_n_sync_1;
    end
end

// State for bus arbitration.

localparam BM_CPU = 2'd0;
localparam BM_Z3 = 2'd2;
localparam BM_Z2 = 2'd3;

reg [1:0] bm_state;

localparam BA_NONE = 2'd0;
localparam BA_SDMAC = 2'd1;
localparam BA_Z3 = 2'd2;
localparam BA_Z2 = 2'd3;

reg [1:0] ba_state;

reg [2:0] z3_ba_state;

// A pulse is if EBR is high, low, high on subsequent falling C7M edges.
wire [4:0] z3_register_pulse = ebr_n_falling_1 & ~ebr_n_falling_0 & ebr_n_sync_1;

reg [4:0] z3_requests;
reg [4:0] z3_grant;
wire [4:0] next_z3_grant;

round_robin_priority_encoder z3_rrpe(
    .requests(z3_requests),
    .previous_grant(z3_grant),
    .grant(next_z3_grant)
);

reg [1:0] z2_ba_state;

// EBR asserted on two consecutive falling C7M edges means Z2 board is requesting.
wire [4:0] z2_requests = ~ebr_n_falling_1 & ~ebr_n_falling_0;
reg [4:0] z2_grant;
wire [4:0] next_z2_grant;

round_robin_priority_encoder z2_rrpe(
    .requests(z2_requests),
    .previous_grant(z2_grant),
    .grant(next_z2_grant)
);

reg connect_busses;
reg bus_direction; // 0=cpu-to-zorro, 1=zorro-to-cpu

wire zorro_ctrl_oe = connect_busses && bus_direction == 1'b0;
wire cpu_ctrl_oe = connect_busses && bus_direction == 1'b1;

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

// State for access handling.
wire access_state_idle;

access access(
    .clk100(clk100),

    .cpuclk_rising(cpuclk_rising),
    .cpuclk_falling(cpuclk_falling),

    .c7m_in(c7m_in),

    .reset_n_in(reset_n_in),

    .bm_state(bm_state),

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
    .a_out(a_out),
    .siz_out(siz_out),
    .rw_out(rw_out),
    .as_n_out(as_n_out),
    .ds_n_out(ds_n_out),

    // CPU access termination.
    .dsack_n_out(dsack_n_out),
    .dsack_n_oe(dsack_n_oe),

    .sterm_n_out(sterm_n_out),
    .sterm_n_oe(sterm_n_oe),

    .ciin_n_out(ciin_n_out),
    .ciin_n_oe(ciin_n_oe),

    // Zorro control.
    .ea_out(ea_out),
    .read_out(read_out),
    .fcs_n_out(fcs_n_out),
    .ccs_n_out(ccs_n_out),
    .doe_out(doe_out),
    .eds_n_out(eds_n_out),

    // Zorro access termination.
    .dtack_n_out(dtack_n_out),
    .dtack_n_oe(dtack_n_oe),

    .cinh_n_out(cinh_n_out),
    .cinh_n_oe(cinh_n_oe),

    .access_state_idle(access_state_idle),

    .addrz3_n_in(addrz3_n_in),
    .memz2_n_in(memz2_n_in),
    .ioz2_n_in(ioz2_n_in),

    .a_in(a_in),
    .siz_in(siz_in),
    .rw_in(rw_in),
    .as_n_in(as_n_in),
    .ds_n_in(ds_n_in),

    .dsack_n_in(dsack_n_in),
    .sterm_n_in(sterm_n_in),
    .ciin_n_in(ciin_n_in),

    .ea_in(ea_in),
    .read_in(read_in),
    .fcs_n_in(fcs_n_in),
    .ccs_n_in(ccs_n_in),
    .doe_in(doe_in),
    .eds_n_in(eds_n_in),

    .dtack_n_in(dtack_n_in),
    .cinh_n_in(cinh_n_in),

    .mtcr_n_in(mtcr_n_in)
);

// All signals are controlled sequentially.

// Bus arbitration state machine.

always @(posedge clk100) begin

    if (!reset_n_sync[1]) begin // In reset.
        // Output pins.
        own_n_out <= 1'b1;
        own_n_oe <= 1'b0;

        br_n_out <= 1'b0;
        br_n_oe <= 1'b0;

        bgack_n_out <= 1'b1;
        bgack_n_oe <= 1'b0;

        sbg_n_out <= 1'b1;
        sbg_n_oe <= 1'b0;

        ebg_n_out <= 5'b11111;
        ebg_n_oe <= 5'b00000;

        // Internal state.
        bm_state <= BM_CPU;

        ba_state <= BA_NONE;

        z3_ba_state <= 3'd0;

        z3_requests <= 5'b0;
        z3_grant <= 5'b0;

        z2_ba_state <= 2'd0;

        z2_grant <= 5'b0;

        connect_busses <= 1'b0;
        bus_direction <= 1'b0;

    end else if (!reset_n_sync[2]) begin // Coming out of reset.

        sbg_n_oe <= 1'b1;

        ebg_n_oe <= 5'b11111;

        connect_busses <= 1'b1;

    end else begin // Normal operations.

        // Handle Z3 register/deregister pulses.
        if (c7m_falling) begin
            z3_requests <= z3_requests ^ z3_register_pulse;
        end

        // Logic for multiplexing bus arbitration.
        case (ba_state)
            BA_NONE: begin
                if (!sbr_n_sync[1]) begin
                    //br_n_out <= 1'b0;
                    br_n_oe <= 1'b1;
                    ba_state <= BA_SDMAC;
                end else if (|z3_requests) begin
                    //br_n_out <= 1'b0;
                    br_n_oe <= 1'b1;
                    ba_state <= BA_Z3;
                end else if (|z2_requests) begin
                    //br_n_out <= 1'b0;
                    br_n_oe <= 1'b1;
                    ba_state <= BA_Z2;
                end
            end

            BA_SDMAC: begin
                br_n_oe <= !sbr_n_sync[1];
                sbg_n_out <= bg_n_sync[1];

                if (sbr_n_sync[1] && bgack_n_sync[1]) begin
                    ba_state <= BA_NONE;
                end
            end

            BA_Z3: begin
                case (z3_ba_state)
                    3'd0: begin
                        if (!bg_n_sync[1] && bgack_n_sync[1] && access_state_idle) begin
                            bm_state <= BM_Z3;

                            bus_direction <= 1'b1;

                            // Switch direction of address buffers.
                            own_n_out <= 1'b0;
                            own_n_oe <= 1'b1;

                            bgack_n_out <= 1'b0;
                            bgack_n_oe <= 1'b1;

                            z3_ba_state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (cpuclk_falling) begin
                            z3_grant <= next_z3_grant;
                            ebg_n_out <= ~next_z3_grant;

                            z3_ba_state <= 2'd2;
                        end
                    end
                    3'd2: begin
                        if (cpuclk_rising) begin
                            br_n_oe <= 1'b0;

                            z3_ba_state <= 2'd3;
                        end
                    end
                    3'd3: begin
                        // Let board do as many requests as it pleases.
                        // Eventually it'll run out of data to copy and
                        // then it returns bus mastery to the cpu.
                        if (!(|(z3_requests & z3_grant))) begin
                            ebg_n_out <= 5'b11111;
                            z3_ba_state <= 3'd4;
                        end
                    end
                    3'd4: begin
                        if (access_state_idle && cpuclk_rising) begin
                            z3_ba_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        if (cpuclk_rising) begin
                            bm_state <= BM_CPU;

                            bus_direction <= 1'b0;

                            // Switch direction of address buffers.
                            own_n_out <= 1'b1;
                            own_n_oe <= 1'b1;

                            // Negating BGACK at the same time as OWN is not a
                            // problem, because the CPU will synchronize BGACK
                            // before using it, so there is sufficient time for
                            // the latch to switch direction.
                            bgack_n_out <= 1'b1;
                            bgack_n_oe <= 1'b1;

                            z3_ba_state <= 3'd6;
                        end
                    end
                    3'd6: begin
                        own_n_oe <= 1'b0;
                        bgack_n_oe <= 1'b0;

                        z3_ba_state <= 3'd0;
                        ba_state <= BA_NONE;
                    end
                endcase
            end

            BA_Z2: begin
                case (z2_ba_state)
                    2'd0: begin
                        // TODO: Borde kanske vara bättre att använda clk90_falling här?
                        // För när man synkar bg_n så är det då den är tillgänglig, tror jag.
                        if (!bg_n_sync[1] && bgack_n_sync[1] && access_state_idle && cpuclk_rising) begin
                            bm_state <= BM_Z2;

                            bus_direction <= 1'b1;

                            bgack_n_out <= 1'b0;
                            bgack_n_oe <= 1'b1;

                            z2_grant <= next_z2_grant;
                            ebg_n_out <= ~next_z2_grant;

                            z2_ba_state <= 2'd1;
                        end
                    end
                    2'd1: begin
                        if (cpuclk_rising) begin
                            br_n_oe <= 1'b0;
                        end

                        // Negate EBG when EBR is negated.
                        ebg_n_out <= ebr_n_sync_1 | ~z2_grant;

                        if (ebgack_n_sync[1] && (&ebg_n_out) && own_n_sync[1]) begin
                            z2_ba_state <= 2'd2;
                        end
                    end
                    2'd2: begin
                        if (cpuclk_rising) begin
                            bm_state <= BM_CPU;

                            bus_direction <= 1'b0;

                            // Negate BGACK so that CPU resumes bus mastering.
                            bgack_n_out <= 1'b1;
                            bgack_n_oe <= 1'b1;

                            z2_ba_state <= 2'd3;
                        end
                    end
                    2'd3: begin
                        bgack_n_oe <= 1'b0;

                        z2_ba_state <= 2'd0;
                        ba_state <= BA_NONE;
                    end
                endcase
            end
        endcase
    end
end

endmodule

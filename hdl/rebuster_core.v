module rebuster_core(
    input clk100,

    input cpuclk_rising,
    input cpuclk_falling,

    input cpuclk_in,
    input c7m_in,

    input reset_n_in,

    input addrz3_n_in,
    input memz2_n_in,
    input ioz2_n_in,

    output reg [2:0] aboe_n_out,
    output reg [2:0] aboe_n_oe,

    input own_n_in,
    output reg own_n_out,
    output reg own_n_oe,

    output reg [1:0] dboe_n_out,
    output reg [1:0] dboe_n_oe,

    output reg d2p_n_out,
    output reg d2p_n_oe,

    output reg dblt_out,
    output reg dblt_oe,

    input [3:0] a_in,
    output reg [3:0] a_out,
    output reg [3:0] a_oe,

    input [1:0] siz_in,
    output reg [1:0] siz_out,
    output reg [1:0] siz_oe,

    input rw_in,
    output reg rw_out,
    output reg rw_oe,

    input as_n_in,
    output reg as_n_out,
    output reg as_n_oe,

    input ds_n_in,
    output reg ds_n_out,
    output reg ds_n_oe,

    input [1:0] dsack_n_in,
    output reg [1:0] dsack_n_out,
    output reg [1:0] dsack_n_oe,

    input sterm_n_in,
    output reg sterm_n_out,
    output reg sterm_n_oe,

    input ciin_n_in,
    output reg ciin_n_out,
    output reg ciin_n_oe,

    input [3:1] ea_in,
    output reg [3:1] ea_out,
    output reg [3:1] ea_oe,

    input read_in,
    output reg read_out,
    output reg read_oe,

    input fcs_n_in,
    output reg fcs_n_out,
    output reg fcs_n_oe,

    input doe_in,
    output reg doe_out,
    output reg doe_oe,

    input [3:0] eds_n_in,
    output reg [3:0] eds_n_out,
    output reg [3:0] eds_n_oe,

    input dtack_n_in,
    output reg dtack_n_out,
    output reg dtack_n_oe,

    input cinh_n_in,
    output reg cinh_n_out,
    output reg cinh_n_oe,

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
    output reg [4:0] ebg_n_oe
);

/*
Notes:

- Doesn't handle EBCLR_n yet. The pin is likely not used by any Z2 or Z3 boards.
- Doesn't handle Multiple Transfer Cycles yet.
- No handling of bus error (BERR/BINT) yet.
- No handling of slave collisions (SLAVE) yet.
- No handling of Read-Modify-Write cycles (RMC/LOCK) yet.
*/

reg [2:0] reset_n_sync;
reg [2:0] dtack_n_sync;
reg [2:0] fcs_n_sync;
reg [2:0] all_eds_n_sync;
reg [3:0] all_dsack_n_sync;
reg [2:0] c7m_sync;
reg [2:0] as_n_sync;
reg [2:0] sbr_n_sync;
reg [2:0] bg_n_sync;
reg [2:0] bgack_n_sync;
reg [4:0] ebr_n_sync_0;
reg [4:0] ebr_n_sync_1;

always @(posedge clk100) begin
    reset_n_sync <= {reset_n_sync[1:0], reset_n_in};
    dtack_n_sync <= {dtack_n_sync[1:0], dtack_n_in};
    fcs_n_sync <= {fcs_n_sync[1:0], fcs_n_in};
    all_eds_n_sync <= {all_eds_n_sync[1:0], &eds_n_in};
    all_dsack_n_sync <= {all_dsack_n_sync[2:0], &dsack_n_in};
    c7m_sync <= {c7m_sync[1:0], c7m_in};
    as_n_sync <= {as_n_sync[1:0], as_n_in};
    sbr_n_sync <= {sbr_n_sync[1:0], sbr_n_in};
    bg_n_sync <= {bg_n_sync[1:0], bg_n_in};
    bgack_n_sync <= {bgack_n_sync[1:0], bgack_n_in};
    ebr_n_sync_1 <= ebr_n_sync_0;
    ebr_n_sync_0 <= ebr_n_in;
end

wire c7m_falling = c7m_sync[2:1] == 2'b10;

localparam DIR_CPU_TO_ZORRO = 1'b0;
localparam DIR_ZORRO_TO_CPU = 1'b1;

reg direction;

localparam ACCESS_IDLE = 3'd0;
localparam ACCESS_CPU_TO_Z3 = 3'd1;
localparam ACCESS_CPU_TO_Z2 = 3'd2;
localparam ACCESS_CPU_TO_OTHER = 3'd3;
localparam ACCESS_Z3_TO_CPU = 3'd4;

reg [2:0] access_state;

// Combinatorially generate next EDS_n.
reg [3:0] next_z3_eds_n;

// Some of these combinations may not be relevant in practice,
// but are included for completeness.
always @(*) begin
    case (siz_in)
        2'd1: begin
            case (a_in[1:0])
                2'd0: next_z3_eds_n <= 4'b0111;
                2'd1: next_z3_eds_n <= 4'b1011;
                2'd2: next_z3_eds_n <= 4'b1101;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
        2'd2: begin
            case (a_in[1:0])
                2'd0: next_z3_eds_n <= 4'b0011;
                2'd1: next_z3_eds_n <= 4'b1001;
                2'd2: next_z3_eds_n <= 4'b1100;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
        2'd3: begin
            case (a_in[1:0])
                2'd0: next_z3_eds_n <= 4'b0001;
                2'd1: next_z3_eds_n <= 4'b1000;
                2'd2: next_z3_eds_n <= 4'b1100;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
        2'd0: begin
            case (a_in[1:0])
                2'd0: next_z3_eds_n <= 4'b0000;
                2'd1: next_z3_eds_n <= 4'b1000;
                2'd2: next_z3_eds_n <= 4'b1100;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
    endcase
end

reg [1:0] next_z3_a;
reg [1:0] next_z3_siz;

always @(*) begin
    case (eds_n_in)
        4'b0000: next_z3_a <= 2'd0;
        4'b0001: next_z3_a <= 2'd0;
        4'b0010: next_z3_a <= 2'd0; // Invalid
        4'b0011: next_z3_a <= 2'd0;
        4'b0100: next_z3_a <= 2'd0; // Invalid
        4'b0101: next_z3_a <= 2'd0; // Invalid
        4'b0110: next_z3_a <= 2'd0; // Invalid
        4'b0111: next_z3_a <= 2'd0;
        4'b1000: next_z3_a <= 2'd1;
        4'b1001: next_z3_a <= 2'd1;
        4'b1010: next_z3_a <= 2'd1; // Invalid
        4'b1011: next_z3_a <= 2'd1;
        4'b1100: next_z3_a <= 2'd2;
        4'b1101: next_z3_a <= 2'd2;
        4'b1110: next_z3_a <= 2'd3;
        4'b1111: next_z3_a <= 2'd3; // Not used during access
    endcase

    case (eds_n_in)
        4'b0000: next_z3_siz <= 2'd0;
        4'b0001: next_z3_siz <= 2'd3;
        4'b0010: next_z3_siz <= 2'd2; // Invalid
        4'b0011: next_z3_siz <= 2'd2;
        4'b0100: next_z3_siz <= 2'd1; // Invalid
        4'b0101: next_z3_siz <= 2'd1; // Invalid
        4'b0110: next_z3_siz <= 2'd1; // Invalid
        4'b0111: next_z3_siz <= 2'd1;
        4'b1000: next_z3_siz <= 2'd3;
        4'b1001: next_z3_siz <= 2'd2;
        4'b1010: next_z3_siz <= 2'd1; // Invalid
        4'b1011: next_z3_siz <= 2'd1;
        4'b1100: next_z3_siz <= 2'd2;
        4'b1101: next_z3_siz <= 2'd1;
        4'b1110: next_z3_siz <= 2'd1;
        4'b1111: next_z3_siz <= 2'd0; // Not used during access
    endcase
end

reg [2:0] cpu_to_z3_state;
reg [2:0] z3_to_cpu_state;

reg [2:0] address_decode_stable;

reg [7:0] terminate_access_counter;

reg [1:0] sterm_n_delayed;

reg [4:0] ebr_n_falling_0;
reg [4:0] ebr_n_falling_1;

reg [4:0] z3_registered;

// A pulse is if EBR is high, low, high on subsequent falling C7M edges.
wire [4:0] z3_register_pulse = ebr_n_falling_1 & ~ebr_n_falling_0 & ebr_n_sync_1;

localparam BA_NONE = 2'd0;
localparam BA_SDMAC = 2'd1;
localparam BA_Z3 = 2'd2;

reg [1:0] ba_state;

reg [2:0] z3_ba_state;

reg [4:0] z3_grant;
wire [4:0] next_z3_grant;

round_robin_priority_encoder rrpe(
    .requests(z3_registered),
    .previous_grant(z3_grant),
    .grant(next_z3_grant)
);

// All signals are controlled sequentially.

always @(posedge clk100) begin

    address_decode_stable <= {address_decode_stable[1:0], aboe_n_out == 3'b000};

    sterm_n_delayed <= {sterm_n_delayed[0], sterm_n_in};

    if (c7m_falling) begin
        ebr_n_falling_1 <= ebr_n_falling_0;
        ebr_n_falling_0 <= ebr_n_sync_1;
    end

    if (!reset_n_sync[1]) begin // In reset.
        // Output pins.
        aboe_n_out <= 3'b111;
        aboe_n_oe <= 3'b0;

        own_n_out <= 1'b1;
        own_n_oe <= 1'b0;

        dboe_n_out <= 2'b11;
        dboe_n_oe <= 2'b0;

        d2p_n_out <= 1'b1;
        d2p_n_oe <= 1'b0;

        dblt_out <= 1'b0;
        dblt_oe <= 1'b0;

        a_out <= 4'b0;
        a_oe <= 4'b0;

        siz_out <= 2'b0;
        siz_oe <= 2'b0;

        rw_out <= 1'b0;
        rw_oe <= 1'b0;

        as_n_out <= 1'b1;
        as_n_oe <= 1'b0;

        ds_n_out <= 1'b1;
        ds_n_oe <= 1'b0;

        dsack_n_out <= 2'b11;
        dsack_n_oe <= 2'b0;

        sterm_n_out <= 1'b1;
        sterm_n_oe <= 1'b0;

        ciin_n_out <= 1'b1;
        ciin_n_oe <= 1'b0;

        ea_out <= 3'b0;
        ea_oe <= 3'b0;

        read_out <= 1'b1;
        read_oe <= 1'b0;

        fcs_n_out <= 1'b1;
        fcs_n_oe <= 1'b0;

        doe_out <= 1'b0;
        doe_oe <= 1'b0;

        eds_n_out <= 4'b1111;
        eds_n_oe <= 4'b0;

        dtack_n_out <= 1'b1;
        dtack_n_oe <= 1'b0;

        cinh_n_out <= 1'b1;
        cinh_n_oe <= 1'b0;

        br_n_out <= 1'b1;
        br_n_oe <= 1'b0;

        bgack_n_out <= 1'b1;
        bgack_n_oe <= 1'b0;

        sbg_n_out <= 1'b1;
        sbg_n_oe <= 1'b0;

        ebg_n_out <= 5'b11111;
        ebg_n_oe <= 5'b0;

        // Internal state.
        direction = DIR_CPU_TO_ZORRO;
        access_state <= ACCESS_IDLE;

        cpu_to_z3_state <= 3'd0;
        z3_to_cpu_state <= 3'd0;

        terminate_access_counter <= 8'd0;

        ba_state <= BA_NONE;

        z3_ba_state <= 3'd0;

        z3_registered <= 5'b0;
        z3_grant <= 5'b0;

    end else if (!reset_n_sync[2]) begin // Coming out of reset.

        // When coming out of reset, the fpga should start driving towards Z3,
        // as Zorro is slave.

        aboe_n_out <= 3'b000;
        aboe_n_oe <= 3'b111;

        ea_out <= 3'b111;
        ea_oe <= 3'b111;

        read_out <= 1'b1;
        read_oe <= 1'b1;

        doe_out <= 1'b0;
        doe_oe <= 1'b1;

        fcs_n_out <= 1'b1;
        fcs_n_oe <= 1'b1;

        dboe_n_out <= 2'b11;
        dboe_n_oe <= 2'b11;

        d2p_n_out <= 1'b1;
        d2p_n_oe <= 1'b1;

        dblt_out <= 1'b0;
        dblt_oe <= 1'b1;

        eds_n_out <= 4'b1111;
        eds_n_oe <= 4'b1111;

        sbg_n_out <= 1'b1;
        sbg_n_oe <= 1'b1;

        ebg_n_out <= 5'b11111;
        ebg_n_oe <= 5'b11111;

    end else begin // Normal operations.

        if (c7m_falling) begin
            z3_registered <= z3_registered ^ z3_register_pulse;
        end

        case (ba_state)
            BA_NONE: begin
                if (!sbr_n_sync[1]) begin
                    br_n_out <= 1'b0;
                    br_n_oe <= 1'b1;
                    ba_state <= BA_SDMAC;
                end else if (|z3_registered) begin
                    br_n_out <= 1'b0;
                    br_n_oe <= 1'b1;
                    ba_state <= BA_Z3;
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
                        if (!bg_n_sync[1] && bgack_n_sync[1] && access_state == ACCESS_IDLE) begin
                            direction <= DIR_ZORRO_TO_CPU;

                            // Stop driving towards the Zorro bus.
                            ea_oe <= 3'b000;
                            read_oe <= 1'b0;
                            doe_oe <= 1'b0;
                            fcs_n_oe <= 1'b0;
                            eds_n_oe <= 4'b0000;

                            // Start driving towards the CPU bus.
                            a_oe <= 4'b1111;
                            siz_oe <= 2'b11;
                            rw_oe <= 1'b1;
                            as_n_oe <= 1'b1;
                            ds_n_oe <= 1'b1;

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
                        if (!(|(z3_registered & z3_grant))) begin
                            ebg_n_out <= 5'b11111;
                            z3_ba_state <= 3'd4;
                        end
                    end
                    3'd4: begin
                        if (access_state == ACCESS_IDLE && cpuclk_rising) begin
                            z3_ba_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        if (cpuclk_rising) begin
                            direction <= DIR_CPU_TO_ZORRO;

                            // Start driving towards the Zorro bus.
                            ea_oe <= 3'b111;
                            read_oe <= 1'b1;
                            doe_oe <= 1'b1;
                            fcs_n_oe <= 1'b1;
                            eds_n_oe <= 4'b1111;

                            // Stop driving towards the CPU bus.
                            a_oe <= 4'b0000;
                            siz_oe <= 2'b00;
                            rw_oe <= 1'b0;
                            as_n_oe <= 1'b0;
                            ds_n_oe <= 1'b0;

                            // Switch direction of address buffers.
                            own_n_out <= 1'b1;
                            own_n_oe <= 1'b1;

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
        endcase

        case (access_state)
            ACCESS_IDLE: begin

                if (direction == DIR_CPU_TO_ZORRO) begin
                    // CPU is bus master.

                    // Rising edge going from S0 to S1.
                    if (cpuclk_rising && !as_n_in) begin
                        // If this later turns out to be a Z2 access then
                        // ea_out has to be updated.
                        ea_out <= {a_in[3:2], 1'b1};
                        read_out <= rw_in;

                        d2p_n_out <= !rw_in;
                    end

                    // Falling edge going from S1 to S2.
                    // This should give address decoder enough time.
                    if (cpuclk_falling && !as_n_in && address_decode_stable[2]) begin
                        if (!addrz3_n_in) begin
                            fcs_n_out <= 1'b0;
                            access_state <= ACCESS_CPU_TO_Z3;
                        end else if (!memz2_n_in || !ioz2_n_in) begin
                            access_state <= ACCESS_CPU_TO_Z2;
                        end else begin
                            access_state <= ACCESS_CPU_TO_OTHER;
                        end
                    end
                end else begin // DIR_ZORRO_TO_CPU
                    // Zorro is bus master.

                    if (!fcs_n_sync[1]) begin
                        access_state <= ACCESS_Z3_TO_CPU;
                    end
                end
            end

            ACCESS_CPU_TO_OTHER: begin
                if (cpuclk_rising && as_n_in) begin
                    access_state <= ACCESS_IDLE;
                end
            end

            ACCESS_CPU_TO_Z2: begin
                if (cpuclk_rising && as_n_in) begin
                    dsack_n_out <= 2'b11;
                    dsack_n_oe <= 2'b00;

                    access_state <= ACCESS_IDLE;
                end else begin
                    dsack_n_out <= 2'b01; // 16 bit port.
                    dsack_n_oe <= 2'b11;
                end
            end

            ACCESS_CPU_TO_Z3: begin
                case (cpu_to_z3_state)
                    3'd0: begin
                        if (cpuclk_rising) begin
                            // Close A[31:8] latch.
                            aboe_n_out <= 3'b110;

                            cpu_to_z3_state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (cpuclk_falling) begin
                            // Open D[31:0] latch.
                            doe_out <= 1'b1;
                            dboe_n_out <= 2'b00;

                            cpu_to_z3_state <= 3'd2;
                        end
                    end
                    3'd2: begin
                        if (cpuclk_rising) begin
                            // Starting driving EDS_n.
                            eds_n_out <= next_z3_eds_n;

                            terminate_access_counter <= 8'd40;

                            cpu_to_z3_state <= 3'd3;
                        end
                    end
                    3'd3: begin
                        if (cpuclk_falling) begin
                            // Start driving cache inhibit.
                            // Must be stable on rising CPUCLK.
                            ciin_n_out <= cinh_n_in;
                            ciin_n_oe <= 1'b1;
                        end

                        if (cpuclk_rising) begin
                            if (!dtack_n_sync[1] || terminate_access_counter == 8'd0) begin
                                dsack_n_out <= 2'b00; // 32 bit port.
                                dsack_n_oe <= 2'b11; // Could potentially use STERM instead.

                                cpu_to_z3_state <= 3'd4;
                            end else begin
                                terminate_access_counter <= terminate_access_counter - 8'd1;
                            end
                        end
                    end
                    3'd4: begin
                        if (cpuclk_rising && as_n_in) begin
                            fcs_n_out <= 1'b1;
                            eds_n_out <= 4'b1111;

                            dboe_n_out <= 2'b11;

                            // DSACK_n is negated earlier than for real Buster.
                            // I think this shouldn't be possible to observe for the Zorro board.
                            // Negate DSACK_n/CIIN_n.
                            dsack_n_out <= 2'b11;
                            ciin_n_out <= 1'b1;

                            cpu_to_z3_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        // DOE is negated 10 ns later than FCS_n to mimic Buster timing.
                        // Likely it would have been okay to negate it at the same time as FCS_n.
                        doe_out <= 1'b0;

                        if (cpuclk_falling) begin
                            // Stop driving DSACK_n/CIIN_n.
                            dsack_n_oe <= 2'b00;
                            ciin_n_oe <= 1'b0;

                            cpu_to_z3_state <= 3'd6;
                        end
                    end
                    3'd6: begin
                        if (cpuclk_falling) begin
                            aboe_n_out <= 3'b000;

                            cpu_to_z3_state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                endcase
            end

            ACCESS_Z3_TO_CPU: begin
                case (z3_to_cpu_state)
                    3'd0: begin // Entering S0
                        if (cpuclk_rising && doe_in && !all_eds_n_sync) begin
                            a_out <= {ea_in[3:2], next_z3_a};
                            siz_out <= next_z3_siz;
                            rw_out <= read_in;

                            dboe_n_out <= 2'b00;
                            d2p_n_out <= read_in;

                            z3_to_cpu_state <= 3'd1;
                        end
                    end
                    3'd1: begin // S0 -> S1
                        if (cpuclk_falling) begin
                            as_n_out <= 1'b0;

                            if (rw_out)
                                ds_n_out <= 1'b0;

                            z3_to_cpu_state <= 3'd2;
                        end
                    end
                    3'd2: begin // S2 -> S3
                        if (cpuclk_falling) begin
                            ds_n_out <= 1'b0;

                            z3_to_cpu_state <= 3'd3;
                        end
                    end
                    3'd3: begin // S4 -> S5
                        if (cpuclk_falling) begin
                            if (!all_dsack_n_sync[3] || !sterm_n_delayed[1]) begin

                                if (!rw_out) begin
                                    as_n_out <= 1'b1;
                                    ds_n_out <= 1'b1;
                                end

                                dtack_n_out <= 1'b0;
                                dtack_n_oe <= 1'b1;

                                z3_to_cpu_state <= 3'd4;
                            end
                        end
                    end
                    3'd4: begin
                        if (fcs_n_sync[1]) begin

                            // Stop driving DTACK_n as soon as possible.
                            dtack_n_out <= 1'b1;

                            // Stop driving data.
                            dboe_n_out <= 2'b11;

                            z3_to_cpu_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        dtack_n_oe <= 1'b0;

                        if (!rw_out || cpuclk_falling) begin
                            as_n_out <= 1'b1;
                            ds_n_out <= 1'b1;

                            z3_to_cpu_state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                endcase
            end
        endcase
    end
end

endmodule

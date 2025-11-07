module access(
    input clk100,

    input cpuclk_rising,
    input cpuclk_falling,

    input c7m_in,

    input reset_n_in,

    input [1:0] bm_state,

    output access_state_idle,

    input addrz3_n_in,
    input memz2_n_in,
    input ioz2_n_in,

    output reg [2:0] aboe_n_out,
    output reg [2:0] aboe_n_oe,

    output reg [1:0] dboe_n_out,
    output reg [1:0] dboe_n_oe,

    output reg db16_n_out,
    output reg db16_n_oe,

    output reg d2p_n_out,
    output reg d2p_n_oe,

    output reg dblt_out,
    output reg dblt_oe,

    output reg bigz_n_out,
    output reg bigz_n_oe,

    // CPU control.
    input [3:0] a_in,
    output reg [3:0] a_out,

    input [1:0] siz_in,
    output reg [1:0] siz_out,

    input rw_in,
    output reg rw_out,

    input as_n_in,
    output reg as_n_out,

    input ds_n_in,
    output reg ds_n_out,

    // CPU access termination.
    input [1:0] dsack_n_in,
    output reg [1:0] dsack_n_out,
    output reg [1:0] dsack_n_oe,

    input sterm_n_in,
    output reg sterm_n_out,
    output reg sterm_n_oe,

    input ciin_n_in,
    output reg ciin_n_out,
    output reg ciin_n_oe,

    // Zorro control.
    input [3:1] ea_in,
    output reg [3:1] ea_out,

    input read_in,
    output reg read_out,

    input fcs_n_in,
    output reg fcs_n_out,

    input ccs_n_in,
    output reg ccs_n_out,

    input doe_in,
    output reg doe_out,

    input [3:0] eds_n_in,
    output reg [3:0] eds_n_out,

    // Zorro access termination.
    input dtack_n_in,
    output reg dtack_n_out,
    output reg dtack_n_oe,

    input cinh_n_in,
    output reg cinh_n_out,
    output reg cinh_n_oe,

    input mtcr_n_in
);

wire ovr_n_in = cinh_n_in;
wire xrdy_in = mtcr_n_in;

localparam BM_CPU = 2'd0;
localparam BM_Z3 = 2'd2;
localparam BM_Z2 = 2'd3;

// Synchronize asynchronous signals.
reg [2:0] c7m_sync;
reg [2:0] reset_n_sync;

reg [2:0] fcs_n_sync;
reg [2:0] ccs_n_sync;
reg [2:0] dtack_n_sync;

reg [2:0] all_eds_n_sync;
reg [3:0] all_dsack_n_sync;

always @(posedge clk100) begin
    c7m_sync <= {c7m_sync[1:0], c7m_in};
    reset_n_sync <= {reset_n_sync[1:0], reset_n_in};

    fcs_n_sync <= {fcs_n_sync[1:0], fcs_n_in};
    ccs_n_sync <= {ccs_n_sync[1:0], ccs_n_in};
    dtack_n_sync <= {dtack_n_sync[1:0], dtack_n_in};

    all_eds_n_sync <= {all_eds_n_sync[1:0], &eds_n_in};
    all_dsack_n_sync <= {all_dsack_n_sync[2:0], &dsack_n_in};
end

wire c7m_rising = c7m_sync[2:1] == 2'b01;
wire c7m_falling = c7m_sync[2:1] == 2'b10;

// Combinatorially generate next EDS_n.
reg [3:0] next_z3_eds_n;

always @(*) begin
    case ({siz_in, a_in[1:0]})
        4'b0100: next_z3_eds_n <= 4'b0111;
        4'b0101: next_z3_eds_n <= 4'b1011;
        4'b0110: next_z3_eds_n <= 4'b1101;
        4'b0111: next_z3_eds_n <= 4'b1110;
        4'b1000: next_z3_eds_n <= 4'b0011;
        4'b1001: next_z3_eds_n <= 4'b1001;
        4'b1010: next_z3_eds_n <= 4'b1100;
        4'b1011: next_z3_eds_n <= 4'b1110;
        4'b1100: next_z3_eds_n <= 4'b0001;
        4'b1101: next_z3_eds_n <= 4'b1000;
        4'b1110: next_z3_eds_n <= 4'b1100;
        4'b1111: next_z3_eds_n <= 4'b1110;
        4'b0000: next_z3_eds_n <= 4'b0000;
        4'b0001: next_z3_eds_n <= 4'b1000;
        4'b0010: next_z3_eds_n <= 4'b1100;
        4'b0011: next_z3_eds_n <= 4'b1110;
    endcase
end

reg [3:0] next_z2_eds_n;

always @(*) begin
    if (!a_in[0]) begin // Even address.
        if (siz_in == 2'd1) begin
            next_z2_eds_n <= 4'b0111;
        end else begin
            next_z2_eds_n <= 4'b0011;
        end
    end else begin // Odd address.
        next_z2_eds_n <= 4'b1011;
    end
end

reg [3:0] next_z3_a;

always @(*) begin
    case (eds_n_in)
        4'b0000: next_z3_a <= {ea_in[3:2], 2'd0};
        4'b0001: next_z3_a <= {ea_in[3:2], 2'd0};
        4'b0010: next_z3_a <= {ea_in[3:2], 2'd0}; // Invalid
        4'b0011: next_z3_a <= {ea_in[3:2], 2'd0};
        4'b0100: next_z3_a <= {ea_in[3:2], 2'd0}; // Invalid
        4'b0101: next_z3_a <= {ea_in[3:2], 2'd0}; // Invalid
        4'b0110: next_z3_a <= {ea_in[3:2], 2'd0}; // Invalid
        4'b0111: next_z3_a <= {ea_in[3:2], 2'd0};
        4'b1000: next_z3_a <= {ea_in[3:2], 2'd1};
        4'b1001: next_z3_a <= {ea_in[3:2], 2'd1};
        4'b1010: next_z3_a <= {ea_in[3:2], 2'd1}; // Invalid
        4'b1011: next_z3_a <= {ea_in[3:2], 2'd1};
        4'b1100: next_z3_a <= {ea_in[3:2], 2'd2};
        4'b1101: next_z3_a <= {ea_in[3:2], 2'd2};
        4'b1110: next_z3_a <= {ea_in[3:2], 2'd3};
        4'b1111: next_z3_a <= {ea_in[3:2], 2'd3}; // Not used during access
    endcase
end

reg [1:0] next_z3_siz;

always @(*) begin
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

wire [3:0] next_z2_a = {ea_in[3:1], eds_n_in[3]};

wire [1:0] next_z2_siz = eds_n_in[3:2] == 2'b00 ? 2'b10 : 2'b01;

// State.
localparam ACCESS_IDLE = 3'd0;
localparam ACCESS_CPU_TO_Z3 = 3'd1;
localparam ACCESS_CPU_TO_Z2 = 3'd2;
localparam ACCESS_CPU_TO_OTHER = 3'd3;
localparam ACCESS_Z3_TO_CPU = 3'd4;
localparam ACCESS_Z3_TO_Z3 = 3'd5;
localparam ACCESS_Z2_TO_CPU = 3'd6;

reg [2:0] access_state;

reg [2:0] address_decode_stable;
reg [1:0] sterm_n_delayed;
reg [1:0] addrz3_n_delayed;

reg [2:0] cpu_to_z3_state;
reg [7:0] terminate_access_counter;

reg [2:0] cpu_to_z2_state;
reg [2:0] z2_state;

reg [2:0] z3_to_cpu_state;

reg [2:0] z2_to_cpu_state;

assign access_state_idle = access_state == ACCESS_IDLE;

// State machine.
always @(posedge clk100) begin

    address_decode_stable <= {address_decode_stable[1:0], aboe_n_out == 3'b000};

    sterm_n_delayed <= {sterm_n_delayed[0], sterm_n_in};

    addrz3_n_delayed <= {addrz3_n_delayed[0], addrz3_n_in};

    if (!reset_n_sync[1]) begin // In reset.
        // Output pins.
        aboe_n_out <= 3'b000;
        aboe_n_oe <= 3'b000;

        dboe_n_out <= 2'b11;
        dboe_n_oe <= 2'b00;

        db16_n_out <= 1'b1;
        db16_n_oe <= 1'b0;

        d2p_n_out <= 1'b1;
        d2p_n_oe <= 1'b0;

        dblt_out <= 1'b0;
        dblt_oe <= 1'b0;

        bigz_n_out <= 1'b1;
        bigz_n_oe <= 1'b0;

        // CPU control.
        a_out <= 4'b0000;
        siz_out <= 2'b00;
        rw_out <= 1'b0;
        as_n_out <= 1'b1;
        ds_n_out <= 1'b1;

        // CPU access termination.
        dsack_n_out <= 2'b11;
        dsack_n_oe <= 2'b00;

        sterm_n_out <= 1'b1;
        sterm_n_oe <= 1'b0;

        ciin_n_out <= 1'b1;
        ciin_n_oe <= 1'b0;

        // Zorro control.
        ea_out <= 3'b000;
        read_out <= 1'b1;
        fcs_n_out <= 1'b1;
        ccs_n_out <= 1'b1;
        doe_out <= 1'b0;
        eds_n_out <= 4'b1111;

        // Zorro access termination.
        dtack_n_out <= 1'b1;
        dtack_n_oe <= 1'b0;

        cinh_n_out <= 1'b1;
        cinh_n_oe <= 1'b0;

        // Internal state.
        access_state <= ACCESS_IDLE;

        cpu_to_z3_state <= 3'd0;

        terminate_access_counter <= 8'd0;

        cpu_to_z2_state <= 3'd0;
        z2_state <= 3'd0;

        z3_to_cpu_state <= 3'd0;

        z2_to_cpu_state <= 3'd0;

    end else if (!reset_n_sync[2]) begin // Coming out of reset.

        aboe_n_oe <= 3'b111;
        dboe_n_oe <= 2'b11;
        db16_n_oe <= 1'b1;
        d2p_n_oe <= 1'b1;
        dblt_oe <= 1'b1;

        bigz_n_oe <= 1'b1;

    end else begin // Normal operations.

        case (access_state)
            ACCESS_IDLE: begin
                aboe_n_out <= bm_state == BM_Z2 ? 3'b100 : 3'b000;
                bigz_n_out <= bm_state == BM_Z2 ? 1'b0 : 1'b1;

                case (bm_state)
                    BM_CPU: begin
                        // Rising edge going from S1 to S2.
                        if (cpuclk_rising && !as_n_in) begin
                            // If this later turns out to be a Z2 access then
                            // ea_out has to be updated.
                            ea_out <= {a_in[3:2], 1'b1};
                            read_out <= rw_in;

                            d2p_n_out <= !rw_in;
                        end

                        // Falling edge going from S2 to S3.
                        // This should give address decoder enough time.
                        if (cpuclk_falling && !as_n_in && address_decode_stable[2]) begin
                            if (!addrz3_n_in) begin
                                fcs_n_out <= 1'b0;
                                access_state <= ACCESS_CPU_TO_Z3;
                            end else if (!memz2_n_in || !ioz2_n_in) begin
                                fcs_n_out <= 1'b0;
                                access_state <= ACCESS_CPU_TO_Z2;
                            end else begin
                                access_state <= ACCESS_CPU_TO_OTHER;
                            end
                        end
                    end

                    BM_Z3: begin
                        if (!fcs_n_sync[1]) begin
                            if (!addrz3_n_delayed[1]) begin
                                access_state <= ACCESS_Z3_TO_Z3;
                            end else begin
                                access_state <= ACCESS_Z3_TO_CPU;
                            end
                        end
                    end

                    BM_Z2: begin
                        if (!ccs_n_sync[1]) begin
                            access_state <= ACCESS_Z2_TO_CPU;
                        end
                    end
                endcase
            end

            ACCESS_CPU_TO_OTHER: begin
                if (cpuclk_rising && as_n_in) begin
                    access_state <= ACCESS_IDLE;
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

            ACCESS_CPU_TO_Z2: begin
                case (cpu_to_z2_state)
                    3'd0: begin
                        if (cpuclk_rising) begin
                            ea_out <= a_in[3:1];

                            // Stop driving EAD[31:24].
                            aboe_n_out <= 3'b100;

                            dblt_out <= rw_in;

                            ciin_n_out <= ioz2_n_in;

                            cpu_to_z2_state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (cpuclk_falling) begin
                            if (!ciin_n_out) begin
                                ciin_n_oe <= 1'b1;
                            end

                            // The address has now been stable for 20 ns.
                            cpu_to_z2_state <= 3'd2;
                        end
                    end
                    3'd2: begin
                        if (z2_state == 3'd6 && c7m_falling) begin
                            cpu_to_z2_state <= 3'd3;
                        end
                    end
                    3'd3: begin
                        if (cpuclk_rising) begin
                            dsack_n_out <= 2'b01;
                            dsack_n_oe <= 2'b11;

                            cpu_to_z2_state <= 3'd4;
                        end
                    end
                    3'd4: begin
                        if (cpuclk_rising && as_n_in) begin
                            fcs_n_out <= 1'b1;

                            aboe_n_out <= 3'b110;
                            dboe_n_out <= 2'b11;

                            dblt_out <= 1'b0;

                            // Negate DSACK_n/CIIN_n.
                            dsack_n_out <= 2'b11;
                            ciin_n_out <= 1'b1;

                            cpu_to_z2_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        if (cpuclk_falling) begin
                            // Stop driving DSACK_n/CIIN_n.
                            dsack_n_oe <= 2'b00;
                            ciin_n_oe <= 1'b0;

                            cpu_to_z2_state <= 3'd6;
                        end
                    end
                    3'd6: begin
                        if (cpuclk_falling) begin
                            aboe_n_out <= 3'b000;

                            cpu_to_z2_state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                endcase

                case (z2_state)
                    3'd0: begin
                        if (cpu_to_z2_state == 3'd1 && cpuclk_falling) begin
                            // The address has now been stable for 20 ns.
                            z2_state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (c7m_rising) begin
                            ccs_n_out <= 1'b0;

                            if (rw_in)
                                eds_n_out <= next_z2_eds_n;

                            if (!rw_in)
                                dboe_n_out <= 2'b01;

                            z2_state <= 3'd2;
                        end
                    end
                    3'd2: begin
                        if (c7m_falling) begin
                            z2_state <= 3'd3;
                        end
                    end
                    3'd3: begin
                        if (c7m_rising) begin
                            if (!rw_in)
                                eds_n_out <= next_z2_eds_n;

                            if (rw_in)
                                dboe_n_out <= 2'b01;

                            doe_out <= 1'b1;

                            if (xrdy_in && ovr_n_in) begin
                                dtack_n_out <= 1'b0;
                                dtack_n_oe <= 1'b1;
                            end

                            z2_state <= 3'd4;
                        end
                    end
                    3'd4: begin
                        if (c7m_falling) begin
                            if (!dtack_n_sync[1])
                                z2_state <= 3'd5;
                            else
                                z2_state <= 3'd3;
                        end
                    end
                    3'd5: begin
                        if (c7m_rising) begin
                            z2_state <= 3'd6;
                        end
                    end
                    3'd6: begin
                        if (c7m_falling) begin
                            ccs_n_out <= 1'b1;

                            eds_n_out <= 4'b1111;

                            dtack_n_oe <= 1'b0;

                            z2_state <= 3'd7;
                        end
                    end
                    3'd7: begin
                        if (c7m_rising) begin
                            doe_out <= 1'b0;

                            z2_state <= 3'd0;
                        end
                    end
                endcase
            end

            ACCESS_Z3_TO_CPU: begin
                case (z3_to_cpu_state)
                    3'd0: begin // Entering S0
                        if (cpuclk_rising && doe_in && !all_eds_n_sync[1]) begin
                            a_out <= next_z3_a;
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

            ACCESS_Z3_TO_Z3: begin
                // This is an access that is local to the Z3 bus. No translation needed!
                // Access termination, etc, is handled by the bus master Z3 board.
                if (fcs_n_sync[1]) begin
                    access_state <= ACCESS_IDLE;
                end
            end

            ACCESS_Z2_TO_CPU: begin
                case (z2_to_cpu_state)
                    3'd0: begin // Entering S0
                        if (cpuclk_rising && !all_eds_n_sync[1]) begin
                            a_out <= next_z2_a;
                            siz_out <= next_z2_siz;
                            rw_out <= read_in;

                            if (!ea_in[1]) begin
                                dboe_n_out <= 2'b01;
                            end else begin
                                db16_n_out <= 1'b0;
                            end

                            d2p_n_out <= read_in;

                            z2_to_cpu_state <= 3'd1;
                        end
                    end
                    3'd1: begin // S0 -> S1
                        if (cpuclk_falling) begin
                            as_n_out <= 1'b0;

                            if (rw_out)
                                ds_n_out <= 1'b0;

                            z2_to_cpu_state <= 3'd2;
                        end
                    end
                    3'd2: begin // S2 -> S3
                        if (cpuclk_falling) begin
                            ds_n_out <= 1'b0;

                            z2_to_cpu_state <= 3'd3;
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

                                z2_to_cpu_state <= 3'd4;
                            end
                        end
                    end
                    3'd4: begin
                        if (ccs_n_sync[1]) begin

                            // Stop driving DTACK_n as soon as possible.
                            dtack_n_out <= 1'b1;

                            // Stop driving data.
                            dboe_n_out <= 2'b11;
                            db16_n_out <= 1'b1;

                            z2_to_cpu_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        dtack_n_oe <= 1'b0;

                        if (!rw_out || cpuclk_falling) begin
                            as_n_out <= 1'b1;
                            ds_n_out <= 1'b1;

                            z2_to_cpu_state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end

                endcase
            end
        endcase
    end
end

endmodule

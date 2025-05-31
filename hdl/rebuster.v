/*
Written by Niklas Ekström, 2025-05-31.

This is an implementation of Buster, Level I.

Level I Buster means:
"they don't support Zorro-3 DMA or Quick Interrupts, and they don't attempt to
translate local bus burst cycles into Zorro-3 burst cycles."

(From https://www.lysator.liu.se/amiga/hard/guide/A4000Hardware.guide,
section "Definitive Buster".)

Also has the following limitations:
- Doesn't support Zorro-2 DMA
- Doesn't consider SLAVE_n and doesn't generate BERR_n on collision
*/
module rebuster(
    // The signal names are taken from this schematic diagram:
    // https://www.amigawiki.org/dnl/schematics/A3000.pdf#page=14

    // Clocks
    input CPUCLK,
    input CLK90,
    input CDAC_n,
    input C7M,

    // System reset
    input RESET_n,          // Reset, cannot be driven
    input HLT_n,            // Halt, unused

    // Address decode, from U714 based on EAD[31:18]
    input IOZ2_n,           // Z2 IO Address Decode
    input MEMZ2_n,          // Z2 Mem Address Decode
    input ADDRZ3_n,         // Z3 Address Decode

    // Zorro buffer control
    output [2:0] ABOE_n,    // Address Bus Output Enables
    output [1:0] DBOE_n,    // Data Bus Output Enables
    output D2P_n,           // Data Bus Direction
    output DBLT,            // Data Bus Latch
    output DB16_n,          // Data Bus low 16 bits

    // CPU interface
    // Cf.: https://www.nxp.com/docs/en/reference-manual/MC68030UM-P1.pdf
    input [3:0] A,          // Address, low nybble
    input RW,               // Read/Write
    input [1:0] SIZ,        // Transfer Size
    input RMC_n,            // Read-Modify-Write Cycle
    input AS_n,             // Address Strobe
    input DS_n,             // Data Strobe
    output [1:0] DSACK_n,   // Data Transfer and Size Acknowledge
    output STERM_n,         // Synchronous Termination
    output BERR_n,          // Bus Error
    output CIIN_n,          // Cache Inhibit In

    input CBREQ_n,          // Cache Burst Request
    output CBACK_n,         // Cache Burst Acknowledge

    output BR_n,            // Bus Request
    input BG_n,             // Bus Grant
    input BGACK_n,          // Bus Grant Acknowledge

    // From CPU board connector
    input WAIT_n,           // Cycle Delay

    // To Gary
    output BIGZ_n,          // Set A[31:24] to zeroes

    // DMAC
    input SBR_n,            // DMAC Bus Request
    output SBG_n,           // DMAC Bus Grant

    // Zorro interface
    input [2:0] MS,         // Zx Function Codes
    output [3:1] EA,        // Z2 Low address bits / Z3 LOCK_n
    output READ,            // Zx Read Enable
    output FCS_n,           // Z3 Full Cycle Strobe
    output CCS_n,           // Z2 Compatibility Cycle Strobe
    output DOE,             // Zx Data Output Enable
    output [3:0] EDS_n,     // Zx Data Strobes

    input [4:0] SLAVE_n,    // Zx Slave responding to access

    inout DTACK_n,          // Zx Data Acknowledge
    input BINT_n,           // Zx Bus Error

    input CINH_n,           // Z3 Cache Inhibit / Z2 OVR_n

    // Multiple Transfer Cycle handshake
    // Bus master asserts MTCR, bus slave responds on MTACK
    inout MTCR_n,           // Z3 Multiple Transfer Cycle Request / Z2 XRDY
    input MTACK_n,          // Z3 Multiple Transfer Cycle Acknowledge

    // Zorro bus master control
    input [4:0] EBR_n,      // Zx Bus Request
    output [4:0] EBG_n,     // Zx Bus Grant
    input EBGACK_n,         // Zx Bus Grant Acknowledge
    input OWN_n,            // Zx PIC is DMA owner
    input EBCLR_n           // Bus Request Pending
);

// Signals with dual uses.
wire OVR_n = CINH_n;
wire XRDY = MTCR_n;

// Output signals that are currently not used and left floating.
assign DB16_n = 1'bz;       // This signal is only used during Z2 DMA.
assign STERM_n = 1'bz;
assign BERR_n = 1'bz;
assign CBACK_n = 1'bz;
assign BIGZ_n = 1'bz;
assign MTCR_n = 1'bz;
assign EBG_n = 5'bzzzzz;

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
wire cpuclk_falling = cpuclk_phase == 2'd1;

// Synchronizing signals to the clk100 clock domain:

// Synchronize to C7M clock. There is a 20-30 ns delay from the actual
// rising/falling events until the c7m_rising/_falling can be acted on.
reg [2:0] c7m_sync;
wire c7m_rising = c7m_sync[2:1] == 2'b01;
wire c7m_falling = c7m_sync[2:1] == 2'b10;

always @(posedge clk100) begin
    c7m_sync <= {c7m_sync[1:0], C7M};
end

reg [2:0] reset_n_sync;

always @(posedge clk100) begin
    reset_n_sync <= {reset_n_sync[1:0], RESET_n};
end

reg [1:0] dtack_n_sync;

always @(posedge clk100) begin
    dtack_n_sync <= {dtack_n_sync[0], DTACK_n};
end

// Wire up output signals.

// Only DMAC bus master requests (SBR/SBG) are handled.
assign BR_n = !SBR_n ? 1'b0 : 1'bz;
assign SBG_n = BG_n;

// OWN has pull-up, so even if no board is driving the signal, the direction
// for the address latches will be towards the board.

// Address buffers output enable.
reg [2:0] aboe_n_out = 3'b111;
assign ABOE_n = aboe_n_out;

// Data buffers output enable.
reg [1:0] dboe_n_out = 2'b11;
assign DBOE_n = dboe_n_out;

// Direction of data buffers.
assign D2P_n = !RW;

// Data bus latch.
// This signal is asserted while FCS is asserted, during a Z2 read access.
reg dblt_out = 1'b0;
assign DBLT = dblt_out;

// CPU signals.

// Data transfer and size acknowledge.
reg [1:0] dsack_n_out = 2'b11;
reg dsack_n_oe = 1'b0;
assign DSACK_n = dsack_n_oe ? dsack_n_out : 2'bzz;

// Cache inhibit input.
reg ciin_n_out = 1'b1;
reg ciin_n_oe = 1'b0;
assign CIIN_n = ciin_n_oe ? ciin_n_out : 1'bz;

// Zorro signals.

// Read.
wire read_out = RW;
reg read_oe = 1'b1;
assign READ = read_oe ? read_out : 1'bz;

// Low order address bits.
reg drive_word_address; // Z2 access
assign EA[3:2] = A[3:2];
assign EA[1] = drive_word_address ? A[1] : 1'b1;

// Full cycle strobe.
// Signal is asserted during all Z2 and Z3 accesses.
reg fcs_n_out = 1'b1;
reg fcs_n_oe = 1'b1;
assign FCS_n = fcs_n_oe ? fcs_n_out : 1'bz;

// Z2 address strobe.
reg ccs_n_out = 1'b1;
reg ccs_n_oe = 1'b1;
assign CCS_n = ccs_n_oe ? ccs_n_out : 1'bz;

// Z2/Z3 data strobes.
reg [3:0] eds_n_out = 4'b1111;
reg eds_n_oe = 1'b1;
assign EDS_n = eds_n_oe ? eds_n_out : 4'bzzzz;

// Data output enable.
reg doe_out = 1'b0;
reg doe_oe = 1'b1;
assign DOE = doe_oe ? doe_out : 1'bz;

// Data transfer acknowledge.
reg dtack_n_out = 1'b0;
reg dtack_n_oe = 1'b0;
assign DTACK_n = dtack_n_oe ? dtack_n_out : 1'bz;

// State machine variables.
reg [1:0] access_start_delay;

// Current access state.
localparam ACCESS_IDLE = 2'd0;
localparam ACCESS_OTHER = 2'd1;
localparam ACCESS_Z3 = 2'd2;
localparam ACCESS_Z2 = 2'd3;

reg [1:0] access_state;
reg [2:0] state = 3'd0;
reg [2:0] z2_state;
reg [7:0] terminate_access_counter;

// Combinatorially generate next EDS_n.
reg [3:0] next_z3_eds_n;

// Some of these combinations may not be relevant in practice,
// but are included for completeness.
always @(*) begin
    case (SIZ)
        2'd1: begin
            case (A[1:0])
                2'd0: next_z3_eds_n <= 4'b0111;
                2'd1: next_z3_eds_n <= 4'b1011;
                2'd2: next_z3_eds_n <= 4'b1101;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
        2'd2: begin
            case (A[1:0])
                2'd0: next_z3_eds_n <= 4'b0011;
                2'd1: next_z3_eds_n <= 4'b1001;
                2'd2: next_z3_eds_n <= 4'b1100;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
        2'd3: begin
            case (A[1:0])
                2'd0: next_z3_eds_n <= 4'b0001;
                2'd1: next_z3_eds_n <= 4'b1000;
                2'd2: next_z3_eds_n <= 4'b1100;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
        2'd0: begin
            case (A[1:0])
                2'd0: next_z3_eds_n <= 4'b0000;
                2'd1: next_z3_eds_n <= 4'b1000;
                2'd2: next_z3_eds_n <= 4'b1100;
                2'd3: next_z3_eds_n <= 4'b1110;
            endcase
        end
    endcase
end

reg [3:0] next_z2_eds_n;

always @(*) begin
    if (!A[0]) begin // Even address.
        if (SIZ == 2'd1) begin
            next_z2_eds_n <= 4'b0111;
        end else begin
            next_z2_eds_n <= 4'b0011;
        end
    end else begin // Odd address.
        next_z2_eds_n <= 4'b1011;
    end
end

// Emulate Buster 7 timing.
// Traces: https://github.com/niklasekstrom/rebuster-firmware/blob/main/docs/buster-timings.md

always @(posedge clk100) begin
    if (!reset_n_sync[2]) begin
        aboe_n_out <= 3'b111;
        dboe_n_out <= 2'b11;

        dblt_out <= 1'b0;

        dsack_n_out <= 2'b11;
        dsack_n_oe <= 1'b0;

        ciin_n_out <= 1'b1;
        ciin_n_oe <= 1'b0;

        read_oe <= 1'b1;

        drive_word_address <= 1'b0;

        fcs_n_out <= 1'b1;
        fcs_n_oe <= 1'b1;

        ccs_n_out <= 1'b1;
        ccs_n_oe <= 1'b1;

        eds_n_out <= 4'b1111;
        eds_n_oe <= 1'b1;

        doe_out <= 1'b0;
        doe_oe <= 1'b1;

        dtack_n_out <= 1'b0;
        dtack_n_oe <= 1'b0;

        // Current state.
        access_start_delay <= 2'b00;
        access_state <= ACCESS_IDLE;
        state <= 3'd0;
        z2_state <= 3'd0;
        terminate_access_counter <= 8'd0;

    end else begin

        if (cpuclk_rising) begin
            access_start_delay <= {access_start_delay[0], !AS_n};
        end

        case (access_state)
            ACCESS_IDLE: begin
                aboe_n_out <= 3'b000;

                if (cpuclk_falling && access_start_delay == 2'b11) begin
                    if (!ADDRZ3_n) begin
                        fcs_n_out <= 1'b0;
                        access_state <= ACCESS_Z3;
                    end else if (!MEMZ2_n || !IOZ2_n) begin
                        fcs_n_out <= 1'b0;
                        access_state <= ACCESS_Z2;
                    end else begin
                        access_state <= ACCESS_OTHER;
                    end
                end
            end

            ACCESS_OTHER: begin
                if (cpuclk_rising && AS_n) begin
                    access_state <= ACCESS_IDLE;
                end
            end

            ACCESS_Z3: begin
                case (state)
                    3'd0: begin
                        if (cpuclk_rising) begin
                            // Close A[31:8] latch.
                            aboe_n_out <= 3'b110;

                            state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (cpuclk_falling) begin
                            // Open D[31:0] latch.
                            doe_out <= 1'b1;
                            dboe_n_out <= 2'b00;

                            state <= 3'd2;
                        end
                    end
                    3'd2: begin
                        if (cpuclk_rising) begin
                            // Starting driving EDS_n.
                            eds_n_out <= next_z3_eds_n;

                            // Start driving cache inhibit.
                            ciin_n_out <= CINH_n;
                            ciin_n_oe <= 1'b1;

                            terminate_access_counter <= 8'd40;

                            state <= 3'd3;
                        end
                    end
                    3'd3: begin
                        if (cpuclk_rising) begin
                            if (!dtack_n_sync[0] || terminate_access_counter == 8'd0) begin
                                dsack_n_out <= 2'b00;
                                dsack_n_oe <= 1'b1;

                                state <= 3'd4;
                            end else begin
                                terminate_access_counter <= terminate_access_counter - 8'd1;
                            end
                        end
                    end
                    3'd4: begin
                        if (cpuclk_rising && AS_n) begin
                            fcs_n_out <= 1'b1;
                            eds_n_out <= 4'b1111;

                            dboe_n_out <= 2'b11;

                            // DSACK_n is negated earlier than for real Buster.
                            // I think this shouldn't be possible to observe for the Zorro board.
                            // Negate DSACK_n/CIIN_n.
                            dsack_n_out <= 2'b11;
                            ciin_n_out <= 1'b1;

                            state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        // DOE is negated 10 ns later than FCS_n to mimic Buster timing.
                        // Likely it would have been okay to negate it at the same time as FCS_n.
                        doe_out <= 1'b0;

                        if (cpuclk_falling) begin
                            // Stop driving DSACK_n/CIIN_n.
                            dsack_n_oe <= 1'b0;
                            ciin_n_oe <= 1'b0;

                            state <= 3'd6;
                        end
                    end
                    3'd6: begin
                        if (cpuclk_falling) begin
                            aboe_n_out <= 3'b000;

                            state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                endcase
            end

            ACCESS_Z2: begin
                case (state)
                    3'd0: begin
                        if (cpuclk_rising) begin
                            drive_word_address <= 1'b1;

                            aboe_n_out <= 3'b100;

                            dblt_out <= RW;

                            if (!IOZ2_n) begin
                                ciin_n_out <= 1'b0;
                                ciin_n_oe <= 1'b1;
                            end

                            state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (cpuclk_falling) begin
                            // The address has now been stable for 20 ns.
                            state <= 3'd2;
                        end
                    end
                    3'd2: begin
                        if (z2_state == 3'd6 && c7m_falling) begin
                            state <= 3'd3;
                        end
                    end
                    3'd3: begin
                        if (cpuclk_rising) begin
                            dsack_n_out <= 2'b01;
                            dsack_n_oe <= 1'b1;

                            state <= 3'd4;
                        end
                    end
                    3'd4: begin
                        if (cpuclk_rising && AS_n) begin
                            fcs_n_out <= 1'b1;

                            aboe_n_out <= 3'b110;
                            dboe_n_out <= 2'b11;

                            dblt_out <= 1'b0;

                            drive_word_address <= 1'b0;

                            // Negate DSACK_n/CIIN_n.
                            dsack_n_out <= 2'b11;
                            ciin_n_out <= 1'b1;

                            state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        if (cpuclk_falling) begin
                            // Stop driving DSACK_n/CIIN_n.
                            dsack_n_oe <= 1'b0;
                            ciin_n_oe <= 1'b0;

                            state <= 3'd6;
                        end
                    end
                    3'd6: begin
                        if (cpuclk_falling) begin
                            aboe_n_out <= 3'b000;

                            state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                endcase

                case (z2_state)
                    3'd0: begin
                        if (state == 3'd1 && cpuclk_falling) begin
                            // The address has now been stable for 20 ns.
                            z2_state <= 3'd1;
                        end
                    end
                    3'd1: begin
                        if (c7m_rising) begin
                            ccs_n_out <= 1'b0;

                            if (RW)
                                eds_n_out <= next_z2_eds_n;

                            if (!RW)
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
                            if (!RW)
                                eds_n_out <= next_z2_eds_n;

                            if (RW)
                                dboe_n_out <= 2'b01;

                            doe_out <= 1'b1;

                            if (XRDY && OVR_n)
                                dtack_n_oe <= 1'b1;

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
        endcase
    end
end

endmodule

module bus_arbitration(
    input clk100,

    input cpuclk_rising,
    input cpuclk_falling,

    input c7m_in,

    input reset_n_in,

    input access_state_idle,

    output reg [1:0] bm_state,

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

    input ebgack_n_in,

    input own_n_in,
    output reg own_n_out,
    output reg own_n_oe,

    output reg [3:1] ea_oe,
    output reg read_oe,
    output reg doe_oe,
    output reg fcs_n_oe,
    output reg ccs_n_oe,
    output reg [3:0] eds_n_oe,

    output reg [3:0] a_oe,
    output reg [1:0] siz_oe,
    output reg rw_oe,
    output reg as_n_oe,
    output reg ds_n_oe
);

// Synchronize asynchronous signals.
reg [2:0] c7m_sync;
reg [2:0] reset_n_sync;

reg [2:0] bg_n_sync;
reg [2:0] bgack_n_sync;
reg [2:0] sbr_n_sync;
reg [2:0] ebgack_n_sync;
reg [2:0] own_n_sync;

always @(posedge clk100) begin
    c7m_sync <= {c7m_sync[1:0], c7m_in};
    reset_n_sync <= {reset_n_sync[1:0], reset_n_in};

    bg_n_sync <= {bg_n_sync[1:0], bg_n_in};
    bgack_n_sync <= {bgack_n_sync[1:0], bgack_n_in};
    sbr_n_sync <= {sbr_n_sync[1:0], sbr_n_in};
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

//reg [1:0] bm_state;

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

// State machine.
always @(posedge clk100) begin

    if (!reset_n_sync[1]) begin // In reset.
        // Output pins.
        br_n_out <= 1'b0;
        br_n_oe <= 1'b0;

        bgack_n_out <= 1'b1;
        bgack_n_oe <= 1'b0;

        sbg_n_out <= 1'b1;
        sbg_n_oe <= 1'b0;

        ebg_n_out <= 5'b11111;
        ebg_n_oe <= 5'b00000;

        own_n_out <= 1'b1;
        own_n_oe <= 1'b0;

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
                            // TODO: Borde negera BR även om lämnar detta tillstånd onormalt tidigt.
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

module access(
    input clk100,

    input cpuclk_rising,
    input cpuclk_falling,
    input clk90_rising,
    input clk90_falling,

    input c7m_in,

    input reset_n_in,

    input [1:0] bm_state,

    output access_state_idle,

    input addrz3_n_in,
    input memz2_n_in,
    input ioz2_n_in,
    input wait_n_in,

    input cbreq_n_in,
    output reg cback_n_out = 1'b1,

    output reg [2:0] aboe_n_out = 3'b111,
    output reg [2:0] aboe_n_oe = 3'b000,

    output reg [1:0] dboe_n_out = 2'b11,
    output reg [1:0] dboe_n_oe = 2'b00,

    output reg db16_n_out = 1'b1,
    output reg db16_n_oe = 1'b0,

    output reg d2p_n_out = 1'b1,
    output reg d2p_n_oe = 1'b0,

    output reg dblt_out = 1'b0,
    output reg dblt_oe = 1'b0,

    output reg bigz_n_out = 1'b1,
    output reg bigz_n_oe = 1'b0,

    // CPU control.
    input [3:0] a_in,
    output reg [3:0] a_out = 4'b000,

    input [1:0] siz_in,
    output reg [1:0] siz_out = 2'b00,

    input rw_in,
    output reg rw_out = 1'b1,

    input as_n_in,
    output reg as_n_out = 1'b1,

    input ds_n_in,
    output reg ds_n_out = 1'b1,

    // CPU access termination.
    input [1:0] dsack_n_in,
    output reg [1:0] dsack_n_out = 1'b1,
    output reg [1:0] dsack_n_oe = 1'b0,

    input sterm_n_in,
    output reg sterm_n_out = 1'b1,
    output reg sterm_n_oe = 1'b0,

    input ciin_n_in,
    output reg ciin_n_out = 1'b1,
    output reg ciin_n_oe = 1'b0,

    input rmc_n_in,
    output reg rmc_n_out = 1'b1,

    // Zorro control.
    input [3:1] ea_in,
    output reg [3:1] ea_out = 3'b000,

    input read_in,
    output reg read_out = 1'b1,

    input fcs_n_in,
    output reg fcs_n_out = 1'b1,

    input ccs_n_in,
    output reg ccs_n_out = 1'b1,

    input doe_in,
    output reg doe_out = 1'b0,
    output reg doe_z2_master_oe = 1'b0,

    input [3:0] eds_n_in,
    output reg [3:0] eds_n_out = 4'b1111,

    // Zorro access termination.
    input dtack_n_in,
    output reg dtack_n_out = 1'b1,
    output reg dtack_n_oe = 1'b0,

    input cinh_n_in,
    output reg cinh_n_out = 1'b1,
    output reg cinh_n_oe = 1'b0,

    input mtcr_n_in,
    output reg mtcr_n_out = 1'b1,
    output reg mtcr_n_oe = 1'b0,

    input mtack_n_in,

    input [4:0] slave_n_in,
    output reg [4:0] slave_n_out = 5'b11111,
    output reg [4:0] slave_n_oe = 5'b00000,

    input [2:0] ms_in,

    input bint_n_in,
    output reg bint_n_out = 1'b1,
    output reg bint_n_oe = 1'b0,

    output reg berr_n_out = 1'b1,
    output reg berr_n_oe = 1'b0
);

wire ovr_n_in = cinh_n_in;
wire xrdy_in = mtcr_n_in;

localparam BM_CPU = 2'd0;
localparam BM_Z3 = 2'd2;
localparam BM_Z2 = 2'd3;

// Synchronize asynchronous signals.
reg [2:0] c7m_sync = 3'b000;
reg [2:0] reset_n_sync = 3'b000;

reg [2:0] fcs_n_sync = 3'b111;
reg [2:0] ccs_n_sync = 3'b111;
reg [2:0] dtack_n_sync = 3'b111;
reg [2:0] cinh_n_sync = 3'b111;
reg [2:0] mtcr_n_sync = 3'b111;
reg [2:0] mtack_n_sync = 3'b111;
reg [2:0] bint_n_sync = 3'b111;
reg [2:0] wait_n_sync = 3'b111;
reg [2:0] any_slave_asserted_sync = 3'b000;
reg [2:0] slave_collision_sync = 3'b000;

reg [2:0] all_eds_n_sync = 3'b111;
reg [3:0] both_dsack_asserted_sync = 4'b0000;
reg [3:0] dsack1_only_sync = 4'b0000;
reg [3:0] single_dsack_asserted_sync = 4'b0000;

wire [4:0] slave_asserted_in = ~slave_n_in;
wire any_slave_asserted_in = |slave_asserted_in;
wire multiple_slaves_asserted_in =
    (slave_asserted_in[0] && |slave_asserted_in[4:1]) ||
    (slave_asserted_in[1] && |slave_asserted_in[4:2]) ||
    (slave_asserted_in[2] && |slave_asserted_in[4:3]) ||
    (slave_asserted_in[3] && slave_asserted_in[4]);

always @(posedge clk100) begin
    c7m_sync <= {c7m_sync[1:0], c7m_in};
    reset_n_sync <= {reset_n_sync[1:0], reset_n_in};

    fcs_n_sync <= {fcs_n_sync[1:0], fcs_n_in};
    ccs_n_sync <= {ccs_n_sync[1:0], ccs_n_in};
    dtack_n_sync <= {dtack_n_sync[1:0], dtack_n_in};
    cinh_n_sync <= {cinh_n_sync[1:0], cinh_n_in};
    mtcr_n_sync <= {mtcr_n_sync[1:0], mtcr_n_in};
    mtack_n_sync <= {mtack_n_sync[1:0], mtack_n_in};
    bint_n_sync <= {bint_n_sync[1:0], bint_n_in};
    wait_n_sync <= {wait_n_sync[1:0], wait_n_in};
    any_slave_asserted_sync <= {any_slave_asserted_sync[1:0], any_slave_asserted_in};
    slave_collision_sync <= {slave_collision_sync[1:0], multiple_slaves_asserted_in};

    all_eds_n_sync <= {all_eds_n_sync[1:0], &eds_n_in};
    both_dsack_asserted_sync <= {both_dsack_asserted_sync[2:0], dsack_n_in == 2'b00};
    dsack1_only_sync <= {dsack1_only_sync[2:0], dsack_n_in == 2'b01};
    single_dsack_asserted_sync <= {single_dsack_asserted_sync[2:0],
        dsack_n_in == 2'b01 || dsack_n_in == 2'b10};
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
reg cpu_to_z2_mem_cycle = 1'b0;
reg cpu_to_z2_io_cycle = 1'b0;

always @(*) begin
    if (cpu_to_z2_mem_cycle && rw_in) begin
        next_z2_eds_n <= 4'b0011;
    end else if (!a_in[0]) begin // Even address.
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

wire zorro2_space_selected = !memz2_n_in || !ioz2_n_in;

// State.
localparam ACCESS_IDLE = 4'd0;
localparam ACCESS_CPU_TO_Z3 = 4'd1;
localparam ACCESS_CPU_TO_Z2 = 4'd2;
localparam ACCESS_CPU_TO_OTHER = 4'd3;
localparam ACCESS_Z3_TO_CPU = 4'd4;
localparam ACCESS_ZORRO_LOCAL = 4'd5;
localparam ACCESS_Z2_TO_CPU = 4'd6;
localparam ACCESS_ERROR = 4'd7;
localparam ACCESS_CPU_QUICK_INTERRUPT = 4'd8;

reg [3:0] access_state = ACCESS_IDLE;

reg [2:0] address_decode_stable = 3'b000;
reg [1:0] sterm_n_delayed = 2'b11;
reg [1:0] addrz3_n_delayed = 2'b11;

reg [3:0] cpu_to_z3_state = 4'd0;
reg [7:0] terminate_access_counter = 8'd0;
reg [1:0] cpu_to_z3_mtc_address = 2'b00;
reg [1:0] cpu_to_z3_mtc_count = 2'd0;
reg cpu_to_z3_mtc_active = 1'b0;
reg cpu_to_z3_mtc_continue = 1'b0;
// Sampled at MTCR* assertion; if clear, the current beat is the last one.
reg cpu_to_z3_mtc_slave_continue = 1'b0;

reg [2:0] cpu_to_z2_state = 3'd0;
reg [2:0] z2_state = 3'd0;
reg cpu_to_z2_rmw_hold = 1'b0;
reg cpu_to_z2_rmw_second = 1'b0;

reg [2:0] z3_to_cpu_state = 3'd0;

reg [2:0] z2_to_cpu_state = 3'd0;

reg [2:0] quick_interrupt_state = 3'd0;
reg [1:0] quick_interrupt_poll_count = 2'd0;
reg [3:0] quick_interrupt_timeout_counter = 4'd0;
reg [4:0] quick_interrupt_requests = 5'b00000;
reg [4:0] quick_interrupt_grant = 5'b00000;

reg bus_error_active = 1'b0;
reg bus_error_drive_bint = 1'b0;

assign access_state_idle = access_state == ACCESS_IDLE;

wire zorro_cycle_state =
    access_state == ACCESS_CPU_TO_Z3 ||
    access_state == ACCESS_CPU_TO_Z2 ||
    access_state == ACCESS_Z3_TO_CPU ||
    access_state == ACCESS_ZORRO_LOCAL ||
    access_state == ACCESS_Z2_TO_CPU ||
    access_state == ACCESS_CPU_QUICK_INTERRUPT;

wire zorro_local_translation_state =
    access_state == ACCESS_Z3_TO_CPU ||
    access_state == ACCESS_Z2_TO_CPU;

wire quick_interrupt_cycle_state =
    access_state == ACCESS_CPU_QUICK_INTERRUPT;

wire slave_collision =
    !quick_interrupt_cycle_state &&
    (multiple_slaves_asserted_in ||
        slave_collision_sync[1] ||
        (zorro_local_translation_state && any_slave_asserted_in));

wire cpu_quick_interrupt_request =
    ms_in == 3'b111 &&
    rw_in &&
    (a_in[3:1] == 3'd2 || a_in[3:1] == 3'd6);

wire [4:0] quick_interrupt_pending_requests =
    quick_interrupt_requests | slave_asserted_in;

wire [4:0] next_quick_interrupt_grant =
    quick_interrupt_pending_requests[0] ? 5'b00001 :
    quick_interrupt_pending_requests[1] ? 5'b00010 :
    quick_interrupt_pending_requests[2] ? 5'b00100 :
    quick_interrupt_pending_requests[3] ? 5'b01000 :
    quick_interrupt_pending_requests[4] ? 5'b10000 : 5'b00000;

wire cpu_to_z3_timeout =
    access_state == ACCESS_CPU_TO_Z3 &&
    cpu_to_z3_state == 4'd3 &&
    clk90_rising &&
    dtack_n_sync[1] &&
    terminate_access_counter == 8'd0;

wire cpu_to_z3_mtc_supported =
    !cbreq_n_in && !mtack_n_sync[1];

wire cpu_to_z3_mtc_can_continue =
    cpu_to_z3_mtc_active &&
    !cbreq_n_in &&
    cpu_to_z3_mtc_slave_continue &&
    cpu_to_z3_mtc_count != 2'd3;

wire [1:0] next_cpu_to_z3_mtc_address = cpu_to_z3_mtc_address + 2'd1;

wire cpu_to_z2_rmw_address_error =
    access_state == ACCESS_CPU_TO_Z2 &&
    cpu_to_z2_state == 3'd7 &&
    cpuclk_falling &&
    !as_n_in &&
    address_decode_stable[2] &&
    !zorro2_space_selected;

wire z3_to_cpu_valid_local_termination =
    both_dsack_asserted_sync[3] ||
    !sterm_n_delayed[1];

wire z2_to_cpu_valid_local_termination =
    both_dsack_asserted_sync[3] ||
    dsack1_only_sync[3] ||
    !sterm_n_delayed[1];

wire z3_to_cpu_invalid_termination =
    access_state == ACCESS_Z3_TO_CPU &&
    z3_to_cpu_state == 3'd3 &&
    cpuclk_falling &&
    !z3_to_cpu_valid_local_termination &&
    single_dsack_asserted_sync[3];

wire z3_to_cpu_timeout =
    access_state == ACCESS_Z3_TO_CPU &&
    z3_to_cpu_state == 3'd3 &&
    cpuclk_falling &&
    !z3_to_cpu_valid_local_termination &&
    !single_dsack_asserted_sync[3] &&
    terminate_access_counter == 8'd0;

wire z2_to_cpu_timeout =
    access_state == ACCESS_Z2_TO_CPU &&
    z2_to_cpu_state == 3'd3 &&
    cpuclk_falling &&
    !z2_to_cpu_valid_local_termination &&
    terminate_access_counter == 8'd0;

wire zorro_master_local_error =
    z3_to_cpu_timeout ||
    z2_to_cpu_timeout ||
    z3_to_cpu_invalid_termination;

wire zorro_error_request =
    (zorro_cycle_state &&
        (!bint_n_in || !bint_n_sync[1] || slave_collision)) ||
    cpu_to_z3_timeout ||
    cpu_to_z2_rmw_address_error ||
    zorro_master_local_error;

wire z2_sloppy_lines_idle =
    dtack_n_in && dtack_n_sync[1] &&
    mtcr_n_in && mtcr_n_sync[1] &&
    cinh_n_in && cinh_n_sync[1] &&
    !any_slave_asserted_in && !any_slave_asserted_sync[1];

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

        cback_n_out <= 1'b1;

        // CPU control.
        a_out <= 4'b0000;
        siz_out <= 2'b00;
        rw_out <= 1'b1;
        as_n_out <= 1'b1;
        ds_n_out <= 1'b1;
        rmc_n_out <= 1'b1;

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
        doe_z2_master_oe <= 1'b0;
        eds_n_out <= 4'b1111;

        // Zorro access termination.
        dtack_n_out <= 1'b1;
        dtack_n_oe <= 1'b0;

        cinh_n_out <= 1'b1;
        cinh_n_oe <= 1'b0;

        mtcr_n_out <= 1'b1;
        mtcr_n_oe <= 1'b0;

        slave_n_out <= 5'b11111;
        slave_n_oe <= 5'b00000;

        bint_n_out <= 1'b1;
        bint_n_oe <= 1'b0;

        berr_n_out <= 1'b1;
        berr_n_oe <= 1'b0;

        // Internal state.
        access_state <= ACCESS_IDLE;

        cpu_to_z3_state <= 4'd0;
        cpu_to_z3_mtc_address <= 2'b00;
        cpu_to_z3_mtc_count <= 2'd0;
        cpu_to_z3_mtc_active <= 1'b0;
        cpu_to_z3_mtc_continue <= 1'b0;
        cpu_to_z3_mtc_slave_continue <= 1'b0;

        terminate_access_counter <= 8'd0;

        cpu_to_z2_state <= 3'd0;
        z2_state <= 3'd0;
        cpu_to_z2_mem_cycle <= 1'b0;
        cpu_to_z2_io_cycle <= 1'b0;
        cpu_to_z2_rmw_hold <= 1'b0;
        cpu_to_z2_rmw_second <= 1'b0;

        z3_to_cpu_state <= 3'd0;

        z2_to_cpu_state <= 3'd0;

        quick_interrupt_state <= 3'd0;
        quick_interrupt_poll_count <= 2'd0;
        quick_interrupt_timeout_counter <= 4'd0;
        quick_interrupt_requests <= 5'b00000;
        quick_interrupt_grant <= 5'b00000;

        bus_error_active <= 1'b0;
        bus_error_drive_bint <= 1'b0;

    end else if (!reset_n_sync[2]) begin // Coming out of reset.

        aboe_n_oe <= 3'b111;
        dboe_n_oe <= 2'b11;
        db16_n_oe <= 1'b1;
        d2p_n_oe <= 1'b1;
        dblt_oe <= 1'b1;

        bigz_n_oe <= 1'b1;

    end else begin // Normal operations.

        if (zorro_error_request && access_state != ACCESS_ERROR) begin
            bus_error_active <= 1'b1;
            bus_error_drive_bint <= slave_collision || zorro_master_local_error;

            berr_n_out <= 1'b0;
            berr_n_oe <= 1'b1;

            if (slave_collision || zorro_master_local_error) begin
                bint_n_out <= 1'b0;
                bint_n_oe <= 1'b1;
            end

            fcs_n_out <= 1'b1;
            ccs_n_out <= 1'b1;
            doe_out <= 1'b0;
            doe_z2_master_oe <= 1'b0;
            eds_n_out <= 4'b1111;

            dboe_n_out <= 2'b11;
            db16_n_out <= 1'b1;
            dblt_out <= 1'b0;
            bigz_n_out <= 1'b1;
            cback_n_out <= 1'b1;

            dsack_n_out <= 2'b11;
            dsack_n_oe <= 2'b00;
            sterm_n_out <= 1'b1;
            sterm_n_oe <= 1'b0;
            ciin_n_out <= 1'b1;
            ciin_n_oe <= 1'b0;

            dtack_n_out <= 1'b1;
            dtack_n_oe <= 1'b0;
            cinh_n_out <= 1'b1;
            cinh_n_oe <= 1'b0;
            mtcr_n_out <= 1'b1;
            mtcr_n_oe <= 1'b0;
            slave_n_out <= 5'b11111;
            slave_n_oe <= 5'b00000;

            as_n_out <= 1'b1;
            ds_n_out <= 1'b1;
            rmc_n_out <= 1'b1;

            cpu_to_z3_state <= 4'd0;
            cpu_to_z3_mtc_address <= 2'b00;
            cpu_to_z3_mtc_count <= 2'd0;
            cpu_to_z3_mtc_active <= 1'b0;
            cpu_to_z3_mtc_continue <= 1'b0;
            cpu_to_z3_mtc_slave_continue <= 1'b0;
            terminate_access_counter <= 8'd0;
            cpu_to_z2_state <= 3'd0;
            z2_state <= 3'd0;
            cpu_to_z2_mem_cycle <= 1'b0;
            cpu_to_z2_io_cycle <= 1'b0;
            cpu_to_z2_rmw_hold <= 1'b0;
            cpu_to_z2_rmw_second <= 1'b0;
            z3_to_cpu_state <= 3'd0;
            z2_to_cpu_state <= 3'd0;
            quick_interrupt_state <= 3'd0;
            quick_interrupt_poll_count <= 2'd0;
            quick_interrupt_timeout_counter <= 4'd0;
            quick_interrupt_requests <= 5'b00000;
            quick_interrupt_grant <= 5'b00000;

            access_state <= ACCESS_ERROR;

        end else begin
        case (access_state)
            ACCESS_IDLE: begin
                aboe_n_out <= bm_state == BM_Z2 ? 3'b100 : 3'b000;
                bigz_n_out <= 1'b1;
                doe_z2_master_oe <= 1'b0;

                case (bm_state)
                    BM_CPU: begin
                        // Rising edge going from S1 to S2.
                        if (cpuclk_rising && !as_n_in) begin
                            // If this later turns out to be a Z2 access then
                            // ea_out has to be updated.
                            if (cpu_quick_interrupt_request) begin
                                ea_out <= a_in[3:1];
                                read_out <= 1'b1;
                            end else begin
                                ea_out <= {a_in[3:2], rmc_n_in};
                                read_out <= rw_in;
                            end

                            d2p_n_out <= !rw_in;
                        end

                        // Falling edge going from S2 to S3.
                        // This should give address decoder enough time.
                        if (cpuclk_falling && !as_n_in && address_decode_stable[2]) begin
                            if (cpu_quick_interrupt_request &&
                                    addrz3_n_in && memz2_n_in && ioz2_n_in &&
                                    wait_n_sync[1]) begin
                                fcs_n_out <= 1'b0;
                                mtcr_n_out <= 1'b0;
                                mtcr_n_oe <= 1'b1;
                                quick_interrupt_state <= 3'd0;
                                quick_interrupt_poll_count <= 2'd0;
                                quick_interrupt_timeout_counter <= 4'd0;
                                quick_interrupt_requests <= 5'b00000;
                                quick_interrupt_grant <= 5'b00000;
                                access_state <= ACCESS_CPU_QUICK_INTERRUPT;
                            end else if (!addrz3_n_in && wait_n_sync[1]) begin
                                fcs_n_out <= 1'b0;
                                access_state <= ACCESS_CPU_TO_Z3;
                            end else if (zorro2_space_selected &&
                                    wait_n_sync[1] && z2_sloppy_lines_idle) begin
                                fcs_n_out <= 1'b0;
                                cpu_to_z2_mem_cycle <= !memz2_n_in;
                                cpu_to_z2_io_cycle <= !ioz2_n_in;
                                access_state <= ACCESS_CPU_TO_Z2;
                            end else if (addrz3_n_in && memz2_n_in && ioz2_n_in) begin
                                access_state <= ACCESS_CPU_TO_OTHER;
                            end
                        end
                    end

                    BM_Z3: begin
                        if (!fcs_n_sync[1]) begin
                            if (!addrz3_n_delayed[1]) begin
                                access_state <= ACCESS_ZORRO_LOCAL;
                            end else begin
                                access_state <= ACCESS_Z3_TO_CPU;
                            end
                        end
                    end

                    BM_Z2: begin
                        if (!ccs_n_sync[1]) begin
                            doe_out <= 1'b1;
                            doe_z2_master_oe <= 1'b1;

                            if (zorro2_space_selected) begin
                                access_state <= ACCESS_ZORRO_LOCAL;
                            end else begin
                                bigz_n_out <= 1'b0;
                                access_state <= ACCESS_Z2_TO_CPU;
                            end
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
                ea_out[1] <= rmc_n_in;

                case (cpu_to_z3_state)
                    4'd0: begin
                        if (cpuclk_rising) begin
                            // Close A[31:8] latch.
                            aboe_n_out <= 3'b110;

                            cpu_to_z3_mtc_address <= a_in[3:2];
                            cpu_to_z3_mtc_count <= 2'd0;
                            cpu_to_z3_mtc_active <= 1'b0;
                            cpu_to_z3_mtc_continue <= 1'b0;
                            cpu_to_z3_mtc_slave_continue <= 1'b0;

                            cpu_to_z3_state <= 4'd1;
                        end
                    end
                    4'd1: begin
                        if (cpuclk_falling) begin
                            // Open D[31:0] latch.
                            doe_out <= 1'b1;
                            dboe_n_out <= 2'b00;

                            cpu_to_z3_state <= 4'd2;
                        end
                    end
                    4'd2: begin
                        if (cpuclk_rising) begin
                            // Starting driving EDS_n.
                            eds_n_out <= next_z3_eds_n;

                            if (cpu_to_z3_mtc_supported) begin
                                mtcr_n_out <= 1'b0;
                                mtcr_n_oe <= 1'b1;
                                cback_n_out <= 1'b0;
                                cpu_to_z3_mtc_active <= 1'b1;
                                cpu_to_z3_mtc_slave_continue <= 1'b1;
                            end else begin
                                mtcr_n_out <= 1'b1;
                                mtcr_n_oe <= 1'b0;
                                cback_n_out <= 1'b1;
                                cpu_to_z3_mtc_slave_continue <= 1'b0;
                            end

                            terminate_access_counter <= 8'd40;

                            cpu_to_z3_state <= 4'd3;
                        end
                    end
                    4'd3: begin
                        if (cpuclk_falling) begin
                            // Start driving cache inhibit.
                            // Must be stable on rising CPUCLK.
                            ciin_n_out <= cinh_n_in;
                            ciin_n_oe <= 1'b1;
                        end

                        if (clk90_rising) begin
                            if (!dtack_n_sync[1]) begin
                                sterm_n_out <= 1'b0;
                                sterm_n_oe <= 1'b1;

                                if (cpu_to_z3_mtc_active) begin
                                    cpu_to_z3_mtc_continue <= cpu_to_z3_mtc_can_continue;

                                    if (!cpu_to_z3_mtc_can_continue) begin
                                        cback_n_out <= 1'b1;
                                    end

                                    if (cpu_to_z3_mtc_count != 2'd3) begin
                                        cpu_to_z3_mtc_count <= cpu_to_z3_mtc_count + 2'd1;
                                    end
                                end

                                cpu_to_z3_state <= 4'd4;
                            end else if (terminate_access_counter != 8'd0) begin
                                terminate_access_counter <= terminate_access_counter - 8'd1;
                            end
                        end
                    end
                    4'd4: begin
                        if (clk90_rising && cpu_to_z3_mtc_active &&
                                cpu_to_z3_mtc_continue && !as_n_in) begin
                            mtcr_n_out <= 1'b1;
                            eds_n_out <= 4'b1111;
                            sterm_n_out <= 1'b1;
                            ciin_n_out <= 1'b1;

                            cpu_to_z3_mtc_address <= next_cpu_to_z3_mtc_address;
                            ea_out[3:2] <= next_cpu_to_z3_mtc_address;

                            terminate_access_counter <= 8'd40;

                            cpu_to_z3_state <= 4'd7;
                        end else if (clk90_rising && as_n_in) begin
                            fcs_n_out <= 1'b1;
                            mtcr_n_out <= 1'b1;
                            mtcr_n_oe <= 1'b0;
                            eds_n_out <= 4'b1111;

                            dboe_n_out <= 2'b11;
                            cback_n_out <= 1'b1;

                            // Negate STERM_n/CIIN_n.
                            sterm_n_out <= 1'b1;
                            ciin_n_out <= 1'b1;

                            cpu_to_z3_mtc_active <= 1'b0;
                            cpu_to_z3_mtc_continue <= 1'b0;
                            cpu_to_z3_mtc_slave_continue <= 1'b0;

                            cpu_to_z3_state <= 4'd5;
                        end
                    end
                    4'd5: begin
                        // DOE is negated 10 ns later than FCS_n to mimic Buster timing.
                        // Likely it would have been okay to negate it at the same time as FCS_n.
                        doe_out <= 1'b0;

                        if (cpuclk_falling) begin
                            // Stop driving STERM_n/CIIN_n.
                            sterm_n_oe <= 1'b0;
                            ciin_n_oe <= 1'b0;

                            cpu_to_z3_state <= 4'd6;
                        end
                    end
                    4'd6: begin
                        if (cpuclk_falling) begin
                            aboe_n_out <= 3'b000;

                            cpu_to_z3_state <= 4'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                    4'd7: begin
                        if (clk90_rising) begin
                            mtcr_n_out <= 1'b0;
                            eds_n_out <= 4'b0000;
                            cpu_to_z3_mtc_slave_continue <= !mtack_n_sync[1];

                            cpu_to_z3_state <= 4'd3;
                        end
                    end
                endcase
            end

            ACCESS_CPU_QUICK_INTERRUPT: begin
                case (quick_interrupt_state)
                    3'd0: begin
                        quick_interrupt_requests <= quick_interrupt_pending_requests;

                        if (cpuclk_rising) begin
                            // Expose A23-A8 and A7-A4/FC during the poll phase.
                            aboe_n_out <= 3'b100;
                        end

                        if (clk90_rising) begin
                            if (quick_interrupt_poll_count == 2'd1) begin
                                mtcr_n_out <= 1'b1;
                                quick_interrupt_grant <= next_quick_interrupt_grant;

                                if (next_quick_interrupt_grant == 5'b00000) begin
                                    fcs_n_out <= 1'b1;
                                    mtcr_n_oe <= 1'b0;
                                    aboe_n_out <= 3'b000;
                                    quick_interrupt_state <= 3'd0;
                                    access_state <= ACCESS_CPU_TO_OTHER;
                                end else begin
                                    doe_out <= 1'b1;
                                    dboe_n_out <= 2'b00;
                                    quick_interrupt_timeout_counter <= 4'd10;
                                    quick_interrupt_state <= 3'd1;
                                end
                            end else begin
                                quick_interrupt_poll_count <= quick_interrupt_poll_count + 2'd1;
                            end
                        end
                    end
                    3'd1: begin
                        if (clk90_rising) begin
                            mtcr_n_out <= 1'b0;
                            slave_n_out <= ~quick_interrupt_grant;
                            slave_n_oe <= quick_interrupt_grant;
                            eds_n_out <= 4'b1110;
                            quick_interrupt_state <= 3'd2;
                        end
                    end
                    3'd2: begin
                        if (!dtack_n_sync[1]) begin
                            sterm_n_out <= 1'b0;
                            sterm_n_oe <= 1'b1;
                            quick_interrupt_state <= 3'd3;
                        end else if (quick_interrupt_timeout_counter == 4'd0) begin
                            fcs_n_out <= 1'b1;
                            mtcr_n_out <= 1'b1;
                            mtcr_n_oe <= 1'b0;
                            slave_n_out <= 5'b11111;
                            slave_n_oe <= 5'b00000;
                            eds_n_out <= 4'b1111;
                            dboe_n_out <= 2'b11;
                            doe_out <= 1'b0;
                            aboe_n_out <= 3'b000;
                            quick_interrupt_state <= 3'd0;
                            access_state <= ACCESS_CPU_TO_OTHER;
                        end else begin
                            quick_interrupt_timeout_counter <= quick_interrupt_timeout_counter - 4'd1;
                        end
                    end
                    3'd3: begin
                        if (clk90_rising && as_n_in) begin
                            fcs_n_out <= 1'b1;
                            mtcr_n_out <= 1'b1;
                            slave_n_out <= 5'b11111;
                            slave_n_oe <= 5'b00000;
                            eds_n_out <= 4'b1111;
                            dboe_n_out <= 2'b11;
                            sterm_n_out <= 1'b1;
                            quick_interrupt_state <= 3'd4;
                        end
                    end
                    3'd4: begin
                        doe_out <= 1'b0;

                        if (cpuclk_falling) begin
                            mtcr_n_oe <= 1'b0;
                            sterm_n_oe <= 1'b0;
                            quick_interrupt_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        if (cpuclk_falling) begin
                            aboe_n_out <= 3'b000;
                            quick_interrupt_state <= 3'd0;
                            quick_interrupt_poll_count <= 2'd0;
                            quick_interrupt_timeout_counter <= 4'd0;
                            quick_interrupt_requests <= 5'b00000;
                            quick_interrupt_grant <= 5'b00000;
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

                            ciin_n_out <= !cpu_to_z2_io_cycle;

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
                            dsack_n_out <= 2'b00;
                            dsack_n_oe <= 2'b10;

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
                            dsack_n_oe <= 2'b00;
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

                            if (cpu_to_z2_rmw_hold) begin
                                cpu_to_z2_state <= 3'd7;
                                cpu_to_z2_mem_cycle <= 1'b0;
                                cpu_to_z2_io_cycle <= 1'b0;
                            end else begin
                                cpu_to_z2_state <= 3'd0;
                                cpu_to_z2_mem_cycle <= 1'b0;
                                cpu_to_z2_io_cycle <= 1'b0;
                                cpu_to_z2_rmw_second <= 1'b0;

                                access_state <= ACCESS_IDLE;
                            end
                        end
                    end
                    3'd7: begin
                        if (rmc_n_in && as_n_in) begin
                            ccs_n_out <= 1'b1;
                            doe_out <= 1'b0;

                            cpu_to_z2_state <= 3'd0;
                            z2_state <= 3'd0;
                            cpu_to_z2_rmw_hold <= 1'b0;
                            cpu_to_z2_rmw_second <= 1'b0;

                            access_state <= ACCESS_IDLE;
                        end else begin
                            if (cpuclk_rising && !as_n_in) begin
                                ea_out <= {a_in[3:2], 1'b1};
                                read_out <= rw_in;
                                d2p_n_out <= !rw_in;
                            end

                            if (cpuclk_falling && !as_n_in && address_decode_stable[2] &&
                                    zorro2_space_selected && wait_n_sync[1] &&
                                    z2_sloppy_lines_idle && z2_state == 3'd0) begin
                                fcs_n_out <= 1'b0;
                                cpu_to_z2_mem_cycle <= !memz2_n_in;
                                cpu_to_z2_io_cycle <= !ioz2_n_in;
                                cpu_to_z2_rmw_hold <= 1'b0;
                                cpu_to_z2_rmw_second <= 1'b1;
                                cpu_to_z2_state <= 3'd0;
                            end
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
                            if (!rmc_n_in && !cpu_to_z2_rmw_second) begin
                                ccs_n_out <= 1'b0;
                                cpu_to_z2_rmw_hold <= 1'b1;
                            end else begin
                                ccs_n_out <= 1'b1;
                                cpu_to_z2_rmw_hold <= 1'b0;
                                cpu_to_z2_rmw_second <= 1'b0;
                            end

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
                            rmc_n_out <= ea_in[1];

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

                            terminate_access_counter <= 8'd40;

                            z3_to_cpu_state <= 3'd3;
                        end
                    end
                    3'd3: begin // S4 -> S5
                        if (cpuclk_falling) begin
                            if (z3_to_cpu_valid_local_termination) begin

                                if (!rw_out) begin
                                    as_n_out <= 1'b1;
                                    ds_n_out <= 1'b1;
                                end

                                dtack_n_out <= 1'b0;
                                dtack_n_oe <= 1'b1;
                                cinh_n_out <= ciin_n_in;
                                cinh_n_oe <= !ciin_n_in;

                                z3_to_cpu_state <= 3'd4;
                            end else if (terminate_access_counter != 8'd0) begin
                                terminate_access_counter <= terminate_access_counter - 8'd1;
                            end
                        end
                    end
                    3'd4: begin
                        if (fcs_n_sync[1]) begin

                            // Stop driving DTACK_n as soon as possible.
                            dtack_n_out <= 1'b1;
                            cinh_n_out <= 1'b1;
                            cinh_n_oe <= 1'b0;

                            // Stop driving data.
                            dboe_n_out <= 2'b11;

                            z3_to_cpu_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        dtack_n_oe <= 1'b0;
                        cinh_n_oe <= 1'b0;

                        if (!rw_out || cpuclk_falling) begin
                            as_n_out <= 1'b1;
                            ds_n_out <= 1'b1;
                            rmc_n_out <= 1'b1;

                            z3_to_cpu_state <= 3'd0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                endcase
            end

            ACCESS_ZORRO_LOCAL: begin
                // This is local to the Zorro bus. No 68030 translation is needed.
                // Access termination is handled by the external Zorro master/slave.
                if (bm_state == BM_Z2) begin
                    doe_out <= 1'b1;
                    doe_z2_master_oe <= 1'b1;
                end

                if (fcs_n_sync[1] && ccs_n_sync[1]) begin
                    doe_out <= 1'b0;
                    doe_z2_master_oe <= 1'b0;
                    access_state <= ACCESS_IDLE;
                end
            end

            ACCESS_Z2_TO_CPU: begin
                bigz_n_out <= 1'b0;

                case (z2_to_cpu_state)
                    3'd0: begin // Entering S0
                        if (cpuclk_rising && !all_eds_n_sync[1]) begin
                            a_out <= next_z2_a;
                            siz_out <= next_z2_siz;
                            rw_out <= read_in;
                            rmc_n_out <= 1'b1;

                            if (!read_in || !ea_in[1]) begin
                                dboe_n_out <= 2'b01;
                            end

                            if (!read_in || ea_in[1]) begin
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

                            terminate_access_counter <= 8'd40;

                            z2_to_cpu_state <= 3'd3;
                        end
                    end
                    3'd3: begin // S4 -> S5
                        if (cpuclk_falling) begin
                            if (both_dsack_asserted_sync[3] || !sterm_n_delayed[1]) begin

                                if (!rw_out) begin
                                    as_n_out <= 1'b1;
                                    ds_n_out <= 1'b1;
                                end

                                dtack_n_out <= 1'b0;
                                dtack_n_oe <= 1'b1;

                                z2_to_cpu_state <= 3'd4;
                            end else if (dsack1_only_sync[3]) begin
                                if (rw_out && !db16_n_out) begin
                                    // Single DSACK1* means a 16-bit local port; if the
                                    // lower-half read bridge was selected, switch before DTACK*.
                                    db16_n_out <= 1'b1;
                                    dboe_n_out <= 2'b01;

                                    z2_to_cpu_state <= 3'd6;
                                end else begin
                                    if (!rw_out) begin
                                        as_n_out <= 1'b1;
                                        ds_n_out <= 1'b1;
                                    end

                                    dtack_n_out <= 1'b0;
                                    dtack_n_oe <= 1'b1;

                                    z2_to_cpu_state <= 3'd4;
                                end
                            end else if (terminate_access_counter != 8'd0) begin
                                terminate_access_counter <= terminate_access_counter - 8'd1;
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
                            doe_out <= 1'b0;
                            doe_z2_master_oe <= 1'b0;

                            z2_to_cpu_state <= 3'd5;
                        end
                    end
                    3'd5: begin
                        dtack_n_oe <= 1'b0;

                        if (!rw_out || cpuclk_falling) begin
                            as_n_out <= 1'b1;
                            ds_n_out <= 1'b1;

                            z2_to_cpu_state <= 3'd0;
                            bigz_n_out <= 1'b1;
                            doe_out <= 1'b0;
                            doe_z2_master_oe <= 1'b0;

                            access_state <= ACCESS_IDLE;
                        end
                    end
                    3'd6: begin
                        if (cpuclk_falling) begin
                            if (!rw_out) begin
                                as_n_out <= 1'b1;
                                ds_n_out <= 1'b1;
                            end

                            dtack_n_out <= 1'b0;
                            dtack_n_oe <= 1'b1;

                            z2_to_cpu_state <= 3'd4;
                        end
                    end

                endcase
            end

            ACCESS_ERROR: begin
                berr_n_out <= 1'b0;
                berr_n_oe <= bus_error_active;

                if (bus_error_drive_bint) begin
                    bint_n_out <= 1'b0;
                    bint_n_oe <= 1'b1;
                end else begin
                    bint_n_out <= 1'b1;
                    bint_n_oe <= 1'b0;
                end

                if (as_n_in && fcs_n_in && ccs_n_in && fcs_n_sync[1] && ccs_n_sync[1]) begin
                    berr_n_out <= 1'b1;
                    berr_n_oe <= 1'b0;
                    bint_n_out <= 1'b1;
                    bint_n_oe <= 1'b0;

                    bus_error_active <= 1'b0;
                    bus_error_drive_bint <= 1'b0;

                    access_state <= ACCESS_IDLE;
                end
            end
        endcase
        end
    end
end

endmodule

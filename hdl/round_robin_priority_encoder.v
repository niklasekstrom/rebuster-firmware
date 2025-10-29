module round_robin_priority_encoder(
    input [4:0] requests,
    input [4:0] previous_grant,
    output [4:0] grant
);

assign grant =
    previous_grant[0] ? (
        requests[1] ? 5'b00010 :
        requests[2] ? 5'b00100 :
        requests[3] ? 5'b01000 :
        requests[4] ? 5'b10000 :
        requests[0] ? 5'b00001 : 5'b00000
    ) :
    previous_grant[1] ? (
        requests[2] ? 5'b00100 :
        requests[3] ? 5'b01000 :
        requests[4] ? 5'b10000 :
        requests[0] ? 5'b00001 :
        requests[1] ? 5'b00010 : 5'b00000
    ) :
    previous_grant[2] ? (
        requests[3] ? 5'b01000 :
        requests[4] ? 5'b10000 :
        requests[0] ? 5'b00001 :
        requests[1] ? 5'b00010 :
        requests[2] ? 5'b00100 : 5'b00000
    ) :
    previous_grant[3] ? (
        requests[4] ? 5'b10000 :
        requests[0] ? 5'b00001 :
        requests[1] ? 5'b00010 :
        requests[2] ? 5'b00100 :
        requests[3] ? 5'b01000 : 5'b00000
    ) :
    (
        requests[0] ? 5'b00001 :
        requests[1] ? 5'b00010 :
        requests[2] ? 5'b00100 :
        requests[3] ? 5'b01000 :
        requests[4] ? 5'b10000 : 5'b00000
    );

endmodule

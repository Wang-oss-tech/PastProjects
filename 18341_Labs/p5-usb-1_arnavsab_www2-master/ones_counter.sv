`default_nettype none

// ones counter used by bit unstuffer for the packet receiver
/*
  asserts halt to indicate the crc checker to pause for a cycle
*/
module ones_counter(
    input bus_state_t busIn,
    input logic clock, reset_n,
    input logic [`COUNT_BITS - 1 : 0] seen,
    output logic halt);

    logic [2 : 0] ones_count;

    always_ff @(posedge clock) begin
        if (~reset_n) begin
            ones_count <= 0;
        end
        else if ((seen >= `SYNC_BITS + (`PID_BITS << 1)) && busIn == BS_J) begin
            ones_count <= ones_count + 1;
        end else begin
            ones_count <= 0;
        end
    end

    assign halt = (ones_count == 6);
endmodule: ones_counter
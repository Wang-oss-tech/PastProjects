`default_nettype none

// seen counter for the packet receiver, counts the bits that have been 
// already seen

module seenCounter(
    input logic clock, reset_n,
    input logic enSeen,
    output logic [`COUNT_BITS - 1 : 0] seen);

    always_ff @(posedge clock) begin
        if (~reset_n) begin
            seen <= 0;
        end
        else if (enSeen) begin
            seen <= seen + 1;
        end
        else begin
          seen <= seen;
        end
    end

endmodule: seenCounter
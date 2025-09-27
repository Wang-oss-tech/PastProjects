`default_nettype none

// State of current phase (for testbench)
// enum logic [2:0] {SYNC, PID, ADDR, ENDP, DATA, CRC} CURRENT_PHASE;

module NRZI(
    input logic clock, reset_n,
    input logic bit_in,
    output logic nrzi_out);

    enum logic [1:0] {ZERO_STATE, ONE_STATE} currState, nextState;

    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currState <= ZERO_STATE;
        end
        else begin
            currState <= nextState;
        end
    end

    // FSM
        always_comb begin
        case(currState)
            ZERO_STATE: begin
                if(bit_in == 1) begin
                    nextState <= ZERO_STATE;
                    nrzi_out <= 1;
                end else if (bit_in == 0) begin
                    nextState <= ONE_STATE;
                    nrzi_out <= 0;
                end
            end
            ONE_STATE: begin
                if(bit_in == 1) begin
                    nextState <= ONE_STATE;
                    nrzi_out <= 0;
                end else if (bit_in == 0) begin
                    nextState <= ZERO_STATE;
                    nrzi_out <= 1;
                end
            end
        endcase
    end
endmodule : NRZI
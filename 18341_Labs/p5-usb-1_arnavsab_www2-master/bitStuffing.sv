`default_nettype none

// State of current phase (for testbench)
// enum logic [2:0] {SYNC, PID, ADDR, ENDP, DATA, CRC} CURRENT_PHASE;

// Manages bit stuffing for serial data based on phase.
module bitStuffing(
    input logic clock, reset_n,
    input logic bit_in,
    input phase_t CURRENT_PHASE, 
    output logic [2 : 0] ones_count,
    output logic bit_out,
    output logic halt);

    // State definition
    enum logic {IDLE, SIX_ONES_DETECTED} currState, nextState;

    // counter (datapath)
    always_ff @(posedge clock, negedge reset_n) begin
        if (ones_count == 6) begin
          ones_count <= 0;
        end
        else if (CURRENT_PHASE != SYNC_P && CURRENT_PHASE != PID_P 
        && CURRENT_PHASE != EOP_P && bit_in == 1) 
        begin
            ones_count <= ones_count + 1;
        end
        else begin
            ones_count <= 0; // reset counter 
        end
    end

    // Sequential logic to drive state
    always_ff @(posedge clock, negedge reset_n) begin
        if (~reset_n) begin
            currState <= IDLE;
        end
        else begin
            currState <= nextState;
        end
    end

    // FSM
    always_comb begin
        case(currState)
            IDLE: begin
                if (ones_count != 6) begin
                    nextState <= IDLE;
                    bit_out <= bit_in;
                    halt = 1'b0;
                end
                else begin
                    nextState <= SIX_ONES_DETECTED;
                    halt = 1'b1;
                    bit_out <= 1'b0;
                end
            end
            SIX_ONES_DETECTED: begin
                bit_out <= bit_in;
                halt = 1'b0;
                nextState <= IDLE;
            end
        endcase
    end
endmodule : bitStuffing
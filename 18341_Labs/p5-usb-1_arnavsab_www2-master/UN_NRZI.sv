`default_nettype none
`include "USBPkg.pkg"

// Decodes the NRZI
module UN_NRZI (
    input logic clock, reset_n,
    input bus_state_t busIn,
    output bus_state_t busOut,
    output logic enSeen);

    enum logic [3:0] {RESET_STATE, OUTJ_AFTERJ, OUTK_AFTERK,
                      OUTJ_AFTERK, OUTK_AFTERJ, SEEN_SEO_1, 
                      SEEN_SEO_2, TRANSFER_COMPLETE} currState, nextState;
    
    always_ff @(posedge clock) begin
        if(~reset_n) begin
            currState <= RESET_STATE;
        end
        else begin
            currState <= nextState;
        end
    end

    // FSM (state transition)
    always_comb begin
        case (currState)
            RESET_STATE: begin
                if(busIn == BS_K) begin
                    nextState = OUTK_AFTERK;
                    busOut = BS_K;
                    enSeen = 1;
                end
                else begin
                    nextState = RESET_STATE;
                    enSeen = 0;
                end
            end
            OUTJ_AFTERJ: begin
                if (busIn == BS_J) begin
                    nextState = OUTJ_AFTERJ;
                    busOut = BS_J;
                end
                else if(busIn == BS_K) begin
                    nextState = OUTK_AFTERK;
                    busOut = BS_K;
                end
                else if(busIn == BS_SE0) begin
                    nextState = SEEN_SEO_1;
                    busOut = BS_SE0;
                end
                enSeen = 1;
            end
            OUTK_AFTERK: begin
                if (busIn == BS_J) begin
                    nextState = OUTK_AFTERJ;
                    busOut = BS_K;
                end
                else if (busIn == BS_K) begin
                    nextState = OUTJ_AFTERK;
                    busOut = BS_J;
                end
                else if(busIn == BS_SE0) begin
                    nextState = SEEN_SEO_1;
                    busOut = BS_SE0;
                end
                enSeen = 1;
            end
            OUTJ_AFTERK: begin
                if (busIn == BS_J) begin
                    nextState = OUTK_AFTERJ;
                    busOut = BS_K;
                end
                else if (busIn == BS_K) begin
                    nextState = OUTJ_AFTERK;
                    busOut = BS_J;
                end
                else if(busIn == BS_SE0) begin
                    nextState = SEEN_SEO_1;
                    busOut = BS_SE0;
                end
                enSeen = 1;
            end
            OUTK_AFTERJ: begin
                if (busIn == BS_K) begin
                    nextState = OUTK_AFTERK;
                    busOut = BS_K;
                end
                else if(busIn == BS_J) begin
                    nextState = OUTJ_AFTERJ;
                    busOut = BS_J;
                end
                else if(busIn == BS_SE0) begin
                    nextState = SEEN_SEO_1;
                    busOut = BS_SE0;
                end
                enSeen = 1;
            end
            SEEN_SEO_1: begin
                nextState = TRANSFER_COMPLETE;
                busOut = BS_SE0;
                enSeen = 1;
            end
            TRANSFER_COMPLETE: begin
                nextState = TRANSFER_COMPLETE;
                busOut = BS_J;
                enSeen = 1;
            end
        endcase
    end
endmodule: UN_NRZI
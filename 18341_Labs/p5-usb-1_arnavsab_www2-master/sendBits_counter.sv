`default_nettype none

// counts the number of bits that have been received, accounting for 
// stuffed 0s
module sendBits_counter (
    input logic clock, reset_n,
    input logic enSeen, halt,
    output logic [`COUNT_BITS - 1 : 0] count);

    always_ff @(posedge clock) begin
        if (~reset_n) begin
            count <= 0;
        end
        else if (enSeen && (~halt)) begin
            count <= count + 1;
        end
        else begin
          count <= count;
        end
    end
  endmodule: sendBits_counter

/*
  generates the phase of the receiver, depending on how much of the 
  incoming packet has been processed
*/
module phaseGen
  (
    input logic [`COUNT_BITS - 1 : 0] count,
    /*
      hook up pid to MUX'd shifter input and the register in which PID
      is latched. When count == PID_BITS, the combinational pid is used and
      in subsequent cycles, the latched PID is used
    */
    input logic [`PID_BITS - 1 : 0] pid,
    input logic clock, reset_n, halt,
    output phase_t currPhase
  );

  phase_t nextPhase;

  always_comb begin
    case (count) inside 
      [0 : `SYNC_BITS - 1] : nextPhase = SYNC_P;

      [`SYNC_BITS : `SYNC_BITS + (`PID_BITS << 1) - 1]: nextPhase = PID_P;

      (`SYNC_BITS + (`PID_BITS << 1)) : begin
        if (pid == PID_DATA0) begin
          nextPhase = PAYLOAD_P;
        end
        else begin
          nextPhase = EOP_P;
        end
      end

      [`SYNC_BITS + (`PID_BITS << 1) + 1 : `SYNC_BITS + (`PID_BITS << 1) + 2] : 
      begin
        if (pid == PID_DATA0) begin
          nextPhase = PAYLOAD_P;
        end
        else begin
          nextPhase = EOP_P;
        end
      end

      // from here on, I suppose we can just assume the pid is DATA0

      [`SYNC_BITS + (`PID_BITS << 1) + 3 : `SYNC_BITS + (`PID_BITS << 1) + 
      `PAYLOAD_BITS 
      - 1] : nextPhase = PAYLOAD_P;

      [`SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS : 
      `SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS + `CRC16_BITS
      - 1] : begin
        nextPhase = ((count == `SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS)
        && halt) ? PAYLOAD_P : CRC_P;
      end

      [`SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS + `CRC16_BITS : 
      `SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS + `CRC16_BITS + `EOP_BITS
      - 1] : begin
        nextPhase = ((count == `SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS + 
        `CRC16_BITS)
        && halt) ? CRC_P : EOP_P;
      end

      default : nextPhase = SYNC_P;
    endcase
  end

  always_ff @(posedge clock) begin
    if (~reset_n) begin
      currPhase <= SYNC_P;
    end
    else begin
      currPhase <= nextPhase;
    end
  end

endmodule: phaseGen
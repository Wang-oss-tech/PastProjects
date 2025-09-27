`default_nettype none

/*
  keeps track of total number of bits sent for the packet sender
*/
module pktTracker
  (
    input logic halt, clock, reset_n,
    output logic [`COUNT_BITS - 1 : 0] count
  );
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      count <= 0;
    end
    else if (halt) begin
      count <= count;
    end
    else begin
      count <= count + 1;
    end
  end
endmodule: pktTracker

/*
  calculates the phase of the sender
*/
module phaseTracker
  (
    input logic [`COUNT_BITS - 1 : 0] count,
    input logic clock, reset_n, halt,
    input pid_t pktType,
    input logic [2 : 0] ones_count, 
    input logic bitOutFeeder,
    output phase_t currPhase
  );
  // common limits for all protocols
  parameter SYNC_LIMIT = 8;
  localparam PID_LIMIT = SYNC_LIMIT + 8;

  // out/in specific
  localparam ADDR_LIMIT = PID_LIMIT + 7;
  localparam ENDP_LIMIT = ADDR_LIMIT + 4;
  localparam CRC5_LIMIT = ENDP_LIMIT + 5;
  localparam OUT_IN_EOP = CRC5_LIMIT + 3;

  // data0 specific
  localparam PAYLOAD_LIMIT = PID_LIMIT + 64;
  localparam CRC16_LIMIT = PAYLOAD_LIMIT + 16;
  localparam DATA0_EOP = CRC16_LIMIT + 3;

  phase_t nextPhase;

  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      currPhase <= SYNC_P;
    end
    else begin
      currPhase <= nextPhase;
    end
  end

  /*
    2 boundary conditions for A -> B transition
    if halt seen at boundary, stay in state A
    if halt is going to be seen at first cycle of state B, remain in state A
  */
  always_comb begin
    case (pktType) inside
      PID_DATA0 : begin
        case (count) inside
          [0 : SYNC_LIMIT - 2] : nextPhase = SYNC_P;
          [SYNC_LIMIT - 1 : PID_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == SYNC_LIMIT - 1)) ? 
          SYNC_P : PID_P;
          [PID_LIMIT - 1 : PAYLOAD_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == PID_LIMIT - 1)) ? 
          PID_P : PAYLOAD_P;
          [PAYLOAD_LIMIT - 1 : CRC16_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == PAYLOAD_LIMIT - 1)) 
          ? PAYLOAD_P : CRC_P;
          [CRC16_LIMIT - 1 : DATA0_EOP - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == CRC16_LIMIT - 1)) ? 
          CRC_P : EOP_P;
          default : nextPhase = EOP_P;
        endcase
      end

      PID_OUT, PID_IN : begin
        case (count) inside
          [0 : SYNC_LIMIT - 2] : nextPhase = SYNC_P;
          [SYNC_LIMIT - 1 : PID_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == SYNC_LIMIT - 1)) ? 
          SYNC_P : PID_P;
          [PID_LIMIT - 1 : ADDR_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == PID_LIMIT - 1)) ? 
          PID_P : ADDR_P;
          [ADDR_LIMIT - 1 : ENDP_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == ADDR_LIMIT - 1)) ? 
          ADDR_P : ENDP_P;
          [ENDP_LIMIT - 1 : CRC5_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == ENDP_LIMIT - 1)) ? 
          ENDP_P : CRC_P;
          [CRC5_LIMIT - 1 : OUT_IN_EOP - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == CRC5_LIMIT - 1)) ? 
          CRC_P : EOP_P;
          default : nextPhase = EOP_P;
        endcase
      end

      // handshake case
      default : begin
        case (count) inside
          [0 : SYNC_LIMIT - 2] : nextPhase = SYNC_P;
          [SYNC_LIMIT - 1 : PID_LIMIT - 2] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == SYNC_LIMIT - 1)) ? 
          SYNC_P : PID_P;
          [PID_LIMIT - 1: PID_LIMIT + 1] : nextPhase = ((halt || 
          ((ones_count == 5) && bitOutFeeder)) && (count == PID_LIMIT - 1)) ? 
          PID_P : EOP_P;
          default : nextPhase = SYNC_P;
        endcase
      end
    endcase
  end

endmodule: phaseTracker



`default_nettype none

// ONLY FOR CUSTOM TESTBENCH
// Wrapper for USB bus states. Notice that enum Z can only be driven, not read
// typedef enum logic [1:0]
//   {BS_J = 2'b10, BS_K = 2'b01, BS_SE0 = 2'b00, BS_SE1 = 2'b11, BS_NC = 2'bzz}
//   bus_state_t;

// typedef enum logic [2 : 0] {
//   SYNC_P, PID_P, ADDR_P, ENDP_P, PAYLOAD_P, CRC_P, EOP_P
// } phase_t;
// END ONLY FOR CUSTOM TESTBENCH

// Reverses bit order of a byte input
function logic [7 : 0] revByte 
  (
    input logic [7 : 0] inByte
  );

  return {inByte[0], inByte[1], inByte[2], inByte[3], inByte[4], inByte[5], 
  inByte[6], inByte[7]};
endfunction: revByte


function logic [63 : 0] revSixtyFour
  (
    input logic [63 : 0] inByte
  );

  return {inByte[0], inByte[1], inByte[2], inByte[3], inByte[4], inByte[5], 
  inByte[6], inByte[7], 
  inByte[8], inByte[9], inByte[10], inByte[11], inByte[12], inByte[13], 
  inByte[14], inByte[15],
  inByte[16], inByte[17], inByte[18], inByte[19], inByte[20], inByte[21], 
  inByte[22], inByte[23],
  inByte[24], inByte[25], inByte[26], inByte[27], inByte[28], inByte[29], 
  inByte[30], inByte[31],
  inByte[32], inByte[33], inByte[34], inByte[35], inByte[36], inByte[37], 
  inByte[38], inByte[39], 
  inByte[40], inByte[41], inByte[42], inByte[43], inByte[44], inByte[45], 
  inByte[46], inByte[47],
  inByte[48], inByte[49], inByte[50], inByte[51], inByte[52], inByte[53], 
  inByte[54], inByte[55],
  inByte[56], inByte[57], inByte[58], inByte[59], inByte[60], inByte[61], 
  inByte[62], inByte[63]};

endfunction: revSixtyFour

// Reverses bit order of a 7-bit input.
function logic [6 : 0] revSeven 
  (
    input logic [6 : 0] inSeven
  );

  return {inSeven[0], inSeven[1], inSeven[2], inSeven[3], inSeven[4], 
  inSeven[5], inSeven[6]};

endfunction: revSeven

// Reverses bit order of a 7-bit input.
function logic [3 : 0] revFour 
  (
    input logic [3 : 0] inFour
  );

  return {inFour[0], inFour[1], inFour[2], inFour[3]};

endfunction: revFour

// Add negated PID to output
function logic [7 : 0] errorPID
  (
    input logic [3 : 0] PID
  );

  return {PID[0], PID[1], PID[2], PID[3], ~PID[0], ~PID[1], ~PID[2], ~PID[3]};

endfunction

// Module to send an End-of-Packet (EOP) signal
module sendEOP
  (
    input logic clock, reset_n, 
    input logic start,
    output bus_state_t eopPacket
  );

  // Definining states
  enum logic [1 : 0] {
    IDLE, SENT_ONE, SENT_TWO
  } currState, nextState;

  // Combinatorial block to determine the next state based on current state and 
  // inputs
  always_comb begin
    case (currState)
      IDLE: nextState = start ? SENT_ONE : IDLE;
      SENT_ONE: nextState = SENT_TWO;
      SENT_TWO: nextState = IDLE;
    endcase
  end

  // Combinatorial block to set the output packet based on the current state
  always_comb begin
    case (currState)
      IDLE: eopPacket = BS_SE0;
      SENT_ONE: eopPacket = BS_SE0;
      SENT_TWO: eopPacket = BS_J;
    endcase
  end

  // Sequential block to update the current state on each clock edge or reset
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      currState <= IDLE;
    end
    else begin
      currState <= nextState;
    end
  end

endmodule: sendEOP

// Transform output from 1,0 to J,K's on bus
function bus_state_t transformed 
  (
    input logic bitOut
  );
  assign transformed = bitOut ? BS_J : BS_K;
  return transformed;
endfunction: transformed

module sendPacketHelper 
  (
    input logic [`MAX_PKT_SIZE_NO_EOP - 1 : 0] init,
    input logic clock, reset_n, 
    input pid_t pktType, 
    input logic stopSending,
    output logic done,
    output bus_state_t busOut
  );

  // PARAMETERS FOR KNOWING WHEN SEND PACKET HAS ELAPSED
  parameter OUT_IN_BITS = `SYNC_BITS + `ADDR_BITS + (`PID_BITS << 1) +
  `CRC5_BITS + `ENDP_BITS + `EOP_BITS - 1;

  parameter DATA0_BITS = `SYNC_BITS + (`PID_BITS << 1) + `CRC16_BITS + 
  `PAYLOAD_BITS + `EOP_BITS - 1;

  parameter ACK_NACK_BITS = `SYNC_BITS + (`PID_BITS << 1) + `EOP_BITS - 1;

  // tracking expected number of bits
  logic [`COUNT_BITS - 1 : 0] expBitAmount;
  
  always_comb begin
    case (pktType) inside
      PID_DATA0 : expBitAmount = DATA0_BITS;
      PID_OUT, PID_IN : expBitAmount = OUT_IN_BITS;
      PID_ACK, PID_NAK : expBitAmount = ACK_NACK_BITS;
    endcase
  end


  // Internal Signals for data handling & flow control
  logic bitOutFeeder, bitOutBitStuffer;
  phase_t currPhase;
  logic [`COUNT_BITS - 1 : 0] count;
  logic halt;
  logic nrzi;
  logic [`CRC16_BITS - 1 : 0] crc;

  // wires for debugging
  logic feederWire;

  assign feederWire = feederArray.shifterBitOut;

  // Packets for different transmission phases
  bus_state_t eopPacket;
  bus_state_t threadPacket;
  bus_state_t finalPacket;

  logic crcDataReady;

  logic [2 : 0] ones_count;

  // Instantiated modules for managing transmission phases
  phaseTracker phase_tracker(.count(count), .clock(clock), .reset_n(reset_n), 
  .pktType(pktType), .currPhase(currPhase), .halt(halt), .ones_count(ones_count),
  .bitOutFeeder(bitOutFeeder));

  pktTracker phaseCounter (.halt(halt), .clock(clock), .reset_n(reset_n), 
  .count(count));

  feeder feederArray (.init(init), .count(count), .crc(crc),
  .clock(clock), .halt(halt), .crcDataReady(crcDataReady),
  .currPhase(currPhase), .bitOut(bitOutFeeder));

  crcGen crcGen(.bitIn(bitOutFeeder), .clock(clock), .reset_n(reset_n), 
  .currPhase(currPhase), .crc(crc), .halt(halt), .crcDataReady(crcDataReady),
  .pktType(pktType));

  bitStuffing bitStuff(.bit_in(bitOutFeeder), .clock(clock), .reset_n(reset_n), 
  .CURRENT_PHASE(currPhase), .bit_out(bitOutBitStuffer), .halt(halt), 
  .ones_count(ones_count));

  NRZI nrzi_encoding(.clock(clock), .reset_n(reset_n), 
  .bit_in(bitOutBitStuffer), .nrzi_out(nrzi));

  sendEOP eopSender (.clock(clock), .reset_n(reset_n), 
  .start(currPhase == EOP_P), .eopPacket(eopPacket));

  // End-of-Packet sender
  assign threadPacket = transformed(nrzi);

  // Packet selection based on current phase
  assign finalPacket = (currPhase == EOP_P) ? eopPacket : threadPacket;

  // Output control based on stopSending signal
  assign busOut = stopSending ? BS_NC : finalPacket;

  // Indication of transmission completion: expected # of bits [8(sync) + 23 
  // (info) + 6(EOP)]
  assign done = (count == expBitAmount);
endmodule: sendPacketHelper


// Control Path for the sending packet
module sendPktFSM 
  (
    input logic clock, start, done,
    output logic local_reset_n, stopSending
  );

  // State definition for the FSM
  enum logic [1 : 0] {
    IDLE, SENDING, DONE
  } currState, nextState;

  // Combinatorial logic to define state transitions and outputs
  always_comb begin
    case (currState)
      IDLE: begin
        local_reset_n = 0;
        nextState = SENDING;
        stopSending = 1;
      end

      SENDING: begin
        nextState = done ? DONE : SENDING;
        local_reset_n = 1;
        stopSending = 0;
      end

      DONE: begin
        nextState = DONE;
        local_reset_n = 0;
        stopSending = 1;
      end

      default: begin
        stopSending = 1;
        nextState = DONE;
        local_reset_n = 0;
      end
    endcase
  end

  // Sequential logic for state transition on clock edge or start signal edge
  always_ff @(posedge clock, posedge start) begin
    if (start) begin
      currState <= IDLE;
    end
    else begin
      currState <= nextState;
    end
  end

endmodule: sendPktFSM

// Top module for sending packet and control paht of sending packet
module sendPacket
  (
    input pid_t pktType,
    input logic [(`PAYLOAD_BITS) - 1 : 0] payload,
    input logic start, clock,
    input logic isAddr,
    output logic done,
    output bus_state_t busOut
  );

  // initial value to give to feeder
  logic [(`MAX_PKT_SIZE_NO_EOP) - 1 : 0] init;

  // done signal from send packet helper
  logic inDone;
  assign done = inDone;

  // tri-stating signal
  logic stopSending;

  // local reset
  logic local_reset_n;

  // endp
  logic [`ENDP_BITS - 1 : 0] endp;
  assign endp = isAddr ? `ADDR_ENDP : `DATA_ENDP;

  // instantiate full module here
  sendPacketHelper helper (.init(init), .clock(clock), .done(inDone), 
  .busOut(busOut), .reset_n(local_reset_n), .pktType(pktType), 
  .stopSending(stopSending));

  sendPktFSM helperController (.clock(clock), .start(start),
  .local_reset_n(local_reset_n), .done(inDone), .stopSending(stopSending));

  // initial packet for other cases defaulted to 0 for now
  always_comb begin
    case (pktType) inside
      PID_OUT, PID_IN : begin
        init = ((`SYNC) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS)) + 
        (errorPID(pktType) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS - 
        (`PID_BITS << 1))) +
        ((revSeven(`DEVICE_ADDR)) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS - 
        (`PID_BITS << 1) - `ADDR_BITS)) + 
        (revFour(endp) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS - 
        (`PID_BITS << 1) - `ADDR_BITS - `ENDP_BITS));
      end

      PID_DATA0: begin
        init = ((`SYNC) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS)) + 
        (errorPID(pktType) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS - 
        (`PID_BITS << 1))) +
        (revSixtyFour(payload) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS -
        (`PID_BITS << 1) - `PAYLOAD_BITS)); 
      end

      PID_ACK, PID_NAK: begin
        init = ((`SYNC) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS)) + 
        (errorPID(pktType) << (`MAX_PKT_SIZE_NO_EOP - `SYNC_BITS - 
        (`PID_BITS << 1)));
      end

      default : init = 'b0;
    endcase
  end

endmodule: sendPacket
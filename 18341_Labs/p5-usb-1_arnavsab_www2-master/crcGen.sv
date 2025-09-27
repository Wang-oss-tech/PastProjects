`default_nettype none


// 5-bit (CRC) generator using a series of D flip-flops
module crcGenFive
  (
    input logic bitIn, clock, preset_L, halt,
    output logic [`CRC5_BITS - 1 : 0] crcOut
  );

  DFlipFlop zero (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[4] ^ bitIn), .Q(crcOut[0]));

  DFlipFlop one (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[0]), .Q(crcOut[1]));

  DFlipFlop two (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[1] ^ (crcOut[4] ^ bitIn)), .Q(crcOut[2]));

  DFlipFlop three (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[2]), .Q(crcOut[3]));

  DFlipFlop four (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[3]), .Q(crcOut[4]));

endmodule: crcGenFive


module crcGenSixteen
  (
    input logic bitIn, clock, preset_L, halt,
    output logic [`CRC16_BITS - 1 : 0] crcOut
  );

  DFlipFlop zero (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[15] ^ bitIn), .Q(crcOut[0]));

  DFlipFlop one (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[0]), .Q(crcOut[1]));

  DFlipFlop two (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[1] ^ (crcOut[15] ^ bitIn)), .Q(crcOut[2]));

  DFlipFlop three (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[2]), .Q(crcOut[3]));
  DFlipFlop four (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[3]), .Q(crcOut[4]));
  DFlipFlop five (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[4]), .Q(crcOut[5]));
  DFlipFlop six (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[5]), .Q(crcOut[6]));
  DFlipFlop seven (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[6]), .Q(crcOut[7]));
  DFlipFlop eight (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[7]), .Q(crcOut[8]));
  DFlipFlop nine (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[8]), .Q(crcOut[9]));
  DFlipFlop ten (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[9]), .Q(crcOut[10]));
  DFlipFlop eleven (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[10]), .Q(crcOut[11]));
  DFlipFlop twelve (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[11]), .Q(crcOut[12]));
  DFlipFlop thirteen (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[12]), .Q(crcOut[13]));
  DFlipFlop fourteen (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[13]), .Q(crcOut[14]));

  DFlipFlop fifteen (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(~halt), .D(crcOut[14] ^ (crcOut[15] ^ bitIn)), .Q(crcOut[15]));

endmodule: crcGenSixteen

/*
  expects top level phase type declaration for phase_t
*/

module crcGen
  (
    input logic bitIn, clock, reset_n, halt,
    input phase_t currPhase,
    input pid_t pktType,
    output logic [`CRC16_BITS - 1 : 0] crc,
    output logic crcDataReady
  );

  enum logic {
    NOT_READY,
    READY
  } currState, nextState;


  // Determine if current phase is in info to know whether 
  // we need to crc
  logic isInfoPhase;
  assign isInfoPhase = (currPhase == PAYLOAD_P) || (currPhase == ADDR_P) || 
  (currPhase == PID_P) || (currPhase == ENDP_P);

  logic [`CRC5_BITS - 1 : 0] crcOutFive; // Output from the 5-bit CRC generator

  // output from 16 bit crc generator
  logic [`CRC16_BITS - 1 : 0] crcOutSixteen;

  logic preset_L;       // Preset signal for the 5-bit CRC generator
  crcGenFive fiveCrc (.bitIn(bitIn), .clock(clock), .preset_L(preset_L), 
  .crcOut(crcOutFive), .halt(halt));

  crcGenSixteen sixteenCrc (.bitIn(bitIn), .clock(clock), .preset_L(preset_L), 
  .crcOut(crcOutSixteen), .halt(halt));

  always_comb begin
    case (pktType) inside
      PID_OUT, PID_IN : crc = {~crcOutFive[4], ~crcOutFive[3], ~crcOutFive[2], 
      ~crcOutFive[1], ~crcOutFive[0], 11'b0};

      PID_DATA0 : crc = ~crcOutSixteen;

      default: crc = 'b0;
    endcase
  end


  // Combinatorial logic for state transitions and output control
  always_comb begin
    case (currState)
      NOT_READY: begin
        if (isInfoPhase && (currPhase != PID_P)) begin
          nextState = READY;
          preset_L = 1;
          crcDataReady = 0;
        end
        else begin
          nextState = NOT_READY;
          preset_L = 0;
          crcDataReady = 0;
        end
      end

      READY: begin
        if (currPhase == CRC_P) begin
          crcDataReady = 1;
          preset_L = 1;
          nextState = NOT_READY;
        end
        else begin
          crcDataReady = 0;
          preset_L = 1;
          nextState = READY;
        end
      end
    endcase
  end

  // Sequential logic for state updating based on the clock and reset signal
  always_ff @(posedge clock, negedge reset_n) begin
    if (~reset_n) begin
      currState <= NOT_READY;
    end
    else begin
      currState <= nextState;
    end
  end

endmodule: crcGen
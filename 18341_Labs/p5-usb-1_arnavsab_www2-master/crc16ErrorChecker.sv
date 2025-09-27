`default_nettype none

/*
  FSM to control enable behaviour of the flip flops in the crc error checker
*/
module ffEnFSM 
  (
    input logic enSeen, halt, 
    input logic clock, reset_n,
    input logic [`COUNT_BITS - 1 : 0] count,
    input logic [`PID_BITS - 1 : 0] pid,
    output logic en
  );

  enum logic {
    NOEN, EN
  } currState, nextState;

  always_comb begin
    case (currState)
      // don't change the FFs in the wrong phase or during halt
      NOEN: begin
        if ((count == `SYNC_BITS + (`PID_BITS << 1)) && (pid == PID_DATA0) 
        && enSeen
        && (~halt)) begin
          nextState = EN;
        end
        else begin
          nextState = NOEN;
        end
        en = 0;
      end

      EN: begin
        if (enSeen && (~halt)) begin
          nextState = EN;
          en = 1;
        end
        else begin
          nextState = EN;
          en = 0;
        end
      end

      default: nextState = NOEN;
    endcase
  end

  always_ff @(posedge clock) begin
    if (~reset_n) begin
      currState <= NOEN;
    end
    else begin
      currState <= nextState;
    end
  end
endmodule: ffEnFSM

/*
  FSM to control done signal from crc error checker
*/
module ffDoneFSM
  (
    input logic clock, reset_n, 
    input phase_t currPhase,
    output logic done
  );

  enum logic {
    NOT_DONE, DONE
  } currState, nextState;

  always_comb begin
    case (currState)
      NOT_DONE: begin
        if (currPhase != EOP_P) begin
          nextState = NOT_DONE;
          done = 0;
        end
        else begin
          nextState = DONE;
          done = 1;
        end
      end

      DONE: begin
        nextState = DONE;
        done = 0;
      end
    endcase
  end

  always_ff @(posedge clock) begin
    if (~reset_n) begin
      currState <= NOT_DONE;
    end
    else begin
      currState <= nextState;
    end
  end

endmodule: ffDoneFSM

/*
  checks for CRC errors in the receiver module
  
  enSeen: indicates non-idle state of bus
  halt: a stuffed 0 is on the line
  currPhase: the phase of the received packet we are in
  done: when the crc checking is done, asserted for one clock cycle
  ok: 0 if crc detected an error
*/
module crc16ErrorChecker
  (
    input logic enSeen, halt, reset_n, clock, 
    input logic bitIn,
    input phase_t currPhase,
    input logic [`COUNT_BITS - 1 : 0] count,
    input logic [`PID_BITS - 1 : 0] pid,
    output logic done, ok
  );

  logic preset_L;
  logic en;
  assign preset_L = reset_n;

  ffEnFSM enFSM (.enSeen(enSeen), .halt(halt), .count(count), .en(en),
  .clock(clock), .reset_n(reset_n), .pid(pid));

  ffDoneFSM doneFSM (.currPhase(currPhase), .clock(clock), .reset_n(reset_n), 
  .done(done));

  logic [`CRC16_BITS - 1 : 0] crcOut;

  assign ok = (crcOut == `CRC16_RESIDUE);

  DFlipFlop zero (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[15] ^ bitIn), .Q(crcOut[0]));

  DFlipFlop one (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[0]), .Q(crcOut[1]));

  DFlipFlop two (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[1] ^ (crcOut[15] ^ bitIn)), .Q(crcOut[2]));

  DFlipFlop three (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[2]), .Q(crcOut[3]));
  DFlipFlop four (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[3]), .Q(crcOut[4]));
  DFlipFlop five (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[4]), .Q(crcOut[5]));
  DFlipFlop six (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[5]), .Q(crcOut[6]));
  DFlipFlop seven (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[6]), .Q(crcOut[7]));
  DFlipFlop eight (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[7]), .Q(crcOut[8]));
  DFlipFlop nine (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[8]), .Q(crcOut[9]));
  DFlipFlop ten (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[9]), .Q(crcOut[10]));
  DFlipFlop eleven (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[10]), .Q(crcOut[11]));
  DFlipFlop twelve (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[11]), .Q(crcOut[12]));
  DFlipFlop thirteen (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[12]), .Q(crcOut[13]));
  DFlipFlop fourteen (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[13]), .Q(crcOut[14]));

  DFlipFlop fifteen (.preset_L(preset_L), .reset_L(1'b1), .clock(clock), 
  .en(en), .D(crcOut[14] ^ (crcOut[15] ^ bitIn)), .Q(crcOut[15]));

endmodule: crc16ErrorChecker
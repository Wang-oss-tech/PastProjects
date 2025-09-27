`default_nettype none

// continuous bit shifter that outputs the most significant bit 
module continuousShifter
  (
    input logic [`CRC16_BITS - 1 : 0] val,
    input logic clock, halt, crcDataReady,
    input phase_t currPhase,
    output logic shifterBitOut
  );

  logic [`COUNT_BITS - 1 : 0] offset;

  logic [`CRC16_BITS - 1 : 0] inReg;

  // Output the MSB of the internal register
  assign shifterBitOut = inReg[`CRC16_BITS - offset - 1];

  always_ff @(posedge clock) begin
    if (halt) begin
      offset <= offset;
    end
    else if (currPhase != CRC_P) begin
      offset <= 0;
    end
    else begin
      offset <= offset + 1;
    end
  end

  always_ff @(posedge clock, posedge crcDataReady) begin
    if (crcDataReady) begin
      inReg <= val;
    end
    else begin
      inReg <= inReg;
    end
  end
  
endmodule: continuousShifter


// Outputs bit stream
module feeder
  (
    input logic [`MAX_PKT_SIZE_NO_EOP - 1 : 0] init,
    input logic [`COUNT_BITS - 1 : 0] count,
    input logic [`CRC16_BITS - 1 : 0] crc,
    input logic crcDataReady, clock, halt,
    input phase_t currPhase,
    output logic bitOut
  );

  logic shifterBitOut;

  continuousShifter myShifter (.val(crc), .currPhase(currPhase),
  .clock(clock), .shifterBitOut(shifterBitOut), .halt(halt), 
  .crcDataReady(crcDataReady));

  // changed from init[count] since ordering of data changed
  assign bitOut = (currPhase == CRC_P) ? shifterBitOut : 
  init[`MAX_PKT_SIZE_NO_EOP - count - 1];
endmodule: feeder
`default_nettype none

/*
  main module for packet receiving

  outputs information such as whether there was a pid or payload error, the
  received packet type and the received payload and a signal (finishedReading)
  to indicate when these values are valid to read
*/
module packetReceiver
  (
    input logic clock, reset_n,
    input bus_state_t busIn,
    output logic [`PID_BITS - 1 : 0] pktType,
    output logic pidError, payloadError,
    output logic [`PAYLOAD_BITS - 1 : 0] payload,
    output logic finishedReading
  );

  // counts no. of seen packets, without accounting for stuffed 0s
  logic enSeen;
  logic [`COUNT_BITS - 1 : 0] seen;
  seenCounter seenCount (.clock(clock), .reset_n(reset_n), .enSeen(enSeen),
  .seen(seen));

  // nrzi remover
  bus_state_t busOutNRZIRemoved;
  UN_NRZI nrziRemover (.clock(clock), .reset_n(reset_n), .busIn(busIn), 
  .busOut(busOutNRZIRemoved), .enSeen(enSeen));

  // ones counter for bit unstuffer
  logic halt;
  ones_counter oneCounter (.clock(clock), .reset_n(reset_n), .seen(seen), 
  .halt(halt), .busIn(busOutNRZIRemoved));

  // counts sent bits for phase calculation
  logic [`COUNT_BITS - 1 : 0] count;
  sendBits_counter bitCounter (.clock(clock), .reset_n(reset_n), 
  .enSeen(enSeen), .halt(halt), .count(count));

  phase_t currPhase;
  logic [`PID_BITS - 1 : 0] pid;
  logic [`PID_BITS - 1 : 0] pidForPhase;

  // the phase tracker needs a correct pid seen to correctly branch phases,
  // so the pid input needs to be muxed between a combinationally stored
  // pid at the time pid arrives and its latched value in later cycles
  assign pidForPhase = (count <= `SYNC_BITS + (`PID_BITS << 1)) ? pid : pktType;
  phaseGen phaseGenerator (.clock(clock), .reset_n(reset_n), .halt(halt), 
  .currPhase(currPhase), .count(count), .pid(pidForPhase));

  // shifts received bits out
  logic topBit;
  logic [`PAYLOAD_BITS - 1 : 0] payloadRaw;
  logic [(`PID_BITS << 1) - 1 : 0] extPid;
  receiveShifter shifter (.clock(clock), .reset_n(reset_n), 
  .busIn(busOutNRZIRemoved),
  .enSeen(enSeen), .halt(halt), .topBit(topBit), .pid(pid), 
  .eopSeen(finishedReading), 
  .payload(payloadRaw), .extPid(extPid));

  // crc 16 error checker
  logic done, ok;
  crc16ErrorChecker errorChecker
  (
    .enSeen(enSeen), .halt(halt), .reset_n(reset_n), .clock(clock), 
    .bitIn(topBit),
    .currPhase(currPhase),
    .count(count),
    .pid(pid),
    .done(done), .ok(ok)
  );

  // pid error calculation
  always_ff @(posedge clock) begin
    if (~reset_n) begin
      pktType <= PID_DATA0;
      pidError <= 0;
    end
    else if (count == `SYNC_BITS + (`PID_BITS << 1)) begin
      pktType <= pid;
      pidError <= ~(extPid[7 : 4] == ~(extPid[3 : 0]));
    end
    else begin
      pktType <= pktType;
      pidError <= pidError;
    end
  end

  // payload latching
  always_ff @(posedge clock) begin
    if (~reset_n) begin
      payload <= 0;
    end
    else if (count == `SYNC_BITS + (`PID_BITS << 1) + `PAYLOAD_BITS) begin
      payload <= payloadRaw;
    end
    else begin
      payload <= payload;
    end
  end

  // payload error based on input from crc 16 checker
  always_ff @(posedge clock) begin
    if (~reset_n) begin
      payloadError <= 0;
    end
    else if (done) begin
      payloadError <= ~ok;
    end
    else begin
      payloadError <= payloadError;
    end
  end

endmodule: packetReceiver
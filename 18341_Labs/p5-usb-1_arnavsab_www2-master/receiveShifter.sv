`default_nettype none

function logic doMap 
  (
    input bus_state_t busIn
  );
  doMap = (busIn == BS_J) ? 1 : 0;
  return doMap;
endfunction

/*
  generates extended outputs based on a collection of received bits to 
  extract pid, payload, crc, etc.

  topBit: the current top (latest) bit in the shift register, used by crc
  pid, payload: may be invalid, valid when finishedReading
  eopSeen: when the 3 bits of eop are on the shifter
*/
module receiveShifter
  (
    input logic clock, reset_n,
    input bus_state_t busIn,
    input logic enSeen, halt,
    output logic topBit,
    output logic [`PID_BITS - 1 : 0] pid,
    output logic [(`PID_BITS << 1) - 1 : 0] extPid,
    output logic [`PAYLOAD_BITS - 1 : 0] payload,
    output logic eopSeen
  );
  bus_state_t [`PAYLOAD_BITS - 1 : 0] arr;

  // continuously shift right and replace top bit with 
  // incoming bit unless halt
  always_ff @(posedge clock) begin
    if (~reset_n) begin
      for (int i = 0; i < `PAYLOAD_BITS; i++) begin
        arr[i] <=  BS_K;
      end
    end
    else if (~(enSeen && (~halt))) begin
      arr <= arr;
    end
    else begin
      for (int i = 0; i < `PAYLOAD_BITS - 1; i++) begin
        arr[i] <= arr[i + 1];
      end
      arr[`PAYLOAD_BITS - 1] <= busIn;
    end
  end

  assign topBit = doMap(arr[`PAYLOAD_BITS - 1]);
  assign eopSeen = (arr[`PAYLOAD_BITS - 1 : `PAYLOAD_BITS - 3] == 
  {BS_J, BS_SE0, BS_SE0});

  assign pid = {doMap(arr[`PAYLOAD_BITS - 5]), doMap(arr[`PAYLOAD_BITS - 6]),
  doMap(arr[`PAYLOAD_BITS - 7]), doMap(arr[`PAYLOAD_BITS - 8])};

  assign extPid = {doMap(arr[`PAYLOAD_BITS - 1]), doMap(arr[`PAYLOAD_BITS - 2]),
  doMap(arr[`PAYLOAD_BITS - 3]), doMap(arr[`PAYLOAD_BITS - 4]), pid};

  always_comb begin
    for (int i = 0; i < `PAYLOAD_BITS; i++) begin
      payload[i] = doMap(arr[i]);
    end
  end

endmodule: receiveShifter
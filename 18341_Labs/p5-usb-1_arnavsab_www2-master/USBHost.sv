`include "USBPkg.pkg"

// Wrapper for USB bus states. Notice that enum Z can only be driven, not read

/*
  topmost level read/write FSM
  inputs:
    mempage: the address to write to
    data: the data to write to mempage addr
    pktReceived: the packet received by the receiver

    success,done Out,In: the status points from the out and in 
    transaction FSMs

    start: synchronously starts a read/write cycle
    re: read enable
  
  outputs:
    startOut_n, startIn_n: for starting the IN and OUT transaction FSMs
    txnType: transaction type for transaction FSMs
    success, done: whether the r/w was successful, done
    senderData: data for sending to sender module
    receivedData: data received from in transaction
*/
module readWriteFSM
  (
    input logic clock,
    input logic [15:0] mempage,
    input logic [63 : 0] data,
    input logic [63 : 0] pktReceived,
    input logic successOut, doneOut, successIn, doneIn,
    input logic start,
    input logic re,
    output logic startOut_n, startIn_n,
    output txn_t txnType,
    output logic done,
    output logic isAddr, success,
    output logic [63 : 0] senderData, receivedData
  );

  enum logic [2 : 0] {
    START, START_SENDING, SENDING_OUT1, SENDING_OUT2, SENDING_IN
  } currState, nextState;

  logic en;

  always_comb begin
    case (currState)
      START: begin
        startOut_n = 0;
        startIn_n = 1;
        txnType = OUT_TXN;
        isAddr = 1;
        senderData = mempage << 48;
        done = 0;
        success = 0;
        nextState = START_SENDING;
      end

      START_SENDING: begin
        startOut_n = 1;
        startIn_n = 1;
        isAddr = 1;
        done = 0;
        success = 0;
        nextState = SENDING_OUT1;
      end

      SENDING_OUT1: begin
        if (doneOut && ~successOut) begin
          done = 1;
          success = 0;
          isAddr = 1;
          startOut_n = 1;
          startIn_n = 1;
          nextState = SENDING_OUT1;
        end
        else if (doneOut && successOut && re) begin
          startIn_n = 0;
          startOut_n = 1;
          txnType = IN_TXN;
          senderData = data;
          isAddr = 0;
          success = 0;
          done = 0;
          nextState = SENDING_IN;
        end
        else if (doneOut && successOut && ~re) begin
          startIn_n = 1;
          startOut_n = 0;
          txnType = OUT_TXN;
          senderData = data;
          isAddr = 0;
          success = 0;
          done = 0;
          nextState = SENDING_OUT2;
        end
        else begin
          startIn_n = 1;
          startOut_n = 1;
          isAddr = 1;
          success = 0;
          done = 0;
          nextState = SENDING_OUT1;
        end
      end
    
      
      SENDING_IN: begin
        if(doneIn && successIn) begin
          // success operation
          done = 1;
          success = 1;
          startIn_n = 1;
          startOut_n = 1;
          receivedData = pktReceived;
          isAddr = 0;
          nextState = SENDING_IN;
        end
        else if(doneIn && ~successIn) begin
          // failed operation
          done = 1;
          success = 0;
          isAddr = 0;
          startIn_n = 1;
          startOut_n = 1;
          nextState = SENDING_IN;
        end else begin
          // still sending IN packet
          startIn_n = 1;
          startOut_n = 1;
          done = 0;
          success = 0;
          isAddr = 0;
          nextState = SENDING_IN;
        end
      end

      SENDING_OUT2: begin
        if(doneOut && successOut) begin
          // success operation
          done = 1;
          success = 1;
          startOut_n = 1;
          startIn_n = 1;
          isAddr = 0;
          nextState = SENDING_OUT2;
        end
        else if (doneOut && ~successOut) begin
          // failed operation
          done = 1;
          success = 0;
          startOut_n = 1;
          startIn_n = 1;
          isAddr = 0;
          nextState = SENDING_OUT2;
        end else begin
          // still sending OUT packet
          startOut_n = 1;
          done = 0;
          success = 0;
          isAddr = 0;
          startIn_n = 1;
          nextState = SENDING_OUT2;
        end
      end
    endcase  
  end

  always_ff @(posedge clock) begin
    if (start) begin
      currState <= START;
    end
    else begin
      currState <= nextState;
    end
  end

endmodule: readWriteFSM


module USBHost (
  USBWires wires,
  input logic clock, reset_n
);

logic [`PAYLOAD_BITS - 1 : 0] senderData;
logic startOut_n, startIn_n;
txn_t txnType;
bus_state_t busIn;
logic successOut, doneOut;
logic successIn, doneIn;
logic [`PAYLOAD_BITS - 1 : 0] pktReceived, receivedData;
bus_state_t busOut;
logic isAddr;

logic [15 : 0] fsmMempage;
logic [63 : 0] fsmData;
logic fsmDone;
logic fsmStart;
logic re;
logic fsmSuccess;

// make connections between the read-write FSM and the USB controller

readWriteFSM rwDoer (.clock(clock), .senderData(senderData), 
.startOut_n(startOut_n), .startIn_n(startIn_n), .txnType(txnType), 
.successOut(successOut), .successIn(successIn), .doneOut(doneOut), 
.doneIn(doneIn), .pktReceived(pktReceived), .isAddr(isAddr), .re(re), 
.mempage(fsmMempage), .data(fsmData), .done(fsmDone), .success(fsmSuccess), 
.receivedData(receivedData), .start(fsmStart));

usbController mainUSB (.*, .data(senderData));

assign wires.DP = busOut[1];
assign wires.DM = busOut[0];

assign busIn = {wires.DP, wires.DM};

task prelabRequest();
  // pktType <= PID_OUT;
  // payload <= 'b0;
  // start <= 1;
  // @(posedge clock);
  // start <= 0;
  // wait(done);
  // @(posedge clock);
endtask : prelabRequest

task readData
// Host sends mempage to thumb drive using a READ (OUT->DATA0->IN->DATA0)
// transaction, and then receives data from it. This task should return both the
// data and the transaction status, successful or unsuccessful, to the caller.
( input logic [15:0] mempage, // Page to write
  output logic [63:0] data, // Vector of bytes to write
  output logic success);

  // set mempage, start, re
  fsmMempage <= mempage;
  re <= 1; // read
  fsmStart <= 1;

  @(posedge clock);
  fsmStart <= 0; // need to deassert fsmStart
  wait(fsmDone); // wait for finish

  success <= fsmSuccess;
  data <= receivedData;
  for (int i = 0; i < 2; i++) begin
    @(posedge clock);
  end
endtask : readData

task writeData
// Host sends mempage to thumb drive using a WRITE (OUT->DATA0->OUT->DATA0)
// transaction, and then sends data to it. This task should return the
// transaction status, successful or unsuccessful, to the caller.
( input logic [15:0] mempage, // Page to write
  input logic [63:0] data, // Vector of bytes to write
  output logic success);

  // set controls
  fsmMempage <= mempage;
  fsmData <= data;
  re <= 0; // write
  fsmStart <= 1;

  @(posedge clock);
  fsmStart <= 0; // deassert start
  
  wait (fsmDone); // wait for done
  success <= fsmSuccess;
  
  for (int i = 0; i < 2; i++) begin
    @(posedge clock);
  end
endtask : writeData

endmodule : USBHost



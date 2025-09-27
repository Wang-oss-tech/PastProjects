`default_nettype none

module controlledSender
  (
    input pid_t pktTypeInTxn, pktTypeOutTxn,
    input logic [(`PAYLOAD_BITS) - 1 : 0] payloadInTxn, payloadOutTxn,
    input logic startInTxn, startOutTxn, clock,
    input txn_t txnType,
    output logic done,
    output bus_state_t busOut
  );

  pid_t pktType;
  logic [(`PAYLOAD_BITS) - 1 : 0] payload;
  logic start;
  
  always_comb begin
    unique case (txnType)
      IN_TXN: begin
        pktType = pktTypeInTxn;
        payload = payloadInTxn;
        start = startInTxn;
      end

      OUT_TXN: begin
        pktType = pktTypeOutTxn;
        payload = payloadOutTxn;
        start = startOutTxn;
      end
    endcase
  end

  sendPacket packetSender (.pktType(pktType), .payload(payload), .start(start),
  .clock(clock), .done(done), .busOut(busOut));

endmodule: controlledSender

module cycleCounter
  (
    input logic clock, reset_n,
    output logic [8 : 0] cycleCount
  );
  always_ff @(posedge clock) begin
    if (~reset_n) begin
      cycleCount <= 0;
    end
    else begin
      cycleCount <= cycleCount + 1;
    end
  end
endmodule: cycleCounter

module incrCounter
  (
    input logic clock, reset_n, incr,
    output logic [3 : 0] count
  );
  always_ff @(posedge clock) begin
    if (~reset_n) begin
      count <= 0;
    end
    else if (incr) begin
      count <= count + 1;
    end
    else begin
      count <= count;
    end
  end
endmodule: incrCounter

module outTxnFSM
  (
    input logic startOut_n,
    input logic [`PAYLOAD_BITS - 1 : 0] data,
    input logic doneSender,
    input logic clock,
    input logic dataError, pktTypeReceived, pidError, finishedReading,
    input logic [`PAYLOAD_BITS - 1:0] payloadReceived,
    output pid_t pktTypeSender,
    output logic [`PAYLOAD_BITS - 1:0] payloadSender,
    output logic startSender,
    output logic resetReceiver_n,
    output logic success, done
  );

  enum logic [2 : 0] {
    START, SENDING_OUT, SEND_DATA0, SENDING_DATA0, SENT_DATA0, 
    WAIT_DEVICE, TIMEOUT_HANDLE, FINISH_HANDLE
  } currState, nextState;
  
  logic resetCycleCounter_n;
  logic [8 : 0] cycleCount;
  logic timedOut;
  // cycle counter
  cycleCounter cCounter (.clock(clock), .reset_n(resetCycleCounter_n), 
  .cycleCount(cycleCount));
  assign timedOut = (cycleCount >= `TIMEOUT - 1);

  logic incrTimeout;
  logic timeoutLimit;
  logic [3 : 0] timeoutCount;
  incrCounter timeoutCounter (.clock(clock), .reset_n(startOut_n), 
  .incr(incrTimeout), .count(timeoutCount));
  assign timeoutLimit = (timeoutCount >= `TX_RETRIES);

  logic incrNak;
  logic nakLimit;
  logic [3 : 0] nakCount;
  incrCounter nakCounter (.clock(clock), .reset_n(startOut_n), 
  .incr(incrNak), .count(nakCount));
  assign nakLimit = (nakCount >= `TX_RETRIES);

  always_comb begin
    case (currState)
      START: begin
        startSender = 1;
        pktTypeSender = PID_OUT;
        nextState = SENDING_OUT;
      end

      SENDING_OUT: begin
        startSender = 0;
        nextState = (~doneSender) ? SENDING_OUT : SEND_DATA0;
      end

      SEND_DATA0: begin
        pktTypeSender = PID_DATA0;
        startSender = 1;
        payloadSender = data;
        nextState = SENDING_DATA0;
      end

      SENDING_DATA0: begin
        startSender = 0;
        nextState = (~doneSending) ? SENDING_DATA0 : SENT_DATA0;
      end
      
      SENT_DATA0: begin
        resetCycleCounter_n = 0;
        resetReceiver_n = 0;
        nextState = WAIT_DEVICE;
      end

      WAIT_DEVICE: begin
        if (finishedReading && (pktTypeReceived == PID_ACK)) begin
          success = 1;
          done = 1;
          nextState = WAIT_DEVICE;
        end
        else if (finishedReading && (pktTypeReceived == PID_NAK)) begin
          incrNak = 1;
          nextState = FINISH_HANDLE;
        end
        else if (timedOut) begin
          incrTimeout = 1;
          nextState = TIMEOUT_HANDLE;
        end
        else begin
          nextState = WAIT_DEVICE;
        end
        resetReceiver_n = 1;
        resetCycleCounter_n = 1;
      end
      
      TIMEOUT_HANDLE: begin
        if (timeoutLimit) begin
          success = 0;
          done = 1;
          nextState = TIMEOUT_HANDLE;
        end
        else begin
          incrTimeout = 0;
          pktTypeSender = PID_DATA0;
          startSender = 1;
          payloadSender = data;
          nextState = SENDING_DATA0;
        end
      end

      FINISH_HANDLE: begin
        if (nakLimit) begin
          success = 0;
          done = 1;
          nextState = FINISH_HANDLE;
        end
        else begin
          incrTimeout = 0;
          pktTypeSender = PID_DATA0;
          startSender = 1;
          payloadSender = data;
          nextState = SENDING_DATA0;
        end
      end
    endcase
  end

  always_ff @(posedge clock) begin
    if (~startOut_n) begin
      currState <= START;
    end
    else begin
      currState <= nextState;
    end
  end

endmodule: outTxnFSM


module inTxnFSM
  (input logic startIn_n,
   input logic doneSender,
   input logic clock,
   input logic dataError, pktTypeReceived, pidError, finishedReading,
   input logic [`PAYLOAD_BITS - 1:0] payloadReceived,
   output logic success, done,
   output logic [`PAYLOAD_BITS -1:0] pktReceived,
   output pid_t pktTypeSender,
   output logic [`PAYLOAD_BITS - 1:0] payloadSender,
   output logic start_sender,
   output logic resetReceiver_n);

  // Define Counter Components
  logic resetCycleCounter_n;
  logic [8 : 0] cycleCount;
  logic timedOut;
  // cycle counter
  cycleCounter cCounter (.clock(clock), .reset_n(resetCycleCounter_n), 
  .cycleCount(cycleCount));
  assign timedOut = (cycleCount >= `TIMEOUT - 1);

  logic incrTimeout;
  logic timeoutLimit;
  logic [3 : 0] timeoutCount;
  incrCounter timeoutCounter (.clock(clock), .reset_n(startIn_n), 
  .incr(incrTimeout), .count(timeoutCount));
  assign timeoutLimit = (timeoutCount >= `TX_RETRIES);

  logic incrNak;
  logic nakLimit;
  logic [3 : 0] nakCount;
  incrCounter nakCounter (.clock(clock), .reset_n(startIn_n), 
  .incr(incrNak), .count(nakCount));
  assign nakLimit = (nakCount >= `TX_RETRIES);

  always_ff @(posedge clock) begin
    if (~startIn_n) begin
      currState <= START;
    end
    else begin
      currState <= nextState;
    end
  end

  // State definition
  enum logic [2:0]{
    START, SENDING_IN, WAIT, TIMEOUT_HANDLER, NAK_HANDLER,
    SEND_ACK, SENDING_ACK} currState, nextState;

  always_comb begin
    case(currState)
      START: begin
        start_sender = 1'b1;
        pktTypeSender = PID_IN;
        nextState = SENDING_IN;
      end
      SENDING_IN: begin
        start_sender = 1'b0; // releases the send button
        if (~doneSender) begin
          nextState = SENDING_IN;
        end
        else begin
          // done sending, reset receiver
          resetCycleCounter_n = 1'b0;
          resetReceiver_n = 1'b0;
          nextState = WAIT;
        end
      end   
      WAIT: begin
        // release reset buttons
        resetCycleCounter_n = 1'b1; 
        resetReceiver_n = 1'b1;
        if (~(timeout || finishedReading)) begin
          nextState = WAIT;
        end
        else if (timeout) begin
          nextState = TIMEOUT_HANDLE;
          incrTimeout = 1;
        end
        else if (pidError || dataError) begin
          nextState = NAK_HANDLER;
          incrNak = 1;
        end
        else begin
          // correct data received
          nextState = SEND_ACK;
          pktReceived = payloadReceived;
        end
      end 
      TIMEOUT_HANDLE: begin
        if (timeOutLimit) begin
          success = 0;
          done = 1;
          nextState = TIMEOUT_HANDLE;
        end
        else if begin
          // retry again
          incrTimeout = 0;
          start_sender = 1'b1;
          pktTypeSender = PID_NAK;
          nextState = SENDING_IN;
          // bogus payload
        end
      end
      NAK_HANDLER: begin
        if (nakLimit) begin
          success = 0;
          done = 1;
          nextState = NAK_HANDLER;
        end
        else if begin
          // retry again
          incrNak = 0;
          start_sender = 1'b1;
          pktTypeSender = PID_NAK;
          // bogus payload
          nextState = SENDING_IN;
        end
      end
      SEND_ACK: begin
        start_sender = 1'b1;
        pktTypeSender = PID_ACK;
        payload = 0;
        nextState = SENDING_ACK;
      end
      SENDING_ACK: begin
        start_sender = 1'b0;
        if (~doneSender) begin
          nextState = SENDING_ACK;
        end else begin
          nextState = SENDING_ACK;
          success = 1;
          done = 1;
        end
      end
    endcase
  end
endmodule: inTxnFSM

module usbController
  (
    input logic [`PAYLOAD_BITS - 1:0] data,
    input logic startOut_n, startIn_n,
    input txn_t txnType,
    input logic clock,
    input bus_state_t busIn,
    output logic successOut, doneOut,
    output logic successIn, doneIn,
    output logic [`PAYLOAD_BITS - 1 : 0] pktReceived,
    output bus_state_t busOut
  );

  pid_t pktTypeInTxn, pktTypeOutTxn;
  logic [`PAYLOAD_BITS - 1 : 0] payloadInTxn, payloadOutTxn;
  logic startInTxn, startOutTxn;
  logic doneSender;

  /*
    input logic startIn_n,
    input logic doneSender,
    input logic dataError, pktTypeReceived, pidError, finishedReading,
    input logic [`PAYLOAD_BITS - 1] payloadReceived,
    output logic success, done,
    output logic [`PAYLOAD_BITS -1] pktReceived,
    output pid_t pktTypeSender,
    output logic [`PAYLOAD_BITS - 1] payloadSender,
    output logic start_sender,
    output logic resetReceiver_n
  */

  inTxmFSM inFSM (
    .startIn_n(startIn_n), .doneSender(doneSender), .dataError(payloadError),
    .pktTypeReceived(pktTypeReceived), .pidError(pidError), 
    .finishedReading(finishedReading), .payloadReceived(payloadReceived), 
    .success(successIn), .done(doneIn), .pktReceived(pktReceived), 
    .pktTypeSender(pktTypeInTxn), .payloadSender(payloadInTxn), 
    .start_sender(startInTxn), .resetReceiver_n(resetReceiver_n)
  );

  outTxnFSM outFSM (.startOut_n(startOut_n), .data(data), 
  .doneSender(doneSender), .dataError(payloadError), 
  .pktTypeReceived(pktTypeReceived), .pidError(pidError), 
  .finishedReading(finishedReading), .payloadReceived(payloadReceived), 
  .pktTypeSender(pktTypeOutTxn), .payloadSender(payloadOutTxn), 
  .startSender(startOutTxn), .resetReceiver_n(resetReceiver_n), 
  .success(successOut), .done(doneOut));

  controlledSender packetSend (.pktTypeInTxn(pktTypeInTxn), 
  .pktTypeOutTxn(pktTypeOutTxn), .payloadInTxn(payloadInTxn),
  .payloadOutTxn(payloadOutTxn), .startInTxn(startInTxn), 
  .startOutTxn(startOutTxn), .clock(clock), .done(doneSender), .busOut(busOut)
  .txnType(txnType));

  /*
    input logic clock, reset_n,
    input bus_state_t busIn,
    output logic [`PID_BITS - 1 : 0] pktType,
    output logic pidError, payloadError,
    output logic [`PAYLOAD_BITS - 1 : 0] payload,
    output logic finishedReading
  */

  logic resetReceiver_n;
  logic pidError, payloadError;
  logic [`PID_BITS - 1 : 0] pktTypeReceived;
  logic finishedReading;
  logic [`PAYLOADS_BITS - 1 : 0] payloadReceived;

  packetReceiver packetReceive (.clock(clock), .reset_n(resetReceiver_n), 
  .busIn(busIn), .pktType(pktTypeReceived), .pidError(pidError), 
  .payloadError(payloadError), .payload(payloadReceived), 
  .finishedReading(finishedReading));

endmodule: usbController
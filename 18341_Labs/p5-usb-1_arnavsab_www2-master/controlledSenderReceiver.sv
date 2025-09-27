`default_nettype none

/*
  wrapper module to control access of out and in transaction FSMs to 
  packet sender
*/
module controlledSender
  (
    input pid_t pktTypeInTxn, pktTypeOutTxn,
    input logic [(`PAYLOAD_BITS) - 1 : 0] payloadInTxn, payloadOutTxn,
    input logic startInTxn, startOutTxn, clock,
    input logic isAddr,
    input txn_t txnType,
    output logic done,
    output bus_state_t busOut
  );

  pid_t pktType;
  logic [(`PAYLOAD_BITS) - 1 : 0] payload;
  logic start;

  // choose input based on transaction type 

  always_comb begin
    case (txnType)
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
  .clock(clock), .done(done), .busOut(busOut), .isAddr(isAddr));

endmodule: controlledSender

// reset of receiver module needs to be controlled

module controlledReceiver
  (
    input logic clock, reset_nIn, reset_nOut,
    input bus_state_t busIn,
    input txn_t txnType,
    output logic [`PID_BITS - 1 : 0] pktType,
    output logic pidError, payloadError,
    output logic [`PAYLOAD_BITS - 1 : 0] payload,
    output logic finishedReading
  );

  logic reset_n;
  assign reset_n = (txnType == OUT_TXN) ? reset_nOut : reset_nIn;
  packetReceiver receivePacket (.*);
endmodule: controlledReceiver

/*
  cycle counter for timeout checking
*/
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

/*
  increment-based update counter, used for counting number of NAKs and 
  timeout errors
*/
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

/*
  out transaction FSM
  startOut_n: synchronously starts out transaction
  data: 64 bit payload to send
  doneSender: input from packet sender signalling when done
  dataError, pidError, finishedReading: inputs from receiver
  pktTypeReceived: the packet type received by receiver

  outputs control sender fields and reset receiver
  success: if the transaction was completed without cancellation
  done: transaction completion signal
*/
module outTxnFSM
  (
    input logic startOut_n,
    input logic [`PAYLOAD_BITS - 1 : 0] data,
    input logic doneSender,
    input logic clock,
    input logic dataError, pidError, finishedReading,
    input logic [`PID_BITS - 1 : 0] pktTypeReceived,
    input logic [`PAYLOAD_BITS - 1:0] payloadReceived,
    output pid_t pktTypeSender,
    output logic [`PAYLOAD_BITS - 1:0] payloadSender,
    output logic startSender,
    output logic resetReceiver_n,
    output logic success, done
  );

  enum logic [2 : 0] {
    START, SENDING_OUT, SEND_DATA0, SENDING_DATA0,
    WAIT_DEVICE, TIMEOUT_HANDLE, FINISH_HANDLE
  } currState, nextState;
  
  logic resetCycleCounter_n;
  logic [8 : 0] cycleCount;
  logic timedOut;
  // cycle counter
  cycleCounter cCounter (.clock(clock), .reset_n(resetCycleCounter_n), 
  .cycleCount(cycleCount));
  // if timed out
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
      // start sending pid_out
      START: begin
        startSender = 1;
        pktTypeSender = PID_OUT;
        nextState = SENDING_OUT;
        success = 0;
        done = 0;
        resetReceiver_n = 1;
        incrNak = 0;
        incrTimeout = 0;
        resetCycleCounter_n = 1;
      end

      // keep sending pid out
      SENDING_OUT: begin
        startSender = 0;
        nextState = (~doneSender) ? SENDING_OUT : SEND_DATA0;
        success = 0;
        done = 0;
        resetReceiver_n = 1;
        incrNak = 0;
        incrTimeout = 0;
        resetCycleCounter_n = 1;
      end

      // send data0
      SEND_DATA0: begin
        pktTypeSender = PID_DATA0;
        startSender = 1;
        payloadSender = data;
        nextState = SENDING_DATA0;
        success = 0;
        done = 0;
        resetReceiver_n = 1;
        incrNak = 0;
        incrTimeout = 0;
        resetCycleCounter_n = 1;
      end

      // keep sending data0
      SENDING_DATA0: begin
        startSender = 0;
        // nextState = (~doneSender) ? SENDING_DATA0 : SENT_DATA0;
        if (~doneSender) begin
          nextState = SENDING_DATA0;
          resetCycleCounter_n = 1;
          resetReceiver_n = 1;
        end
        else begin
          nextState = WAIT_DEVICE;
          resetCycleCounter_n = 0;
          resetReceiver_n = 0;
        end
        success = 0;
        done = 0;
        incrNak = 0;
        incrTimeout = 0;
      end

      // wait for response based on receiver verdict
      WAIT_DEVICE: begin
        if (finishedReading && (pktTypeReceived == PID_ACK)) begin
          success = 1;
          done = 1;
          incrNak = 0;
          incrTimeout = 0;
          nextState = WAIT_DEVICE;
        end
        else if (finishedReading && (pktTypeReceived == PID_NAK)) begin
          incrNak = 1;
          success = 0;
          done = 0;
          incrTimeout = 0;
          nextState = FINISH_HANDLE;
        end
        else if (timedOut) begin
          incrTimeout = 1;
          incrNak = 0;
          success = 0;
          done = 0;
          nextState = TIMEOUT_HANDLE;
        end
        else begin
          incrTimeout = 0;
          incrNak = 0;
          success = 0;
          done = 0;
          nextState = WAIT_DEVICE;
        end
        resetReceiver_n = 1;
        resetCycleCounter_n = 1;
        startSender = 0;
      end
      
      TIMEOUT_HANDLE: begin
        if (timeoutLimit) begin
          success = 0;
          done = 1;
          incrTimeout = 0;
          startSender = 0;
          nextState = TIMEOUT_HANDLE;
        end
        else begin
          incrTimeout = 0;
          pktTypeSender = PID_DATA0;
          startSender = 1;
          payloadSender = data;
          success = 0;
          done = 0;
          nextState = SENDING_DATA0;
        end
        resetReceiver_n = 1;
        resetCycleCounter_n = 1;
        incrNak = 0;
      end

      FINISH_HANDLE: begin
        if (nakLimit) begin
          success = 0;
          done = 1;
          nextState = FINISH_HANDLE;
          incrTimeout = 0;
          startSender = 0;
        end
        else begin
          incrTimeout = 0;
          pktTypeSender = PID_DATA0;
          startSender = 1;
          payloadSender = data;
          success = 0;
          done = 0;
          nextState = SENDING_DATA0;
        end
        incrNak = 0;
        resetReceiver_n = 1;
        resetCycleCounter_n = 1;
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

/*
  in transaction FSM
  I/O is analogous to out transaction FSM, with the difference of 
  pktReceived being an input from the receiver and no data input from
  upstream FSM
*/
module inTxnFSM
  (input logic startIn_n,
   input logic doneSender,
   input logic clock,
   input logic dataError, pidError, finishedReading,
   input logic [`PID_BITS - 1:0] pktTypeReceived,
   input logic [`PAYLOAD_BITS - 1:0] payloadReceived,
   output logic success, done,
   output logic [`PAYLOAD_BITS -1:0] pktReceived,
   output pid_t pktTypeSender,
   output logic [`PAYLOAD_BITS - 1 : 0] payloadSender,
   output logic start_sender,
   output logic resetReceiver_n);

  // State definition
  enum logic [2:0]{
    START, SENDING_IN, WAIT, TIMEOUT_HANDLER, NAK_HANDLER,
    SEND_ACK, SENDING_ACK} currState, nextState;

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

  always_comb begin
    case(currState)
      START: begin
        start_sender = 1'b1;
        pktTypeSender = PID_IN;
        
        success = 1'b0;
        done = 1'b0;  
        payloadSender = 64'd0;// bogus payload
        resetReceiver_n = 1'b1;
        resetCycleCounter_n = 1'b1;
        incrTimeout = 1'b0;
        incrNak = 1'b0;
        nextState = SENDING_IN;
      end
      SENDING_IN: begin
        start_sender = 1'b0; // releases the send button
        success = 1'b0;
        done = 1'b0;
        incrTimeout = 1'b0;
        incrNak = 1'b0;
        if (~doneSender) begin
          // have not done sending
          nextState = SENDING_IN;
          resetCycleCounter_n = 1'b1;
          resetReceiver_n = 1'b1;
        end
        else begin
          // done sending, reset receiver to start receiving
          resetCycleCounter_n = 1'b0;
          resetReceiver_n = 1'b0;
          nextState = WAIT;
        end
      end   
      WAIT: begin
        // release reset buttons
        resetCycleCounter_n = 1'b1; 
        resetReceiver_n = 1'b1;

        success = 1'b0;
        done = 1'b0;
        start_sender = 1'b0;
        if (~(timedOut || finishedReading)) begin
          nextState = WAIT;
          incrTimeout = 1'b0;
          incrNak = 1'b0;
        end
        else if (timedOut) begin // IN with timeout
          nextState = TIMEOUT_HANDLER;
          incrTimeout = 1'b1;
          incrNak = 1'b0;
        end
        else if (pidError || dataError) begin // IN with corrupted data
          nextState = NAK_HANDLER;
          incrTimeout = 1'b0;
          incrNak = 1'b1;
        end
        else begin
          // correct data received
          nextState = SEND_ACK;
          pktReceived = payloadReceived;
          incrTimeout = 1'b0;
          incrNak = 1'b0;
        end
      end 
      TIMEOUT_HANDLER: begin
        if (timeoutLimit) begin
          success = 1'b0; 
          done = 1'b1;
          incrTimeout = 1'b0;
          incrNak = 1'b0;
          start_sender = 1'b0;
          resetReceiver_n = 1'b1;
          resetCycleCounter_n = 1'b1;
          nextState = TIMEOUT_HANDLER;
        end
        else begin
          // retry again
          success = 1'b0;
          done = 1'b0;
          incrTimeout = 1'b0;
          incrNak = 1'b0;
          resetReceiver_n = 1'b1;
          resetCycleCounter_n = 1'b1;
          start_sender = 1'b1;
          pktTypeSender = PID_NAK;
          nextState = SENDING_IN;
          // bogus payload
        end
      end
      NAK_HANDLER: begin
        if (nakLimit) begin
          success = 1'b0;
          done = 1'b1;
          start_sender = 1'b0;
          resetReceiver_n = 1'b1;
          resetCycleCounter_n = 1'b1;
          incrTimeout = 1'b0;
          incrNak = 1'b0;
          nextState = NAK_HANDLER;
        end
        else begin
          // retry again
          success = 1'b0;
          done = 1'b0;
          start_sender = 1'b1;
          incrNak = 1'b0;
          incrTimeout = 1'b0;
          resetReceiver_n = 1'b1;
          resetCycleCounter_n = 1'b1;
          pktTypeSender = PID_NAK;
          // bogus payload
          nextState = SENDING_IN;
        end
      end
      SEND_ACK: begin
        start_sender = 1'b1;
        success = 1'b0;
        done = 1'b0;
        resetReceiver_n = 1'b1;
        resetCycleCounter_n = 1'b1;
        incrTimeout = 1'b0;
        incrNak = 1'b0;
        pktTypeSender = PID_ACK;
        payloadSender = 1'b0; // bogus payload
        nextState = SENDING_ACK;
      end
      SENDING_ACK: begin
        start_sender = 1'b0;
        resetReceiver_n = 1'b1;
        resetCycleCounter_n = 1'b1;
        incrTimeout = 1'b0;
        incrNak = 1'b1;
        if (~doneSender) begin
          nextState = SENDING_ACK;
          success = 1'b0;
          done = 1'b0;
        end else begin
          nextState = SENDING_ACK;
          success = 1'b1;
          done = 1'b1;
        end
      end
    endcase
  end
endmodule: inTxnFSM


// main encompassing module to include out and in transaction FSMs with
// packet sender and receiver
/*
  txnType: OUT_TXN OR IN_TXN
  isAddr: if sending an address, this is one so that sender can choose endp
  success,done Out,In: out,in transaction success and done
  pktReceived: the packet received by in transaction, can be bogus
*/
module usbController
  (
    input logic [`PAYLOAD_BITS - 1:0] data,
    input logic startOut_n, startIn_n,
    input txn_t txnType,
    input logic isAddr,
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

  logic resetReceiver_n;
  logic pidError, payloadError;
  logic [`PID_BITS - 1 : 0] pktTypeReceived;
  logic finishedReading;
  logic [`PAYLOAD_BITS - 1 : 0] payloadReceived;

  logic reset_nIn, reset_nOut;

  inTxnFSM inFSM (
    .startIn_n(startIn_n), .doneSender(doneSender), .dataError(payloadError),
    .pktTypeReceived(pktTypeReceived), .pidError(pidError), .clock(clock),
    .finishedReading(finishedReading), .payloadReceived(payloadReceived), 
    .success(successIn), .done(doneIn), .pktReceived(pktReceived), 
    .pktTypeSender(pktTypeInTxn), .payloadSender(payloadInTxn), 
    .start_sender(startInTxn), .resetReceiver_n(reset_nIn)
  );

  outTxnFSM outFSM (.startOut_n(startOut_n), .data(data), 
  .doneSender(doneSender), .dataError(payloadError),  .clock(clock),
  .pktTypeReceived(pktTypeReceived), .pidError(pidError), 
  .finishedReading(finishedReading), .payloadReceived(payloadReceived), 
  .pktTypeSender(pktTypeOutTxn), .payloadSender(payloadOutTxn), 
  .startSender(startOutTxn), .resetReceiver_n(reset_nOut), 
  .success(successOut), .done(doneOut));

  controlledSender packetSend (.pktTypeInTxn(pktTypeInTxn), 
  .pktTypeOutTxn(pktTypeOutTxn), .payloadInTxn(payloadInTxn),
  .payloadOutTxn(payloadOutTxn), .startInTxn(startInTxn), 
  .startOutTxn(startOutTxn), .clock(clock), .done(doneSender), .busOut(busOut),
  .txnType(txnType), .isAddr(isAddr));

  controlledReceiver packetReceive (.clock(clock), .reset_nIn(reset_nIn),
  .reset_nOut(reset_nOut), .txnType(txnType),
  .busIn(busIn), .pktType(pktTypeReceived), .pidError(pidError), 
  .payloadError(payloadError), .payload(payloadReceived), 
  .finishedReading(finishedReading));

endmodule: usbController

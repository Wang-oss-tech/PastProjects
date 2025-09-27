`default_nettype none

module MagComp
  # (parameter w = 8)
  (
    input logic [w - 1 : 0] A, B,
    output logic AltB, AeqB, AgtB
  );
  always_comb begin
    {AltB, AeqB, AgtB} = 3'd0;
    if (A < B) begin
      AltB = 1'b1;
    end
    else if (A > B) begin
      AgtB = 1'b1;
    end
    else begin
      AeqB = 1'b1;
    end
  end
endmodule: MagComp


module Adder
  # (parameter w = 8)
  (
    input logic [w - 1 : 0] A, B,
    input logic cin,
    output logic [w - 1 : 0] S,
    output logic cout
  );
  logic [w:0] sum_raw;
  assign sum_raw = cin + A + B;
  assign cout = sum_raw [w];
  assign S = sum_raw [w - 1 : 0];
endmodule: Adder


module Multiplexer 
  # (parameter w = 8)
  (
    input logic [w - 1 : 0] I,
    input logic [($clog2(w) - 1) : 0] S,
    output logic Y
  );
  // handle illegal select input by returning 0
  assign Y = I[S];
endmodule: Multiplexer


module Mux2to1
  #(parameter w = 8)
  (
    input logic [w - 1 : 0] I0, I1,
    input logic S,
    output logic [w - 1 : 0] Y
  );
  assign Y = S? I1 : I0;
endmodule : Mux2to1

// For the decoder, need a response from Piazza

module Decoder
  #(parameter w = 8)
  (
    input logic [($clog2(w) - 1) : 0] I,
    input logic en,
    output logic [(w - 1) : 0] D
  );
  always_comb begin
    D = '0;
    D[I] = en? 1'b1 : 1'b0;
  end
endmodule: Decoder

module DFlipFlop
  (
    input logic preset_L, reset_L, clock, D, en,
    output logic Q
  );
  always_ff @(posedge clock, negedge preset_L, negedge reset_L) begin
    if (~preset_L) begin
      Q <= 1'b1;
    end
    else if (~reset_L) begin
      Q <= 1'b0;
    end
    else if (en) begin
      Q <= D;
    end
    else begin
      Q <= Q;
    end
  end
endmodule: DFlipFlop


module Register
  # (parameter w = 8)
  (
    input logic en, clear, clock,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (en) begin
      Q <= D;
    end
    else if (clear) begin
      Q <= '0;
    end
    else begin
      Q <= Q;
    end
  end
endmodule: Register

module Register_async
  # (parameter w = 8)
  (
    input logic en, reset_l, clock,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock, negedge reset_l) begin
    if (~reset_l) begin
      Q <= '0;
    end
    else if (en) begin
      Q <= D;
    end
    else begin
      Q <= Q;
    end
  end
endmodule: Register_async

module Register_async_customReset
  # (parameter w = 8)
  (
    input logic en, reset_l, clock,
    input logic [w - 1 : 0] D, resetValue,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock, negedge reset_l) begin
    if (~reset_l) begin
      Q <= resetValue;
    end
    else if (en) begin
      Q <= D;
    end
    else begin
      Q <= Q;
    end
  end
endmodule: Register_async_customReset


module Counter
  # (parameter w = 8)
  (
    input logic en, clear, load, up, clock,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (clear) begin
        Q <= '0;
      end
    else if (load) begin
      Q <= D;
    end
    else if (en) begin
      if (up) begin
        Q <= Q + 1;
      end
      else begin
        Q <= Q - 1;
      end
    end
    else begin
      Q <= Q;
    end
  end
endmodule: Counter

module Counter_async
  # (parameter w = 8)
  (
    input logic en, reset_l, load, up, clock,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock, negedge reset_l) begin
    if (~reset_l) begin
        Q <= '0;
      end
    else if (load) begin
      Q <= D;
    end
    else if (en) begin
      if (up) begin
        Q <= Q + 1;
      end
      else begin
        Q <= Q - 1;
      end
    end
    else begin
      Q <= Q;
    end
  end
endmodule: Counter_async

// FiveCounter adds/substracts 5 instead of 1 for the purpose of paddle movement
module CountFive
  # (parameter w = 8)
  (
    input logic en, clear, load, up, clock,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (clear) begin
        Q <= '0;
      end
    else if (load) begin
      Q <= D;
    end
    else if (en) begin
      if (up) begin
        Q <= Q + 5;
      end
      else begin
        Q <= Q - 5;
      end
    end
    else begin
      Q <= Q;
    end
  end
endmodule: CountFive

// TwoCounter adds/substracts 2 instead of 1 for the purpose of paddle movement
module TwoCounter
  # (parameter w = 8)
  (
    input logic en, clear, load, up, clock,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (clear) begin
        Q <= '0;
      end
    else if (load) begin
      Q <= D;
    end
    else if (en) begin
      if (up) begin
        Q <= Q + 2;
      end
      else begin
        Q <= Q - 2;
      end
    end
    else begin
      Q <= Q;
    end
  end
endmodule: TwoCounter

// synchronizer for async inputs
module Synchronizer
    (input logic async,
    output logic sync,
    input logic clock);

    logic temp;
    always_ff @(posedge clock) begin
        temp <= async;
        sync <= temp;
    end

endmodule: Synchronizer


module ShiftRegister_SIPO
  # (parameter w = 8)
  (
    input logic serial, en, left, clock,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (en) begin
      if (left) begin
        Q <= {Q [w - 2 : 0], serial};
      end
      else begin
        Q <= {serial, Q [w - 1 : 1]};
      end
    end
    else begin
      Q <= Q;
    end
  end
endmodule: ShiftRegister_SIPO


module ShiftRegister_PIPO
  # (parameter w = 8)
  (
    input logic [w - 1 : 0] D,
    input logic en, left, clock, load,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (load) begin
      Q <= D;
    end
    else if (en) begin
      if (left) begin
        Q <= (Q << 1);
      end
      else begin
        Q <= (Q >> 1);
      end
    end
    else begin
      Q <= Q;
    end
  end
endmodule: ShiftRegister_PIPO


module BarrelShiftRegister
  # (parameter w = 8)
  (
    input logic en, load, clock,
    input logic [1:0] by,
    input logic [w - 1 : 0] D,
    output logic [w - 1 : 0] Q
  );
  always_ff @(posedge clock) begin
    if (load) begin
      Q <= D;
    end
    else if (en) begin
      Q <= (Q << 1);
    end
    else begin
      Q <= Q;
    end
  end
endmodule: BarrelShiftRegister


module BusDriver
  # (parameter w = 8)
  (
    input logic en,
    input logic [w - 1 : 0] data,
    output logic [w - 1 : 0] buff,
    inout tri [w - 1 : 0] bus
  );
  assign bus = (en) ? data : 'z;
  assign buff = bus;
endmodule: BusDriver


module Memory
  # (parameter DW = 16, parameter W = 256, parameter AW = $clog2(W))
    (
      input logic re, we, clock,
      input logic [AW-1:0] addr,
      inout tri [DW-1:0] data
    );
    logic [DW-1:0] M[W];
    logic [DW-1:0] rData;
    assign data = (re) ? rData: 'z;
    always_ff @(posedge clock) begin
      if (we)
      M[addr] <= data;
    end
    always_comb
      rData = M[addr];
endmodule: Memory

module RangeCheck
  # (parameter w = 10)
  (
    input logic [w - 1 : 0] high, low, val,
    output logic is_between
  );
  assign is_between = (val >= low && val <= high);
endmodule: RangeCheck

module OffsetCheck
  # (parameter w = 10)
  (
    input logic [w - 1 : 0] delta, low, val,
    output logic is_between
  );
  RangeCheck #(w) offset_checker (.high(low + delta), .low(low), .val(val), 
  .is_between(is_between));
endmodule: OffsetCheck

module hexDisplay0 (
  input logic [3:0] num,
  output logic [6:0] HEX0
);
always_comb begin
  case (num)
    4'd0: HEX0 = 7'b1000000;
    4'd1: HEX0 = 7'b1111001;
    4'd2: HEX0 = 7'b0100100;
    4'd3: HEX0 = 7'b0110000;
    4'd4: HEX0 = 7'b0011001;
    4'd5: HEX0 = 7'b0010010;
    4'd6: HEX0 = 7'b0000010;
    4'd7: HEX0 = 7'b1111000;
    4'd8: HEX0 = 7'b0000000;
    4'd9: HEX0 = 7'b0010000;
    4'd10: HEX0 = 7'b0001000;
    4'd11: HEX0 = 7'b0000011;
    4'd12: HEX0 = 7'b1000110;
    4'd13: HEX0 = 7'b0100001;
    4'd14: HEX0 = 7'b0000110;
    4'd15: HEX0 = 7'b0001110;
  endcase
end
endmodule: hexDisplay0

module hexDisplay1 (
  input logic [3:0] num,
  output logic [6:0] HEX1
);
always_comb begin
  case (num)
    4'd0: HEX1 = 7'b1000000;
    4'd1: HEX1 = 7'b1111001;
    4'd2: HEX1 = 7'b0100100;
    4'd3: HEX1 = 7'b0110000;
    4'd4: HEX1 = 7'b0011001;
    4'd5: HEX1 = 7'b0010010;
    4'd6: HEX1 = 7'b0000010;
    4'd7: HEX1 = 7'b1111000;
    4'd8: HEX1 = 7'b0000000;
    4'd9: HEX1 = 7'b0010000;
    4'd10: HEX1 = 7'b0001000;
    4'd11: HEX1 = 7'b0000011;
    4'd12: HEX1 = 7'b1000110;
    4'd13: HEX1 = 7'b0100001;
    4'd14: HEX1 = 7'b0000110;
    4'd15: HEX1 = 7'b0001110;
  endcase
end
endmodule: hexDisplay1

module hexDisplay2 (
  input logic [3:0] num,
  output logic [6:0] HEX2
);
always_comb begin
  case (num)
    4'd0: HEX2 = 7'b1000000;
    4'd1: HEX2 = 7'b1111001;
    4'd2: HEX2 = 7'b0100100;
    4'd3: HEX2 = 7'b0110000;
    4'd4: HEX2 = 7'b0011001;
    4'd5: HEX2 = 7'b0010010;
    4'd6: HEX2 = 7'b0000010;
    4'd7: HEX2 = 7'b1111000;
    4'd8: HEX2 = 7'b0000000;
    4'd9: HEX2 = 7'b0010000;
    4'd10: HEX2 = 7'b0001000;
    4'd11: HEX2 = 7'b0000011;
    4'd12: HEX2 = 7'b1000110;
    4'd13: HEX2 = 7'b0100001;
    4'd14: HEX2 = 7'b0000110;
    4'd15: HEX2 = 7'b0001110;
  endcase
end
endmodule: hexDisplay2

module hexDisplay3 (
  input logic [3:0] num,
  output logic [6:0] HEX3
);
always_comb begin
  case (num)
    4'd0: HEX3 = 7'b1000000;
    4'd1: HEX3 = 7'b1111001;
    4'd2: HEX3 = 7'b0100100;
    4'd3: HEX3 = 7'b0110000;
    4'd4: HEX3 = 7'b0011001;
    4'd5: HEX3 = 7'b0010010;
    4'd6: HEX3 = 7'b0000010;
    4'd7: HEX3 = 7'b1111000;
    4'd8: HEX3 = 7'b0000000;
    4'd9: HEX3 = 7'b0010000;
    4'd10: HEX3 = 7'b0001000;
    4'd11: HEX3 = 7'b0000011;
    4'd12: HEX3 = 7'b1000110;
    4'd13: HEX3 = 7'b0100001;
    4'd14: HEX3 = 7'b0000110;
    4'd15: HEX3 = 7'b0001110;
  endcase
end
endmodule: hexDisplay3
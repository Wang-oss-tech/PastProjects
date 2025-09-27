`default_nettype none

/* 3:8 decoder with enable */
module Decoder3to8
  (input  logic [2:0] I,
   input  logic       en,
   output logic [7:0] D);

  always_comb begin
    D = 8'b0;
    if (en === 1'b1)
      D[I] = 1'b1;
    end

endmodule : Decoder3to8

/* 16-bit combinational barrel shifter */
module BarrelShifter
  (input  logic [15:0] V,  // Value
   input  logic [ 3:0] by,
   output logic [15:0] S); // Shifted
   
  assign S = V << by;
  
endmodule : BarrelShifter

/* 8:1 multiplexer */
module Multiplexer8to1
  (input  logic [7:0] I,
   input  logic [2:0] S,
   output logic       Y);

  always_comb
    case (S)
      3'h1 : Y = I[1];
      3'h2 : Y = I[2];
      3'h3 : Y = I[3];
      3'h4 : Y = I[4];
      3'h5 : Y = I[5];
      3'h6 : Y = I[6];
      3'h7 : Y = I[7];
      default : Y = I[0];
    endcase


endmodule : Multiplexer8to1

/* 8-bit magnitude comparator */
module MagComparator8Bit
  (input  logic [7:0] A, B,
   output logic       AgtB, AeqB, AltB);

  assign AeqB = (A == B);
  assign AgtB = (A > B);
  assign AltB = (A < B);

endmodule : MagComparator8Bit

/* 4-bit comparator */
module Comparator
  (input  logic [3:0] A, B,
   output logic       AeqB);

  logic [7:0] A8, B8;
  assign A8 = {4'b0, A};
  assign B8 = {4'b0, B};

  MagComparator8Bit mc(.A(A8), 
                   .B(B8), 
                   .AeqB,
                   .AltB(),
                   .AgtB()
                   );
endmodule : Comparator

/*
 * A library of components, usable for many future hardware designs.
 */
 
// A Magnitude Comparator does an unsigned comparison of two input values.
module MagComp
  #(parameter   WIDTH = 8)
  (output logic             AltB, AeqB, AgtB,
   input  logic [WIDTH-1:0] A, B);

  assign AeqB = (A == B);
  assign AltB = (A <  B);
  assign AgtB = (A >  B);

endmodule: MagComp

// An Adder is a combinational sum generator.
module Adder
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] A, B,
   output logic [WIDTH:0] sum);
   
   assign sum = A + B;
   
endmodule : Adder

// The Multiplexer chooses one of WIDTH bits
module Multiplexer
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0]         I,
   input  logic [$clog2(WIDTH)-1:0] S,
   output logic                     Y);
   
   assign Y = I[S];
   
endmodule : Multiplexer

// The 2-to-1 Multiplexer chooses one of two multi-bit inputs.
module Mux2to1
  #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] I0, I1,
   input  logic             S,
   output logic [WIDTH-1:0] Y);
   
  assign Y = (S) ? I1 : I0;
  
endmodule : Mux2to1

// The Decoder converts from binary to one-hot codes.
module Decoder
  #(parameter WIDTH=8)
  (input  logic [$clog2(WIDTH)-1:0] I,
   input  logic                     en,
   output logic [WIDTH-1:0]         D);
   
  always_comb begin
    D = '0;
    if (en)
      D[I] = 1'b1;
  end
  
endmodule : Decoder

// A DFlipFlop stores the input bit synchronously with the clock signal.
// preset and reset are asynchronous inputs.
module DFlipFlop
  (input  logic D,
   input  logic preset_L, reset_L, clock,
   output logic Q);
   
  always_ff @(posedge clock, negedge preset_L, negedge reset_L)
    if (~preset_L & reset_L)
      Q <= 1'b1;
    else if (~reset_L & preset_L)
      Q <= 1'b0;
    else if (~reset_L & ~preset_L)
      Q <= 1'bX;
    else
      Q <= D;
    
endmodule : DFlipFlop

module Register
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, clock,
   output logic [WIDTH-1:0] Q);
  
  // Asynchronous reset
  always_ff @(posedge clock or posedge clear)
    if (clear)
      Q <= '0;
    else if (en)
      Q <= D;
      
      
endmodule : Register

// A binary up-down counter.
// Clear has priority over Load, which has priority over Enable
module Counter
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, load, clock, up,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock)
    if (clear)
      Q <= {WIDTH {1'b0}};
    else if (load)
      Q <= D;
    else if (en)
      if (up)
        Q <= Q + 1'b1;
      else
        Q <= Q - 1'b1;
        
endmodule : Counter

// A Synchronizer takes an asynchronous input and changes it to synchronized
module Synchronizer
  (input  logic async, clock,
   output logic sync);
 
  logic metastable;
    
  DFlipFlop one(.D(async),
                .Q(metastable),
                .clock,
                .preset_L(1'b1), 
                .reset_L(1'b1)
               );

  DFlipFlop two(.D(metastable),
                .Q(sync),
                .clock,
                .preset_L(1'b1), 
                .reset_L(1'b1)
               );

endmodule : Synchronizer

// A PIPO Shift Register, with controllable shift direction
// Load has priority over shifting.
module ShiftRegister_PIPO
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, left, load, clock,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock)
    if (load)
      Q <= D;
    else if (en)
      if (left)
        Q <= {Q[WIDTH-2:0], 1'b0};
      else
        Q <= {1'b0, Q[WIDTH-1:1]};
        
endmodule : ShiftRegister_PIPO

// A SIPO Shift Register, with controllable shift direction
// Load has priority over shifting.
module ShiftRegister_SIPO
  #(parameter WIDTH=8)
  (input  logic             serial,
   input  logic             en, left, clock,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock)
    if (en)
      if (left)
        Q <= {Q[WIDTH-2:0], serial};
      else
        Q <= {serial, Q[WIDTH-1:1]};
        
endmodule : ShiftRegister_SIPO

// A BSR shifts bits to the left by a variable amount
module BarrelShiftRegister
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, load, clock,
   input  logic [      1:0] by,
   output logic [WIDTH-1:0] Q);
   
  logic [WIDTH-1:0] shifted;
  always_comb
    case (by)
      default: shifted = Q;
      2'b01: shifted = {Q[WIDTH-2:0], 1'b0};
      2'b10: shifted = {Q[WIDTH-3:0], 2'b0};
      2'b11: shifted = {Q[WIDTH-4:0], 3'b0};
    endcase
   
  always_ff @(posedge clock)
    if (load)
        Q <= D;
    else if (en)
        Q <= shifted;
    
endmodule : BarrelShiftRegister

/* start of hw7 */
module BusDriver
  #(parameter WIDTH = 8)
  (input logic              en,
   input logic [WIDTH-1:0]  data,
   inout tri    [WIDTH-1:0] bus,
   output logic [WIDTH-1:0] buff);

  assign buff = bus;
  assign bus = (en) ? data : 'bz;
endmodule: BusDriver 


/* Combinational-read, synchronous write memory */
module Memory
  #(parameter DW = 16,
              W = 256,
              AW = $clog2(W))
  (input logic  re, we, clock,
   input logic  [AW-1:0]  addr,
   inout tri    [DW-1:0]  data); // at times data = output, input otherwise

  logic [DW-1:0] M[W];
  logic [DW-1:0] rData;

  assign data = (re) ? rData: 'bz; // reading data from mem

  always_ff @ (posedge clock)
    if(we)
      M[addr] <= data; // writing data from bus to memory (sequential)
  
  always_comb begin
    rData = M[addr]; // data is always equal to memory
  end
    
endmodule: Memory
 






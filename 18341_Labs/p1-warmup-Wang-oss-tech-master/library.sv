`default_nettype none

// A DFlipFlop stores the input bit synchronously with the clock signal.
// preset and reset are asynchronous inputs.
module DFlipFlop
  (input  logic D,
   input  logic preset_L, reset_L, clock,
   output logic Q);
   
  always_ff @(posedge clock or negedge preset_L or negedge reset_L)
    if (~preset_L) begin
      Q <= 1'b1;
    end else if (~reset_L) begin
      Q <= 1'b0;
    end else begin
      Q <= D;
    end
    
endmodule : DFlipFlop


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

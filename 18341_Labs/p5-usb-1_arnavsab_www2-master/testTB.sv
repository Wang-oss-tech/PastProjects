`default_nettype none

// module TB();
//   logic clock;

//   initial begin
//     clock = 0;
//     forever #5 clock = ~clock;
//   end

//   initial begin
//     for (int i = 0; i < 50; i++) begin
//       @(posedge clock);
//     end

//     $finish;
//   end
// endmodule: TB
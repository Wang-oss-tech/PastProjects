`default_nettype none

// Starter code for Project 2.  See README.md for details
module ChipInterface
  (input  logic       CLOCK_50,
   input  logic [0:0] SW,
   input  logic [0:0] KEY,
   output logic [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);

   logic [23:0] final_sum;
   
   logic [11:0] clock_cycles;

   logic done_computing;

   matrix_multiply dut( .CLOCK_50(CLOCK_50),
                        .reset_L(KEY),
                        .*);
endmodule : ChipInterface

/* Multiplication Block */
module matrix_multiply
  (input logic CLOCK_50, reset_L,
   output logic [23:0] final_sum,
   output logic [11:0] clock_cycles,
   output logic done_computing);

  
  
  logic [23:0] c_total_read, c_total_result;


  logic [11:0] cycleTicks;
  assign done_computing = (cycleTicks == 520);

    
  // Total Cycle Counter
  matrix_counter #(.WIDTH(12), .INCREMENT(1)) total_cycleCounter(.D(1'b0),
                                                                 .Q(cycleTicks),
                                                                 .en(~done_computing),
                                                                 .clear(~reset_L),
                                                                 .load(1'b0),
                                                                 .clock(CLOCK_50));

  logic add_enable;
  assign add_enable = (cycleTicks > 0);

  logic [31:0] a_index;
  logic [7:0] b_index;
  logic reload_b;

  assign reload_b = (b_index == 96);

  // romA index counter 
  matrix_counter #(.WIDTH(32), .INCREMENT(32)) romA_counter(.D(1'b0), 
                                                            .en(1), 
                                                            .clear(~reset_L), 
                                                            .load(1'b0), 
                                                            .clock(CLOCK_50), 
                                                            .up(1'b1), 
                                                            .Q(a_index));

  // romB index counter
  matrix_counter #(.WIDTH(8), .INCREMENT(32)) romB_counter(.D(8'b0), 
                                                           .en(reload_b), 
                                                           .clear(~reset_L), 
                                                           .load(1'b0), 
                                                           .clock(CLOCK_50), 
                                                           .up(1'b1), 
                                                           .Q(b_index));

  logic [31:0][7:0] matrix_a_read, matrix_b_read, matrix_a_output, matrix_b_output;
  logic [31:0][15:0] mult_result, mult_result_output;
  logic [15:0][31:0] add_firstLayer, add_firstLayer_output;
  logic [7:0][31:0] add_secondLayer, add_secondLayer_output;
  logic [3:0][31:0] add_thirdLayer, add_thirdLayer_output;
  logic [1:0][31:0] add_fourthLayer, add_fourthLayer_output;
  
  // generate
  genvar i, j, k, l, m, n;

  generate
    // Instantial romA blocks
    for (i = 0; i < 32; i = i + 2) begin 

      // 16 romA Blocks
      romA_128x128 rom_A (.address_a(i + a_index), 
                          .address_b(i + a_index + 1), 
                          .clock(CLOCK_50), 
                          .q_a(matrix_a_read[i]), 
                          .q_b(matrix_a_read[i + 1]));
      
      // 16 romB Blocks
      romB_128x1 rom_B (.address_a(i + b_index), 
                        .address_b(i + b_index + 1), 
                        .clock(CLOCK_50), 
                        .q_a(matrix_b_read[i]), 
                        .q_b(matrix_b_read[i + 1]));

    end

    for (j = 0; j < 32; j = j + 1) begin

      // put all 32 romA values in registers
      Register #(8) reg_A(.D(matrix_a_read[j]), .en(add_enable), .clear(~reset_L), .clock(CLOCK_50), .Q(matrix_a_output[j]));

      // put all 32 romB values in registers
      Register #(8) reg_B(.D(matrix_b_read[j]), .en(add_enable), .clear(~reset_L), .clock(CLOCK_50), .Q(matrix_b_output[j]));

      // 32 Multipliers, multiply each index in matrix A to matrix B    
      multiplier_8816 multiplier(.dataa(matrix_a_output[j]), .datab(matrix_b_output[j]), .result(mult_result[j]));

      // 32 Registers, store multiplier output into registers
      Register #(16) reg_multiplier(.D(mult_result[j]), .en(1'b1), .clear(~reset_L), .clock(CLOCK_50), .Q(mult_result_output[j]));

    end

    for (k = 0; k < 16; k = k + 1) begin
      // START HERE
      // 16 Adders 
      Adder #(32) addFirstLayer(.A(mult_result_output[k]), 
                                .B(mult_result_output[k + 16]), 
                                .sum(add_firstLayer[k])
                                );

      // Store adder result to output
      Register #(32) reg_firstLayer(.D(add_firstLayer[k]), 
                                    .en(1'b1), 
                                    .clear(~reset_L), 
                                    .clock(CLOCK_50), 
                                    .Q(add_firstLayer_output[k]));

    end 

    for (l = 0; l < 8; l = l + 1) begin

      // 8 Adders 
      Adder #(32) addSecondLayer(.A(add_firstLayer_output[l]), 
                                .B(add_firstLayer_output[l + 8]), 
                                 
                                .sum(add_secondLayer[l]));

      // Store adder result to output
      Register #(32) reg_secondLayer(.D(add_secondLayer[l]), 
                                    .en(1'b1), 
                                    .clear(~reset_L), 
                                    .clock(CLOCK_50), 
                                    .Q(add_secondLayer_output[l]));

    end 

    for (m = 0; m < 4; m = m + 1) begin

      // 4 Adders 
      Adder #(32) addThirdLayer(.A(add_secondLayer_output[m]), 
                                .B(add_secondLayer_output[m + 4]), 
                                .sum(add_thirdLayer[m]));

      // Store adder result to output
      Register #(32) reg_thirdLayer(.D(add_thirdLayer[m]), 
                                    .en(1'b1), .clear(~reset_L), 
                                    .clock(CLOCK_50), 
                                    .Q(add_thirdLayer_output[m]));

    end 

    for (n = 0; n < 2; n = n + 1) begin

      // 2 Adders 
      Adder #(32) addFourthLayer(.A(add_thirdLayer_output[n]), 
                                .B(add_thirdLayer_output[n + 2]),
                                .sum(add_fourthLayer[n]));

      // Store adder result to output
      Register #(32) reg_fourthLayer(.D(add_fourthLayer[n]), 
                                    .en(1'b1), 
                                    .clear(~reset_L), 
                                    .clock(CLOCK_50), 
                                    .Q(add_fourthLayer_output[n]));
    end 
  endgenerate

  logic [23:0] add_finalLayer, add_finalLayer_output;

  // Final Layer
  Adder #(32) addFifthLayer(.A(add_fourthLayer_output[0]), .B(add_fourthLayer_output[1]), .sum(add_finalLayer));

  // Store adder result to output
  Register #(32) regFithLayer(.D(add_finalLayer), .en(1), .clear(~reset_L), .clock(CLOCK_50), .Q(add_finalLayer_output));

  // Add up AxB
  logic [31:0] add_total_read, add_total_result;

  Adder #(32) adderTotal(.A(add_finalLayer_output), 
                         .B(add_total_result), 
                          
                         .sum(add_total_read));

  Register #(32) adderTotal_reg(.D(add_total_read),
                                .en(~done_computing),
                                .clear(~reset_L),
                                .clock(CLOCK_50),
                                .Q(add_total_result));


  // Sum add_total_result (AxB sum) with matrix 

  logic done_traversing;
  assign done_traversing = (cycleTicks> 129);

  logic [15:0] matrix_c_read, matrix_c_output;

  logic [7:0] c_index;
  
  // Counter C
  matrix_counter #(.WIDTH(8), .INCREMENT(1)) romC_counter(.D(1'b0), 
                                                          .en(1), 
                                                          .clear(~reset_L), 
                                                          .load(1'b0), 
                                                          .clock(CLOCK_50), 
                                                          .up(1'b1), 
                                                          .Q(c_index));

  // Instantiate matrix c into rom
  romC_128x1 romC(.address_a(c_index), 
                  .address_b(), 
                  .clock(CLOCK_50), 
                  .q_a(matrix_c_read), 
                  .q_b());

  // C_index
  Register #(16) romC_reg(.D(matrix_c_read), 
                          .en(1'b1),
                          .clear(~reset_L), 
                          .clock(CLOCK_50), 
                          .Q(matrix_c_output));

  Adder #(24) c_adder(.A({8'b0,matrix_c_output}), 
                          .B(c_total_result), 
                           
                          .sum(c_total_read));

  Register #(24) romC_total_reg(.D(c_total_read), 
                                .en(~done_traversing), 
                                .clear(~reset_L), 
                                .clock(CLOCK_50), 
                                .Q(c_total_result));

  // Final Pipeline of AxB + C
  logic [31:0] add_read;

  Adder #(32) final_sum_adder(.A(c_total_result),
                            .B(add_total_result),
                            .sum(add_read)
                            );

  Register #(32) final_sum_reg(.D(add_read),
                             .en(done_computing),
                             .clear(~reset_L),
                             .clock(CLOCK_50),
                             .Q(final_sum));


  assign clock_cycles = cycleTicks;

endmodule: matrix_multiply


// Counter Module for Matrix
module matrix_counter
  #(parameter WIDTH=8,
              INCREMENT=1)
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
        Q <= Q + INCREMENT;
      else
        Q <= Q - 1'b1;
        
endmodule : matrix_counter
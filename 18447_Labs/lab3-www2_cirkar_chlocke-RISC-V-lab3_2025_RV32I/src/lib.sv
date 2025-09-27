/**
 * lib.sv
 *
 * RISC-V 32-bit Processor
 *
 * ECE 18-447
 * Carnegie Mellon University
 *
 * This is the library of standard components used by the RISC-V processor,
 * which includes both synchronous and combinational components.
 **/

/*----------------------------------------------------------------------------*
 *  You may edit this file and add or change any files in the src directory.  *
 *----------------------------------------------------------------------------*/

// Force the compiler to throw an error if any variables are undeclared
`default_nettype none

// Local Includes
`include "internal_defines.vh"      // Control signals struct, ALU ops

/*--------------------------------------------------------------------------------------------------------------------
 * Combinational Components
 *--------------------------------------------------------------------------------------------------------------------*/

/**
 * Selects on input from INPUTS inputs to output, each of WIDTH bits.
 *
 * Parameters:
 *  - INPUTS    The number of values from which the mux can select.
 *  - WIDTH     The number of bits each value contains.
 *
 * Inputs:
 *  - in        The values from which to select, packed together as a single
 *              bit-vector.
 *  - sel       The value from the inputs to output.
 *
 * Outputs:
 *  - out       The selected output from the inputs.
 **/
module mux
    #(parameter INPUTS=0, WIDTH=0)
    (input  logic [INPUTS-1:0][WIDTH-1:0]   in,
     input  logic [$clog2(INPUTS)-1:0]      sel,
     output logic [WIDTH-1:0]               out);

    assign out = in[sel];

endmodule: mux

/**
 * Adds two numbers of WIDTH bits, with a carry in bit, producing a sum and a
 * carry out bit.
 *
 * Parameters:
 *  - WIDTH     The number of bits of the numbers being summed together.
 *
 * Inputs:
 *  - cin       The carry in to the addition.
 *  - A         The first number to add.
 *  - B         The second number to add.
 *
 * Outputs:
 *  - cout      The carry out from the addition.
 *  - sum       The result of the addition.
 **/
module adder
    #(parameter WIDTH=0)
    (input  logic               cin,
     input  logic [WIDTH-1:0]   A, B,
     output logic               cout,
     output logic [WIDTH-1:0]   sum);

     assign {cout, sum} = A + B + cin;

endmodule: adder

/*--------------------------------------------------------------------------------------------------------------------
 * Synchronous Components
 *--------------------------------------------------------------------------------------------------------------------*/

/**
 * Latches and stores values of WIDTH bits and initializes to RESET_VAL.
 *
 * This register uses an asynchronous active-low reset and a synchronous
 * active-high clear. Upon clear or reset, the value of the register becomes
 * RESET_VAL.
 *
 * Parameters:
 *  - WIDTH         The number of bits that the register holds.
 *  - RESET_VAL     The value that the register holds after a reset.
 *
 * Inputs:
 *  - clk           The clock to use for the register.
 *  - rst_l         An active-low asynchronous reset.
 *  - clear         An active-high synchronous reset.
 *  - en            Indicates whether or not to load the register.
 *  - D             The input to the register.
 *
 * Outputs:
 *  - Q             The latched output from the register.
 **/
module register
   #(parameter                      WIDTH=0,
     parameter logic [WIDTH-1:0]    RESET_VAL='b0)
    (input  logic               clk, en, rst_l, clear,
     input  logic [WIDTH-1:0]   D,
     output logic [WIDTH-1:0]   Q);

     always_ff @(posedge clk, negedge rst_l) begin
         if (!rst_l)
             Q <= RESET_VAL;
         else if (clear)
             Q <= RESET_VAL;
         else if (en)
             Q <= D;
     end

endmodule:register

// Pipeline register between FETCH1 and FETCH2 stages
module registerF1F2
    (input logic clk, en,
    input logic [31:0] pc, npc_plus4, instr, next_pc,
    output logic [31:0] pc_F1, npc_plus4_F1, instr_F1, next_pc_F1,
    input logic bTaken, flushInstr,
    output logic bTaken_F1, flushInstr_F1,
    input logic [61:0] sramReadData,
    output logic [61:0] sramReadData_F1);

    always_ff @(posedge clk) begin
        if (en) begin
            pc_F1 <= pc;
            npc_plus4_F1 <= npc_plus4;
            instr_F1 <= instr;
            bTaken_F1 <= bTaken;
            flushInstr_F1 <= flushInstr;
            sramReadData_F1 <= sramReadData;
            next_pc_F1 <= next_pc;
        end      
    end

endmodule: registerF1F2

// Pipeline register between FETCH2 and DECODE stages
module registerF2D
    (input logic clk, en,
    input logic [31:0] pc_F1, npc_plus4_F1, instr_F1, next_pc_F1,
    output logic [31:0] pc_F1F2, npc_plus4_F1F2, instr_F1F2, next_pc_F1F2,
    input logic bTaken_F1, flushInstr_F1, flushInstr2,
    output logic bTaken_F1F2, flushInstr_F1F2, flushInstr2_F2,
    input logic [61:0] sramReadData_F1,
    output logic [61:0] sramReadData_F1F2);

    always_ff @(posedge clk) begin
        if (en) begin
            pc_F1F2 <= pc_F1;
            npc_plus4_F1F2 <= npc_plus4_F1;
            instr_F1F2 <= instr_F1;
            bTaken_F1F2 <= bTaken_F1;
            flushInstr_F1F2 <= flushInstr_F1;
            flushInstr2_F2 <= flushInstr2;
            sramReadData_F1F2 <= sramReadData_F1;
            next_pc_F1F2 <= next_pc_F1;
        end      
    end

endmodule: registerF2D

// Pipeline register between DECODE and EXECUTE stages
module registerDE
    (input logic clk, en,
    input logic [31:0] pc_F1F2, npc_plus4_F1F2, instr_F1F2, rs1_data, rs2_data, next_pc_F1F2,
    input logic [31:0] se_immediate,
    input logic [4:0] rs1,
    input ctrl_signals_t  ctrl_signals,
    output logic [31:0] pc_F1F2D, npc_plus4_F1F2D, instr_F2D, rs1_data_D, next_pc_F1F2D,
    output logic [31:0] se_immediate_D, rs2_data_D,
    output ctrl_signals_t  ctrl_signals_D,
    output logic [4:0] rs1_D,
    input logic bTaken_F1F2, flushed,
    output logic bTaken_F1F2D, flushed_D,
    input logic [61:0] sramReadData_F1F2,
    output logic [61:0] sramReadData_F1F2D);
    

    always_ff @(posedge clk) begin
        if (en) begin
            pc_F1F2D <= pc_F1F2;
            npc_plus4_F1F2D <= npc_plus4_F1F2;
            instr_F2D <= instr_F1F2;
            rs1_data_D <= rs1_data;
            rs2_data_D <= rs2_data;
            se_immediate_D <= se_immediate;
            ctrl_signals_D <= ctrl_signals;
            rs1_D <= rs1;
            bTaken_F1F2D <= bTaken_F1F2;
            flushed_D <= flushed;
            sramReadData_F1F2D <= sramReadData_F1F2;
            next_pc_F1F2D <= next_pc_F1F2;
        end      
    end

endmodule: registerDE

// Pipeline register between EXECUTE and MEMORY1 stages
module registerEM1
    (input logic clk, en,
    input logic [31:0] pc_F1F2D, npc_plus4_F1F2D, instr_F2D, rs1_data_D, 
    input logic [31:0] alu_out, data_load_temp,  rs2_data_D,
    input ctrl_signals_t  ctrl_signals_D,
    input logic [4:0] rs1_D,
    output logic [31:0] pc_F1F2DE, npc_plus4_F1F2DE, instr_F2DE, 
    output logic [31:0] alu_out_E, data_load_temp_E, rs1_data_DE, rs2_data_DE,
    output ctrl_signals_t  ctrl_signals_DE,
    output logic [4:0] rs1_DE,
    input logic flushed_D,
    output logic flushed_DE);
    

    always_ff @(posedge clk) begin
        if (en) begin
            pc_F1F2DE <= pc_F1F2D;
            npc_plus4_F1F2DE <= npc_plus4_F1F2D;
            instr_F2DE <= instr_F2D;
            rs1_data_DE <= rs1_data_D;
            rs2_data_DE <= rs2_data_D;
            alu_out_E <= alu_out;
            data_load_temp_E <= data_load_temp;
            ctrl_signals_DE <= ctrl_signals_D;
            rs1_DE <= rs1_D;
            flushed_DE <= flushed_D;
        end      
    end

endmodule: registerEM1

// Pipeline register between MEMORY1 and MEMORY2 stages
module registerM1M2
    (input logic clk, en,
    input logic [31:0] npc_plus4_F1F2DE, instr_F2DE, 
    input logic [31:0] alu_out_E, data_load_temp_E, rs1_data_DE,
    input ctrl_signals_t  ctrl_signals_DE,
    input logic [4:0] rs1_DE,
    output logic [31:0] npc_plus4_F1F2DEM1, instr_F2DEM1, 
    output logic [31:0] alu_out_EM1, data_load_temp_EM1, rs1_data_DEM1,
    output ctrl_signals_t  ctrl_signals_DEM1,
    output logic [4:0] rs1_DEM1,
    input logic flushed_DE,
    output logic flushed_DEM1);
    

    always_ff @(posedge clk) begin
        if (en) begin
            npc_plus4_F1F2DEM1 <= npc_plus4_F1F2DE;
            instr_F2DEM1 <= instr_F2DE;
            alu_out_EM1 <= alu_out_E;
            data_load_temp_EM1 <= data_load_temp_E;
            ctrl_signals_DEM1 <= ctrl_signals_DE;
            rs1_data_DEM1 <= rs1_data_DE;
            rs1_DEM1 <= rs1_DE;
            flushed_DEM1 <= flushed_DE;
        end      
    end

endmodule: registerM1M2

// Pipeline register between MEMORY2 and WRITEBACK stages
module registerM2W
    (input logic clk, en,
    input logic [31:0] npc_plus4_F1F2DEM1, instr_F2DEM1, 
    input logic [31:0] alu_out_EM1, data_load_temp_EM1, rs1_data_DEM1,
    input ctrl_signals_t  ctrl_signals_DEM1,
    input logic [4:0] rs1_DEM1,
    output logic [31:0] npc_plus4_F1F2DEM1M2, instr_F2DEM1M2, 
    output logic [31:0] alu_out_EM1M2, data_load_temp_EM1M2, rs1_data_DEM1M2,
    output ctrl_signals_t  ctrl_signals_DEM1M2,
    output logic [4:0] rs1_DEM1M2,
    input logic flushed_DEM1,
    output logic flushed_DEM1M2);

    always_ff @(posedge clk) begin
        if (en) begin
            npc_plus4_F1F2DEM1M2 <= npc_plus4_F1F2DEM1;
            instr_F2DEM1M2 <= instr_F2DEM1;
            alu_out_EM1M2 <= alu_out_EM1;
            data_load_temp_EM1M2 <= data_load_temp_EM1;
            ctrl_signals_DEM1M2 <= ctrl_signals_DEM1;
            rs1_data_DEM1M2 <= rs1_data_DEM1;
            rs1_DEM1M2 <= rs1_DEM1;
            flushed_DEM1M2 <= flushed_DEM1;
        end      
    end

endmodule: registerM2W

/**
 * riscv_core.sv
 *
 * RISC-V 32-bit Processor
 *
 * ECE 18-447
 * Carnegie Mellon University
 *
 * This is the core part of the processor, and is responsible for executing the
 * instructions and updating the CPU state appropriately.
 *
 * This is where you can start to add code and make modifications to fully
 * implement the processor. You can add any additional files or change and
 * delete files as you need to implement the processor, provided that they are
 * under the src directory. You may not change any files outside the src
 * directory. The only requirement is that there is a riscv_core module with the
 * interface defined below, with the same port names as below.
 *
 * The Makefile will automatically find any files you add, provided they are
 * under the src directory and have either a *.v, *.vh, or *.sv extension. The
 * files may be nested in subdirectories under the src directory as well.
 * Additionally, the build system sets up the include paths so that you can
 * place header files (*.vh) in any subdirectory in the src directory, and
 * include them from anywhere else inside the src directory.
 *
 * The compiler and synthesis tools support both Verilog and System Verilog
 * constructs and syntax, so you can write either Verilog or System Verilog
 * code, or mix both as you please.
 **/

/*----------------------------------------------------------------------------*
 *  You may edit this file and add or change any files in the src directory.  *
 *----------------------------------------------------------------------------*/

// RISC-V Includes
`include "riscv_abi.vh"             // ABI registers and definitions
`include "riscv_isa.vh"             // RISC-V ISA definitions
`include "memory_segments.vh"       // Memory segment starting addresses

// Local Includes
`include "internal_defines.vh"      // Control signals struct, ALU ops

/* A quick switch to enable/disable tracing. Comment out to disable. Please
 * comment this out before submitting your code. You'll also want to comment
 * this out for longer tests, as it will make them run much faster. */
`define TRACE

// Force the compiler to throw an error if any variables are undeclared
`default_nettype none

/**
 * The core of the RISC-V processor, everything except main memory.
 *
 * This is the RISC-V processor, which, each cycle, fetches the next
 * instruction, executes it, and then updates the register file, memory,
 * and register file appropriately.
 *
 * The memory that the processor interacts with is dual-ported with a
 * single-cycle synchronous write and combinational read. One port is used to
 * fetch instructions, while the other is for loading and storing data.
 *
 * Inputs:
 *  - clk               The global clock for the processor.
 *  - rst_l             The asynchronous, active low reset for the processor.
 *  - instr_mem_excpt   Indicates that an invalid instruction address was given
 *                      to memory.
 *  - data_mem_excpt    Indicates that an invalid address was given to the data
 *                      memory during a load and/or store operation.
 *  - instr             The instruction loaded loaded from the instr_addr
 *                      address in memory.
 *  - data_load         The data loaded from the data_addr address in memory.
 *
 * Outputs:
 *  - data_load_en      Indicates that data from the data_addr address in
 *                      memory should be loaded.
 *  - halted            Indicates that the processor has stopped because of a
 *                      syscall or exception. Used to indicate to the testbench
 *                      to end simulation. Must be held until next clock cycle.
 *  - data_store_mask   Byte-enable bit mask  signal indicating which bytes of data_store
 *                      should be written to the data_addr address in memory.
 *  - instr_addr        The address of the instruction to load from memory.
 *  - instr_stall       stall instruction load from memory if multicycle.
 *  - data_addr         The address of the data to load or store from memory.
 *  - data_stall        stall data load from memory if multicycle.
 *  - data_store        The data to store to the data_addr address in memory.
 **/
module riscv_core
    (input  logic           clk, rst_l, instr_mem_excpt, data_mem_excpt,
     input  logic [31:0]    instr, data_load,
     output logic           data_load_en, halted,
     output logic [3:0]     data_store_mask,
     output logic [29:0]    instr_addr, data_addr,
     output logic           instr_stall, data_stall,
     output logic [31:0]    data_store);

    /* Import the ISA field types, and the argument to ecall to halt the
     * simulator, and the start of the user text segment. */
    import RISCV_ISA::*;
    import RISCV_ABI::ECALL_ARG_HALT;
    import MemorySegments::USER_TEXT_START;

    // Manage the value of the PC, don't increment if the processor is halted
    logic [31:0]    pc, npc_plus4, npc_offset, next_pc, npc_jal;
    logic [31:0]    boffset;
    logic 	    bcond;

    // Execute the instruction, performing the needed ALU operation
    logic [31:0]    alu_out;
    logic [31:0]    se_immediate, alu_src2, se_immediate_D;
    logic [4:0]     rs1, rs2, rdToWrite, rs1_D, rs1_DE, rs1_DEM1, rs1_DEM1M2;

    /* declare variables (as logic propagates through the pipeline, the 
    suffix represents which stage they originated in and the stages they have 
    passed through) */
    logic [31:0] npc_jal_DE, npc_jal_D;
    logic [31:0] pc_F1, pc_F1F2, pc_F1F2D, pc_F1F2DE;
    logic [31:0] rs2_data_D, rs2_data_DE, rs1_data_D, rs1_data_DE;
    logic [31:0] rs1_data_DEM1, rs1_data_DEM1M2;
    logic [31:0] npc_plus4_F1, npc_plus4_F1F2, npc_plus4_F1F2D;
    logic [31:0] npc_plus4_F1F2DE, npc_plus4_F1F2DEM1, npc_plus4_F1F2DEM1M2;
    logic [31:0] instr_F1, instr_F1F2, instr_F2, instr_F2D, instr_F2DE;
    logic [31:0] instr_F2DEM1, instr_F2DEM1M2;
    logic [31:0] alu_out_E, alu_out_EM1, alu_out_EM1M2;
    logic [31:0] data_load_temp_E, data_load_temp_EM1, data_load_temp_EM1M2;
    ctrl_signals_t  ctrl_signals_D, ctrl_signals_DE, ctrl_signals_DEM1;
    ctrl_signals_t ctrl_signals_DEM1M2;
    logic timeToWrite;
    logic [31:0]    a0_value;
    logic           syscall_halt, exception_halt;
    logic [31:0] data_load_temp;
    logic [31:0]    rs1_data, rs2_data, rd_data, rs2_data_temp;
    ctrl_signals_t  ctrl_signals;

    logic [31:0] cycle_counter, num_instr_exec, num_stall_instr_ID;
    logic [31:0] instr_stall_1, instr_stall_2, instr_stall_3, instr_stall_4;
    logic prev_instr_stalled;
    logic [2:00] numStalls;
    logic [2:0] prevNumStalls;
    always_ff @(posedge clk, negedge rst_l) begin
        if (~rst_l) begin
            cycle_counter <= 32'd0;
            prev_instr_stalled <= 1'b0;
            num_stall_instr_ID <= 32'd0;
            numStalls <= 3'd0;
            prevNumStalls <= 3'd0;
            instr_stall_1 <= 32'd0;
            instr_stall_2 <= 32'd0;
            instr_stall_3 <= 32'd0;
            instr_stall_4 <= 32'd0;
            num_instr_exec <= 32'd0;
        end
        else begin
            cycle_counter <= cycle_counter + 32'd1;
            prev_instr_stalled <= instr_stall;
            if (~prev_instr_stalled && instr_stall) num_stall_instr_ID <= num_stall_instr_ID + 32'd1;
            if (instr_stall) numStalls <= numStalls + 3'd1;
            else numStalls <= 3'd0;
            prevNumStalls <= numStalls;
            if (prev_instr_stalled & ~instr_stall) begin
                if (prevNumStalls == 3'd1) instr_stall_1 <= instr_stall_1 + 32'd1;
                else if (prevNumStalls == 3'd2) instr_stall_2 <= instr_stall_2 + 32'd1;
                else if (prevNumStalls == 3'd3) instr_stall_3 <= instr_stall_3 + 32'd1;
                else if (prevNumStalls == 3'd4) instr_stall_4 <= instr_stall_4 + 32'd1;
            end
            if (~instr_stall) num_instr_exec <= num_instr_exec + 32'd1;
        end
    end

    always_ff @(posedge clk) begin
        if (ctrl_signals_DEM1.syscall)
            $display("NUMBER OF CYCLES: %d\nNUMBER OF INSTRUCTIONS EXECUTED: %d\nNUMBER OF INSTRUCTIONS STALLED IN ECODE PHASE: %d\nNUMBER OF INSTRUCTIONS STALLED FOR 1 CYCLE: %d\nNUMBER OF INSTRUCTIONS STALLED FOR 2 CYCLES: %d\nNUMBER OF INSTRUCTIONS STALLED FOR 3 CYCLES: %d\nNUMBER OF INSTRUCTIONS STALLED FOR 4 CYCLES: %d\n", 
            cycle_counter, num_instr_exec, num_stall_instr_ID, instr_stall_1, instr_stall_2, instr_stall_3, instr_stall_4);
    end

    IF fetchStage (.clk, .rst_l, .halted, .bcond, .instr_stall, .alu_out, 
        .npc_jal, .npc_plus4, .pc, .instr_addr, .boffset);

    registerF1F2 r1 (.clk, .en(~instr_stall), .pc, .npc_plus4, .pc_F1, 
        .npc_plus4_F1, .instr, .instr_F1);
    registerF2D r2 (.clk, .en(~instr_stall), .pc_F1, .npc_plus4_F1, .pc_F1F2, 
        .npc_plus4_F1F2, .instr_F1, .instr_F1F2);

    decode decodeStage (.clk, .rst_l, .halted, .instr_stall, .instr(instr), 
        .pc(pc_F1F2), .rs1_data, 
        .rs2_data, .se_immediate, .npc_jal, .rd_data, .rs1, .rs2, 
        .ctrl_signals, .timeToWrite, .rdToWrite);

    logic [31:0] instrToProp;
    logic instr_stall_del;
    assign instrToProp = (instr_stall) ? 32'd0: instr;
    always_ff @(posedge clk) begin
        instr_stall_del <= instr_stall;
    end

    registerDE r3 (.clk, .en(1'b1), .pc_F1F2, .npc_plus4_F1F2, 
        .instr_F1F2(instrToProp), .rs1_data, .rs2_data, .se_immediate, 
        .npc_jal, .ctrl_signals, .pc_F1F2D, .npc_plus4_F1F2D, .instr_F2D, 
        .rs1_data_D, .rs2_data_D, .se_immediate_D, .npc_jal_D, 
        .ctrl_signals_D, .rs1, .rs1_D);


    execute executeStage (.clk, .rst_l, .rs2_data(rs2_data_D), 
        .se_immediate(se_immediate_D), .rs1_data(rs1_data_D), 
        .instr(instr_F2D), .ctrl_signals(ctrl_signals_D), .alu_out,  
        .data_load);
    
    registerEM1 r4 (.clk, .en(1'b1), .pc_F1F2D, .npc_plus4_F1F2D, 
        .instr_F2D(instr_F2D), .rs1_data_D, .rs2_data_D, .npc_jal_D, 
        .alu_out, .data_load_temp, .ctrl_signals_D, .pc_F1F2DE, 
        .npc_plus4_F1F2DE, .instr_F2DE, .rs1_data_DE, .rs2_data_DE, 
        .npc_jal_DE, .alu_out_E, .data_load_temp_E, .ctrl_signals_DE, .rs1_D, 
        .rs1_DE);

    mem memStage (.clk, .rst_l, .instr(instr_F2DE), .rs1_data(rs1_data_DE), 
        .rs2_data(rs2_data_DE), .alu_out(alu_out_E), 
        .ctrl_signals(ctrl_signals_DE), .data_store, .data_store_mask, 
        .bcond, .data_load_en, .npc_offset, .pc(pc_F1F2D), .boffset, 
        .data_addr);
    
    registerM1M2 r5 (.clk, .en(1'b1), .npc_plus4_F1F2DE, .instr_F2DE, 
        .alu_out_E, .data_load_temp_E, .ctrl_signals_DE, .npc_plus4_F1F2DEM1, 
        .instr_F2DEM1, .alu_out_EM1, .data_load_temp_EM1, .ctrl_signals_DEM1, 
        .rs1_data_DE, .rs1_data_DEM1, .rs1_DE, .rs1_DEM1);

    registerM2W r6 (.clk, .en(1'b1), .npc_plus4_F1F2DEM1, .instr_F2DEM1, 
        .alu_out_EM1, .data_load_temp_EM1, .ctrl_signals_DEM1, 
        .npc_plus4_F1F2DEM1M2, .instr_F2DEM1M2, .alu_out_EM1M2, 
        .data_load_temp_EM1M2, .ctrl_signals_DEM1M2, .rs1_data_DEM1, 
        .rs1_data_DEM1M2, .rs1_DEM1, .rs1_DEM1M2);

    writeback writebackStage (.clk, .rst_l, 
        .ctrl_signals(ctrl_signals_DEM1M2),
        .npc_plus4(npc_plus4_F1F2DEM1M2), .alu_out(alu_out_EM1M2), 
        .instr(instr_F2DEM1M2), .rd_data, .timeToWrite, .rdToWrite, 
        .rs1(rs1_DEM1M2), .rs1_data(rs1_data_DEM1M2), .syscall_halt, 
        .data_load);

    /* STALLING LOGIC */
    always_comb begin
        instr_stall = 1'b0;  // Default: No stall

        // RAW Hazard: Instruction in EX, MEM1, or MEM2 writes to a register that ID is reading
        if  (ctrl_signals_D.rfWrite &&  // EX stage writes to a register
            (instr_F2D[11:7] != 0) &&  // Destination register is not x0
            ((rs1 == instr_F2D[11:7]) ||  // ID needs EX's result in rs1
            (rs2 == instr_F2D[11:7] && !ctrl_signals.useImm))) // ID needs rs2 (except immediate instructions)
        begin
            instr_stall = 1'b1;  // Stall pipeline
        end

        // RAW Hazard: Instruction in MEM1 writes to a register that ID is reading
        else if (ctrl_signals_DE.rfWrite &&  // MEM1 stage writes to a register
                (instr_F2DE[11:7] != 0) &&  // Destination register is not x0
                ((rs1 == instr_F2DE[11:7]) ||  
                (rs2 == instr_F2DE[11:7] && !ctrl_signals.useImm)))
        begin
            instr_stall = 1'b1;
        end

        // RAW Hazard: Instruction in MEM2 writes to a register that ID is reading
        else if (ctrl_signals_DEM1.rfWrite &&  // MEM2 stage writes to a register
                (instr_F2DEM1[11:7] != 0) &&  // Destination register is not x0
                ((rs1 == instr_F2DEM1[11:7]) ||  
                (rs2 == instr_F2DEM1[11:7] && !ctrl_signals.useImm)))
        begin
            instr_stall = 1'b1;  
        end

        else if (ctrl_signals_DEM1M2.rfWrite &&  // MEM2 stage writes to a register
                (instr_F2DEM1M2[11:7] != 0) &&  // Destination register is not x0
                ((rs1 == instr_F2DEM1M2[11:7]) ||  
                (rs2 == instr_F2DEM1M2[11:7] && !ctrl_signals.useImm)))
        begin
            instr_stall = 1'b1;  
        end

        else if (ctrl_signals.syscall && (
                (ctrl_signals_DE.rfWrite && instr_F2DE[11:7] == 5'd10) ||
                (ctrl_signals_DEM1.rfWrite && instr_F2DEM1[11:7] == 5'd10) ||
                (ctrl_signals_DEM1M2.rfWrite && instr_F2DEM1M2[11:7] == 5'd10)
        )) begin
            instr_stall = 1'b1;
        end
    
        // **Fix Load-Store Hazard**: Stall if `SW` needs a value that is still in WB
        else if (opcode_t'(instr_F2D[6:0]) == OP_STORE && ( // Only stall `SW`
            (ctrl_signals_DE.rfWrite && instr_F2DE[11:7] == rs2) ||  // EX stage writes to rs2
            (ctrl_signals_DEM1.rfWrite && instr_F2DEM1[11:7] == rs2) || // MEM1 stage writes to rs2
            (ctrl_signals_DEM1M2.rfWrite && instr_F2DEM1M2[11:7] == rs2))) // MEM2 stage writes to rs2
        begin
            instr_stall = 1'b1;
        end
    end

/* 
`ifdef SIMULATION_18447
    initial begin
        $display("\n\n=========================================================================");
        $display("\n\n=========================================================================");
        $display("\n\n=========================================================================");
        $display("\n\n=========================================================================\n\n");
        $display("Error: The register file is not yet hooked up.");
        $display("The register file must be hooked up before any programs can be simulated.");
        $display("Find and remove the initial block with this warning when you are ready to go.");
        $display("\n\n=========================================================================\n\n");
        $display("=========================================================================\n\n");
        $display("=========================================================================\n\n");
        $display("=========================================================================\n\n");
        $fatal;
    end
`endif*/

    logic [31:0]         mult_out;   // assign mult_out = rs1_data * rs2_data ;                                                           
    // set first parameter to 0 for combinatonal; to 1 for pipelined.                                    
    // mult #(0, 32) multiplier (.A(rs1_data), .B(rs2_data), .O(mult_out), 
    // .CLK(clk));

    assign data_stall       = 1'b0;
    
    // handles exceptions
    assign exception_halt   = instr_mem_excpt | data_mem_excpt | 
        ctrl_signals.illegal_instr;

    assign halted = (rst_l & (syscall_halt | exception_halt));

`ifdef SIMULATION_18447
    always_ff @(posedge clk) begin
        if (rst_l && instr_mem_excpt) begin
            $display("Instruction memory exception at address 0x%08x.", 
                instr_addr << 2);
        end
        if (rst_l && data_mem_excpt) begin
            $display("Data memory exception at address 0x%08x.", 
                data_addr << 2);
        end
        if (rst_l && syscall_halt) begin
            $display("ECALL invoked with halt argument. Terminating simulation at 0x%08x.", 
                pc);
        end
    end
`endif /* SIMULATION_18447 */

    /* When the design is compiled for simulation, the Makefile defines
     * SIMULATION_18447. You can use this to have code that is there for
     * simulation, but is discarded when the design is synthesized. Useful
     * for constructs that can't be synthesized. */
`ifdef SIMULATION_18447
`ifdef TRACE

    opcode_t opcode;
    funct7_t funct7;
    rtype_funct3_t rtype_funct3;
    itype_int_funct3_t itype_int_funct3;
    assign opcode           = opcode_t'(instr[6:0]);
    assign funct7           = funct7_t'(instr[31:25]);
    assign rtype_funct3     = rtype_funct3_t'(instr[14:12]);
    assign itype_int_funct3 = itype_int_funct3_t'(instr[14:12]);

    /* Cycle-by-cycle trace messages. You'll want to comment this out for
     * longer tests, or they will take much, much longer to run. Be sure to
     * comment this out before submitting your code, so tests can be run
     * quickly. */
    /*
    always_ff @(posedge clk) begin
        if (rst_l) begin
            $display({"\n", {80{"-"}}});
            $display("- Simulation Cycle %0d", $time);
            $display({{80{"-"}}, "\n"});

            $display("\tPC: 0x%08x", pc);
            $display("\tInstruction: 0x%08x\n", instr);

            $display("\tInstruction Memory Exception: %0b", instr_mem_excpt);
            $display("\tData Memory Exception: %0b", data_mem_excpt);
            $display("\tIllegal Instruction Exception: %0b", ctrl_signals.illegal_instr);
            $display("\tHalted: %0b\n\n ADDRESS HERE: %h", halted,data_addr);

            $display("\tOpcode: 0x%02x (%s)", opcode, opcode.name);
            $display("\tFunct3: 0x%01x (%s | %s)", rtype_funct3, rtype_funct3.name, itype_int_funct3.name);
            $display("\tFunct7: 0x%02x (%s)", funct7, funct7.name);
            $display("\trs1: %0d", rs1);
            $display("\trs2: %0d", rs2);
            $display("\trd: %0d", rd);
            $display("\tSign Extended Immediate: %0d", se_immediate);

            $display("\tBRANCHING rs1 %d rs2 %d bcond %d mem2rf %h pc2rf %h pc source %h", rs1_data, rs2_data, bcond, ctrl_signals.mem2RF, ctrl_signals.pc2RF, ctrl_signals.pc_source);

            $display("ECALL CHECK: ctrl_signals.syscall=%b, a0_value=%h, syscall_halt=%b use imm %h", 
                 ctrl_signals.syscall, a0_value, syscall_halt, ctrl_signals.useImm);

            $display("Load debug: PC=%h, opcode=%h, memRead=%b, mem2RF=%b, useImm=%b",
             pc, instr[6:0],
             ctrl_signals.memRead,
             ctrl_signals.mem2RF,
             ctrl_signals.useImm);
            $display("data_addr=%h, data_load=%h, data_load_temp=%h, rd_data=%h, rd=%d is it writing %h",
             data_addr, data_load, data_load_temp, rd_data, rd, ctrl_signals.rfWrite);
        end
    end*/

`endif /* TRACE */
`endif /* SIMULATION_18447 */

endmodule: riscv_core

/**
 * The arithmetic-logic unit (ALU) for the RISC-V processor.
 *
 * The ALU handles executing the current instruction, producing the
 * appropriate output based on the ALU operation specified to it by the
 * decoder.
 *
 * Inputs:
 *  - alu_src1      The first operand to the ALU.
 *  - alu_src2      The second operand to the ALU.
 *  - alu_op        The ALU operation to perform.
 * Outputs:
 *  - alu_out       The result of the ALU operation on the two sources.
 **/
module riscv_alu
    (input  logic [31:0]    alu_src1,
     input  logic [31:0]    alu_src2,
     input  alu_op_t alu_op,
     output logic [31:0]    alu_out);

    logic [31:0]    sum;
    adder #($bits(alu_src1)) ALU_Adder(.A(alu_src1), 
                                       .B((alu_op==ALU_SUB)?(~alu_src2):alu_src2), 
                                       .cin(alu_op==ALU_SUB),
                                       .sum, .cout());

    // combinationally perform arithmetic operations
    always_comb begin
        unique case (alu_op)
            ALU_ADD: alu_out = sum;
            ALU_SUB: alu_out = sum;
            ALU_XOR: alu_out = alu_src1 ^ alu_src2;
            ALU_LUI: alu_out = alu_src2;
            ALU_AND: alu_out = alu_src1 & alu_src2;
            ALU_OR: alu_out = alu_src1 | alu_src2;
            ALU_AUIPC: alu_out = alu_src2;
            ALU_SLTU: alu_out = (alu_src1 < alu_src2) ? 1 : 0;
            ALU_SLT: begin
                if (alu_src1[31] == 0 && alu_src2[31] == 1) begin // positive
                    alu_out = 0;
                end 
                else if (alu_src1[31] == 1 && alu_src2[31] == 0) begin // negative
                    alu_out = 1;
                end
                else begin
                    alu_out = (alu_src1 < alu_src2) ? 1 : 0;
                end
            end
            ALU_SLL: alu_out = alu_src1 << (alu_src2 & 32'h1F);
            ALU_SRL: alu_out = alu_src1 >> (alu_src2 & 32'h1F);
            ALU_SRA: alu_out = $signed(alu_src1) >>> (alu_src2 & 32'h1F);
            default: alu_out = 'bx;
        endcase
    end
    
endmodule: riscv_alu

/* Fetch Stage: instr_addr is combinationally computed in order to put on the 
instr memory input which will have a 2 cycle delay until the instr is 
ready. npc_plus4 and pc are computed combinationally- they will be placed in
2 sequential registers to have a 2 cycle delay as well */
module IF
    (input logic clk, rst_l, halted, bcond, instr_stall,
    input logic [31:0] alu_out, npc_jal, boffset,
    output logic [31:0] npc_plus4, pc,
    output logic [29:0] instr_addr);

    import MemorySegments::USER_TEXT_START;

    logic [31:0] next_pc;

    // Instantiate a register to hold the current pc
    always_ff @(posedge clk, negedge rst_l) begin
        if (!rst_l) begin
            pc <= USER_TEXT_START; // Reset PC to the start address
            instr_addr <= USER_TEXT_START[31:2];
        end else if (!halted && !instr_stall) begin
            pc <= next_pc; // Normal PC update (stall prevents update)
            instr_addr <= next_pc[31:2];
        end
    end

    // Compute next PC: Default is sequential execution (pc + 4)
    adder #($bits(pc)) Next_PC_Adder(.A(pc), .B('d4), .cin(1'b0), 
        .sum(npc_plus4), .cout());

    // Default next PC assignment
    assign next_pc = npc_plus4;

endmodule: IF

/* Decode the current instruction and handle register writeback (these can 
happen simultaneously) */
module decode 
    (input logic clk, rst_l, halted, timeToWrite, instr_stall,
    input logic [4:0] rdToWrite,
    input logic [31:0] instr, pc, rd_data,
    output logic [31:0] rs1_data, rs2_data, se_immediate, npc_jal,
    output logic [4:0] rs1, rs2, 
    output ctrl_signals_t  ctrl_signals);

    riscv_decode Decoder(.rst_l, .stall(instr_stall), .instr, .ctrl_signals);

    logic [4:0]     rd;
    assign  rs1             = (ctrl_signals.syscall)? 5'd10: instr[19:15];
    assign  rs2             = instr[24:20];
    assign  rd              = instr[11:7];

    // instantiate the register file
    register_file rf_file
    (.clk(clk), .rst_l(rst_l), .halted(halted), .rd_we(timeToWrite), 
    .rs1(rs1), .rs2(rs2), .rd(rdToWrite), .rd_data(rd_data), 
    .rs1_data(rs1_data), .rs2_data(rs2_data));

    // se_immediate generation
    always_comb begin
        case(ctrl_signals.imm_mode) 
            IMM_I: se_immediate = {{21{instr[31]}}, instr[30:20]};
            IMM_S: se_immediate = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_SB: se_immediate = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_U: begin
                if (ctrl_signals.alu_op == ALU_LUI) begin
                    se_immediate = 32'hFFFFF000 & instr;
                end
                else begin
                    se_immediate = (32'hFFFFF000 & instr) + pc;
                end
            end
            IMM_UJ: se_immediate = {{12{instr[31]}}, instr[19:12], instr[20], 
                instr[30:21], 1'b0};
            default: begin
                se_immediate = {{21{instr[31]}}, instr[30:20]};
            end
        endcase
    end

    // not important for lab2:
    adder #($bits(pc)) jalAdder(.A(pc), 
                                .B(se_immediate), 
                                .cin(1'b0),
                                .sum(npc_jal), .cout());

endmodule: decode

/* Handles calculations via the alu */
module execute
    (input logic clk, rst_l,
    input logic [31:0] rs2_data, se_immediate, rs1_data, instr, data_load,
    input ctrl_signals_t  ctrl_signals,
    output logic [31:0] alu_out);

    import RISCV_ISA::*;

    logic [31:0] alu_src2;

    /* if our instruction uses an immediate, then alu_src2 must be set to 
    se_immediate, but otherwise is rs2_data */
    assign alu_src2 = (!ctrl_signals.useImm) ? rs2_data : se_immediate;

    riscv_alu ALU(.alu_src1(rs1_data), .alu_src2(alu_src2), 
        .alu_op(alu_op_t'(ctrl_signals.alu_op)), .alu_out(alu_out));

endmodule: execute

/* handles memory stores and loads */
module mem
    (input logic clk, rst_l,
    input logic [31:0] instr, rs1_data, rs2_data, alu_out, pc,
    input ctrl_signals_t  ctrl_signals,
    output logic bcond, data_load_en,
    output logic [31:0] npc_offset, boffset, data_store,
    output logic [29:0] data_addr,
    output logic [3:0] data_store_mask);

    import RISCV_ISA::*;

    assign boffset = {{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};

    adder #($bits(pc)) Offset_PC_Adder(.A(pc), .B(boffset), .cin(1'b0),
            .sum(npc_offset), .cout());

    // bcond generation
    always_comb begin
        if (opcode_t'(instr[6:0]) == OP_BRANCH) begin
            case(ctrl_signals.btype)
                FUNCT3_BEQ: bcond = (alu_out==0);
                FUNCT3_BNE: bcond = ($signed(rs1_data) != $signed(rs2_data));
                FUNCT3_BLT: bcond = ($signed(rs1_data) < $signed(rs2_data));
                FUNCT3_BGE: bcond = ($signed(rs1_data) >= $signed(rs2_data));
                FUNCT3_BLTU: bcond = rs1_data < rs2_data;
                FUNCT3_BGEU: bcond = rs1_data >= rs2_data;
                default: bcond = (alu_out==0);
            endcase
        end
        else bcond = (alu_out==0);
    end 

    
    assign data_addr        = alu_out[31:2];
    assign data_load_en     = ctrl_signals.memRead;

    // data_store and data_store_mask generation
    always_comb begin
        if (opcode_t'(instr[6:0]) == OP_STORE) begin
            unique case (ctrl_signals.ldst_mode)
                LDST_W: begin // if you are storing a full word
                    data_store = rs2_data;
                    data_store_mask = 4'b1111;
                end
                LDST_H: begin // if you are only storing a half word
                    unique case (alu_out[1])
                        1'b0: begin // store second half of the word
                            data_store = {16'd0, rs2_data[15:0]};
                            data_store_mask = 4'b0011;
                        end
                        1'b1: begin // store front half of the word
                            data_store = {rs2_data[15:0], 16'd0};
                            data_store_mask = 4'b1100;
                        end
                        default: begin // no inferred latching
                            data_store = rs2_data;
                            data_store_mask = 4'b1111;
                        end
                    endcase
                end
                LDST_B: begin // if you are only storing a byte
                    unique case (alu_out[1:0])
                        2'b00: begin // store last 8 bits
                            data_store = {24'd0, rs2_data[7:0]};
                            data_store_mask = 4'b0001;
                        end
                        2'b01: begin // store second to last 8 bits
                            data_store = {16'd0, rs2_data[7:0], 8'd0};
                            data_store_mask = 4'b0010;
                        end
                        2'b10: begin // store second byte
                            data_store = {8'd0, rs2_data[7:0], 16'd0};
                            data_store_mask = 4'b0100;
                        end
                        2'b11: begin // store first 8 bits
                            data_store = {rs2_data[7:0], 24'd0};
                            data_store_mask = 4'b1000;
                        end
                        default: begin // no inferred latching
                            data_store = rs2_data;
                            data_store_mask = 4'b1111;
                        end
                    endcase
                end
                default: begin // no inferred latching
                    data_store_mask = 4'b0;
                    data_store = 32'd0;
                end
            endcase
        end
        else begin // to avoid inferred latches
            data_store_mask = 4'b0;
            data_store = 32'd0;
        end
    end

endmodule: mem

// handles writebacks to the register file
module writeback
    (input logic clk, rst_l, 
    input ctrl_signals_t  ctrl_signals,
    input logic [31:0] npc_plus4, alu_out, instr, rs1_data, data_load,
    input logic [4:0] rs1,
    output logic [31:0] rd_data,
    output logic timeToWrite, 
    output logic [4:0] rdToWrite,
    output logic syscall_halt);

    import RISCV_ISA::*;
    import RISCV_ABI::ECALL_ARG_HALT;

    logic [31:0] data_load_temp;

    assign timeToWrite = ctrl_signals.rfWrite;
    assign  rdToWrite              = instr[11:7];

        // data_load is available in this stage, so determines which 
        //subsection of data_load needs to be written back to the register 
        //file if a load operation
        always_comb begin
        unique case (opcode_t'(instr[6:0]))
            OP_LOAD: begin // data_load_temp only matters if is a load
                unique case (ctrl_signals.ldst_mode)
                    LDST_W: begin // load full word
                        data_load_temp = data_load;
                    end
                    LDST_H: begin //load half word (determined by alu_out)
                        if (alu_out[1] == 1'b0)
                            data_load_temp = 
                                {{16{data_load[15]}}, data_load[15:0]};
                        else 
                            data_load_temp = 
                                {{16{data_load[31]}}, data_load[31:16]};
                    end
                    LDST_HU: begin // load half word (unsigned)
                        if (alu_out[1] == 1'b0)
                            data_load_temp = {16'd0, data_load[15:0]};
                        else 
                            data_load_temp = {16'd0, data_load[31:16]};
                    end
                    LDST_B: begin //load byte (which is determined by alu_out)
                        if (alu_out[1:0] == 2'd0)
                            data_load_temp = 
                                {{24{data_load[7]}}, data_load[7:0]};
                        else if (alu_out[1:0] == 2'd1)
                            data_load_temp = 
                                {{24{data_load[15]}}, data_load[15:8]};
                        else if (alu_out[1:0] == 2'd2)
                            data_load_temp = 
                                {{24{data_load[23]}}, data_load[23:16]};
                        else if (alu_out[1:0] == 2'd3)
                            data_load_temp = 
                                {{24{data_load[31]}}, data_load[31:24]};
                    end
                    LDST_BU: begin // load byte (unsigned)
                        if (alu_out[1:0] == 2'd0)
                            data_load_temp = {24'd0, data_load[7:0]};
                        else if (alu_out[1:0] == 2'd1)
                            data_load_temp = {24'd0, data_load[15:8]};
                        else if (alu_out[1:0] == 2'd2)
                            data_load_temp = {24'd0, data_load[23:16]};
                        else if (alu_out[1:0] == 2'd3)
                            data_load_temp = {24'd0, data_load[31:24]};
                    end
                    default: data_load_temp = data_load;
                endcase
            end
            default: data_load_temp = 32'd0;
        endcase
    end

    // based on the type of insturction assign rd_data accordingly
    always_comb begin
        case ({ctrl_signals.mem2RF, ctrl_signals.pc2RF}) 
            2'b10: rd_data = data_load_temp; // loads
            2'b01: begin
                if (opcode_t'(instr[6:0]) == OP_JAL | 
                    opcode_t'(instr[6:0]) == OP_JALR) // jumps
                    rd_data = npc_plus4;
                else
                    rd_data = alu_out;
            end
            default: rd_data = alu_out;
        endcase
    end

    logic [31:0] a0_value;
    assign a0_value = (rs1 == 5'd10) ? rs1_data: 32'd0;
    assign syscall_halt = ctrl_signals.syscall && a0_value == ECALL_ARG_HALT;

endmodule: writeback
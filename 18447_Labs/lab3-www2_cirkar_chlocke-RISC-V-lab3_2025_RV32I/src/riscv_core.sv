
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

    /* Bracnhing Strategy For Each Prediction Scheme
        2'd0 = predict always not taken
        2'd1 = 1-bit counter (Branch History State Machine)
        2'd2 = 2 bit hysterisis
    */

    logic [1:0] predScheme;
    assign predScheme = 2'd2;

    // Manage the value of the PC, don't increment if the processor is halted
    logic [31:0]    pc, npc_plus4, npc_offset, next_pc, npc_jal;
    logic [31:0]    boffset;
    logic 	    bcond;

    // Execute the instruction, performing the needed ALU operation
    logic [31:0]    alu_out;
    logic [31:0]    se_immediate, alu_src2, se_immediate_D;
    logic [4:0]     rs1, rs2, rdToWrite, rs1_D, rs1_DE, rs1_DEM1, rs1_DEM1M2;

    /* Declare variables (as logic propagates through the pipeline, the 
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
    ctrl_signals_t  ctrl_signals, ctrl_signalsToProp;

    // Cycle counter logic
    logic [31:0] cycle_counter, num_instr_exec, num_stall_instr_ID;
    logic [31:0] alu_src1_forwarded;
    logic [31:0] instr_stall_1, instr_stall_2, instr_stall_3, instr_stall_4;
    logic prev_instr_stalled;
    logic [2:00] numStalls;
    logic [2:0] prevNumStalls;
    logic [1:0] forwardA, forwardB; // forwarding control signals

    // lab 3 additional instantiations
    logic needToFlush, flushInstr, flushInstr2;
    logic flushInstr_F1, flushInstr_F1F2, flushInstr2_F2;
    logic bTaken, bTaken_F1, bTaken_F1F2, bTaken_F1F2D;
    logic [31:0] pc_indirect, rs2_data_out,next_pc_F1;
    logic [31:0] next_pc_F1F2, next_pc_F1F2D;
    logic forwardLoadA, forwardLoadB;
    logic [61:0] sramReadData, sramReadData_F1, sramReadData_F1F2;
    logic [61:0] sramReadData_F1F2D, updatedSramReadData;
    logic sramWE, bShouldBeTaken;
    logic lastInstrStall, flushed;
    logic [31:0] instrToProp;
    logic instr_stall_del, flushed_D, flushed_DE, flushed_DEM1, flushed_DEM1M2;
    logic [1:0] forwardStore;


    // Performance Counter
    // Basic performance counters
    logic [31:0] num_instrs_fetched;       // Total instructions fetched (including wrong path)
    logic [31:0] num_raw_stall_cycles;     // Total RAW stall cycles

    // Instruction type counters
    logic [31:0] num_alu_instrs;           // ALU instructions executed
    logic [31:0] num_load_instrs;          // Load instructions executed
    logic [31:0] num_store_instrs;         // Store instructions executed

    // Branch instruction counters (16 combinations)
    // Format: forward/backward × taken/not-taken × BTB hit/miss × rewind required/not required
    logic [31:0] num_br_fwd_t_hit_rewind;
    logic [31:0] num_br_fwd_t_hit_norewind;
    logic [31:0] num_br_fwd_t_miss_rewind;
    logic [31:0] num_br_fwd_t_miss_norewind;
    logic [31:0] num_br_fwd_nt_hit_rewind;
    logic [31:0] num_br_fwd_nt_hit_norewind;
    logic [31:0] num_br_fwd_nt_miss_rewind;
    logic [31:0] num_br_fwd_nt_miss_norewind;
    logic [31:0] num_br_bwd_t_hit_rewind;
    logic [31:0] num_br_bwd_t_hit_norewind;
    logic [31:0] num_br_bwd_t_miss_rewind;
    logic [31:0] num_br_bwd_t_miss_norewind;
    logic [31:0] num_br_bwd_nt_hit_rewind;
    logic [31:0] num_br_bwd_nt_hit_norewind;
    logic [31:0] num_br_bwd_nt_miss_rewind;
    logic [31:0] num_br_bwd_nt_miss_norewind;

    // JAL instruction counters (8 combinations)
    // Format: rd=x1/rd!=x1 × BTB hit/miss × rewind required/not required
    logic [31:0] num_jal_x1_hit_rewind;
    logic [31:0] num_jal_x1_hit_norewind;
    logic [31:0] num_jal_x1_miss_rewind;
    logic [31:0] num_jal_x1_miss_norewind;
    logic [31:0] num_jal_nx1_hit_rewind;
    logic [31:0] num_jal_nx1_hit_norewind;
    logic [31:0] num_jal_nx1_miss_rewind;
    logic [31:0] num_jal_nx1_miss_norewind;

    // JALR instruction counters (8 combinations)
    // Format: rs1=x1/rs1!=x1 × BTB hit/miss × rewind required/not required
    logic [31:0] num_jalr_x1_hit_rewind;
    logic [31:0] num_jalr_x1_hit_norewind;
    logic [31:0] num_jalr_x1_miss_rewind;
    logic [31:0] num_jalr_x1_miss_norewind;
    logic [31:0] num_jalr_nx1_hit_rewind;
    logic [31:0] num_jalr_nx1_hit_norewind;
    logic [31:0] num_jalr_nx1_miss_rewind;
    logic [31:0] num_jalr_nx1_miss_norewind;

    // Temporary signals to help track events for counters
    logic branch_is_forward, branch_is_forward_out;     // Is branch offset forward?
    logic branch_is_taken;                              // Is branch taken?
    logic btb_hit;                                      // Did BTB predict correctly?
    logic rewind_required;                              // Was rewind required?
    logic is_branch_instruction;                        // Is this a branch instruction?
    logic is_jal_instruction;                           // Is this a JAL instruction?
    logic is_jalr_instruction;                          // Is this a JALR instruction?
    logic jal_rd_is_x1;                                 // Is JAL rd = x1?
    logic jalr_rs1_is_x1;                               // Is JALR rs1 = x1?
    logic is_alu_instruction;                           // Is this an ALU instruction?
    logic is_load_instruction;                          // Is this a load instruction?
    logic is_store_instruction;                         // Is this a store instruction?
    
    // Initialize all the counters in the reset block
    always_ff @(posedge clk, negedge rst_l) begin
        if (~rst_l) begin
            // Existing resets
            cycle_counter <= 32'd1;
            prev_instr_stalled <= 1'b0;
            num_stall_instr_ID <= 32'd0;
            numStalls <= 3'd0;
            prevNumStalls <= 3'd0;
            instr_stall_1 <= 32'd0;
            instr_stall_2 <= 32'd0;
            instr_stall_3 <= 32'd1;
            instr_stall_4 <= 32'd0;
            num_instr_exec <= 32'd0;
            
            // Basic performance counters
            num_instrs_fetched <= 32'd0;
            num_raw_stall_cycles <= 32'd0;
            
            // Instruction type counters
            num_alu_instrs <= 32'd0;
            num_load_instrs <= 32'd0;
            num_store_instrs <= 32'd0;
            
            // Branch instruction counters
            num_br_fwd_t_hit_rewind <= 32'd0;
            num_br_fwd_t_hit_norewind <= 32'd0;
            num_br_fwd_t_miss_rewind <= 32'd0;
            num_br_fwd_t_miss_norewind <= 32'd0;
            num_br_fwd_nt_hit_rewind <= 32'd0;
            num_br_fwd_nt_hit_norewind <= 32'd0;
            num_br_fwd_nt_miss_rewind <= 32'd0;
            num_br_fwd_nt_miss_norewind <= 32'd0;
            num_br_bwd_t_hit_rewind <= 32'd0;
            num_br_bwd_t_hit_norewind <= 32'd0;
            num_br_bwd_t_miss_rewind <= 32'd0;
            num_br_bwd_t_miss_norewind <= 32'd0;
            num_br_bwd_nt_hit_rewind <= 32'd0;
            num_br_bwd_nt_hit_norewind <= 32'd0;
            num_br_bwd_nt_miss_rewind <= 32'd0;
            num_br_bwd_nt_miss_norewind <= 32'd0;
            
            // JAL instruction counters
            num_jal_x1_hit_rewind <= 32'd0;
            num_jal_x1_hit_norewind <= 32'd0;
            num_jal_x1_miss_rewind <= 32'd0;
            num_jal_x1_miss_norewind <= 32'd0;
            num_jal_nx1_hit_rewind <= 32'd0;
            num_jal_nx1_hit_norewind <= 32'd0;
            num_jal_nx1_miss_rewind <= 32'd0;
            num_jal_nx1_miss_norewind <= 32'd0;
            
            // JALR instruction counters
            num_jalr_x1_hit_rewind <= 32'd0;
            num_jalr_x1_hit_norewind <= 32'd0;
            num_jalr_x1_miss_rewind <= 32'd0;
            num_jalr_x1_miss_norewind <= 32'd0;
            num_jalr_nx1_hit_rewind <= 32'd0;
            num_jalr_nx1_hit_norewind <= 32'd0;
            num_jalr_nx1_miss_rewind <= 32'd0;
            num_jalr_nx1_miss_norewind <= 32'd0;
        end
        else begin
            // Existing updates - maintain your standard counter logic
            cycle_counter <= cycle_counter + 32'd1;
            prev_instr_stalled <= instr_stall;
            if (~prev_instr_stalled && instr_stall) 
                num_stall_instr_ID <= num_stall_instr_ID + 32'd1;
            if (instr_stall) numStalls <= numStalls + 3'd1;
            else numStalls <= 3'd0;
            prevNumStalls <= numStalls;
            if (prev_instr_stalled & ~instr_stall) begin
                if (prevNumStalls == 3'd1) 
                    instr_stall_1 <= instr_stall_1 + 32'd1;
                else if (prevNumStalls == 3'd2) 
                    instr_stall_2 <= instr_stall_2 + 32'd1;
                else if (prevNumStalls == 3'd3) 
                    instr_stall_3 <= instr_stall_3 + 32'd1;
                else if (prevNumStalls == 3'd4) 
                    instr_stall_4 <= instr_stall_4 + 32'd1;
            end
            
            // Count instructions executed
            if (~instr_stall & ~halted & (instr != 'h00000013) & 
                (instr != 'hdededede) & (~flushed_D)) 
                num_instr_exec <= num_instr_exec + 32'd1;
            
            // Count instructions fetched (not double counting stalls)
            if (~instr_stall & ~halted & (instr != 'hdededede)) 
                num_instrs_fetched <= num_instrs_fetched + 32'd1;
            
            // Count RAW stalls, using IMM flgas
            if (instr_stall) begin
                if (ctrl_signals_DE.memRead && 
                    ((rs1 == instr_F2DE[11:7] && instr_F2DE[11:7] != 0) || 
                    (rs2 == instr_F2DE[11:7] && instr_F2DE[11:7] != 0 && 
                    !ctrl_signals.useImm)))
                begin
                    num_raw_stall_cycles <= num_raw_stall_cycles + 32'd1;
                end
            end
            
            // To track instruction types - only in Execute stage and only when not flushed
            if (~halted & (flushed_D !== 1'd1)) begin
                // Instruction Type Detection
                is_alu_instruction = (ctrl_signals_D.rfWrite && 
                    !ctrl_signals_D.memRead && !ctrl_signals_D.memWrite && 
                    !ctrl_signals_D.pc2RF && (instr_F2D[6:0] == 7'b0110011 || 
                    instr_F2D[6:0] == 7'b0010011));
                is_load_instruction = ctrl_signals_D.memRead;
                is_store_instruction = ctrl_signals_D.memWrite;
                
                if (is_alu_instruction) 
                    num_alu_instrs <= num_alu_instrs + 32'd1;
                if (is_load_instruction) 
                    num_load_instrs <= num_load_instrs + 32'd1;
                if (is_store_instruction) 
                    num_store_instrs <= num_store_instrs + 32'd1;
                
                // Branch and jump tracking
                // FIX: Clear distinction between branch, JAL, and JALR instructions
                is_branch_instruction = (ctrl_signals_D.pc_source == PC_cond && 
                    instr_F2D[6:0] == 7'b1100011);
                is_jal_instruction = (ctrl_signals_D.pc_source == PC_uncond && 
                    instr_F2D[6:0] == 7'b1101111);
                is_jalr_instruction = (ctrl_signals_D.pc_source == PC_indirect 
                    && instr_F2D[6:0] == 7'b1100111);
                
                // Branch instruction tracking
                if (is_branch_instruction) begin
                    // Backward/forward branch detection
                    branch_is_forward = branch_is_forward_out; // Not the sign bit (1 = negative = backward)
                    branch_is_taken = bcond;
                    btb_hit = (bTaken_F1F2D == branch_is_taken);
                    rewind_required = needToFlush;
                    
                    // Increment the appropriate branch counter based on the 4 conditions
                    if (branch_is_forward && branch_is_taken && btb_hit && rewind_required)
                        num_br_fwd_t_hit_rewind <= num_br_fwd_t_hit_rewind + 32'd1;
                    else if (branch_is_forward && branch_is_taken && btb_hit && !rewind_required)
                        num_br_fwd_t_hit_norewind <= num_br_fwd_t_hit_norewind + 32'd1;
                    else if (branch_is_forward && branch_is_taken && !btb_hit && rewind_required)
                        num_br_fwd_t_miss_rewind <= num_br_fwd_t_miss_rewind + 32'd1;
                    else if (branch_is_forward && branch_is_taken && !btb_hit && !rewind_required)
                        num_br_fwd_t_miss_norewind <= num_br_fwd_t_miss_norewind + 32'd1;
                    else if (branch_is_forward && !branch_is_taken && btb_hit && rewind_required)
                        num_br_fwd_nt_hit_rewind <= num_br_fwd_nt_hit_rewind + 32'd1;
                    else if (branch_is_forward && !branch_is_taken && btb_hit && !rewind_required)
                        num_br_fwd_nt_hit_norewind <= num_br_fwd_nt_hit_norewind + 32'd1;
                    else if (branch_is_forward && !branch_is_taken && !btb_hit && rewind_required)
                        num_br_fwd_nt_miss_rewind <= num_br_fwd_nt_miss_rewind + 32'd1;
                    else if (branch_is_forward && !branch_is_taken && !btb_hit && !rewind_required)
                        num_br_fwd_nt_miss_norewind <= num_br_fwd_nt_miss_norewind + 32'd1;
                    else if (!branch_is_forward && branch_is_taken && btb_hit && rewind_required)
                        num_br_bwd_t_hit_rewind <= num_br_bwd_t_hit_rewind + 32'd1;
                    else if (!branch_is_forward && branch_is_taken && btb_hit && !rewind_required)
                        num_br_bwd_t_hit_norewind <= num_br_bwd_t_hit_norewind + 32'd1;
                    else if (!branch_is_forward && branch_is_taken && !btb_hit && rewind_required)
                        num_br_bwd_t_miss_rewind <= num_br_bwd_t_miss_rewind + 32'd1;
                    else if (!branch_is_forward && branch_is_taken && !btb_hit && !rewind_required)
                        num_br_bwd_t_miss_norewind <= num_br_bwd_t_miss_norewind + 32'd1;
                    else if (!branch_is_forward && !branch_is_taken && btb_hit && rewind_required)
                        num_br_bwd_nt_hit_rewind <= num_br_bwd_nt_hit_rewind + 32'd1;
                    else if (!branch_is_forward && !branch_is_taken && btb_hit && !rewind_required)
                        num_br_bwd_nt_hit_norewind <= num_br_bwd_nt_hit_norewind + 32'd1;
                    else if (!branch_is_forward && !branch_is_taken && !btb_hit && rewind_required)
                        num_br_bwd_nt_miss_rewind <= num_br_bwd_nt_miss_rewind + 32'd1;
                    else if (!branch_is_forward && !branch_is_taken && !btb_hit && !rewind_required)
                        num_br_bwd_nt_miss_norewind <= num_br_bwd_nt_miss_norewind + 32'd1;
                end
                
                // JAL instructions
                if (is_jal_instruction) begin
                    jal_rd_is_x1 = (instr_F2D[11:7] == 5'd1); // Check if rd = x1
                    // JAL is always taken, so BTB hit means it predicted taken
                    btb_hit = (bTaken_F1F2D == 1'b1);
                    rewind_required = needToFlush;
                    
                    // Increment the appropriate JAL counter
                    if (jal_rd_is_x1 && btb_hit && rewind_required)
                        num_jal_x1_hit_rewind <= num_jal_x1_hit_rewind + 32'd1;
                    else if (jal_rd_is_x1 && btb_hit && !rewind_required)
                        num_jal_x1_hit_norewind <= num_jal_x1_hit_norewind + 32'd1;
                    else if (jal_rd_is_x1 && !btb_hit && rewind_required)
                        num_jal_x1_miss_rewind <= num_jal_x1_miss_rewind + 32'd1;
                    else if (jal_rd_is_x1 && !btb_hit && !rewind_required)
                        num_jal_x1_miss_norewind <= num_jal_x1_miss_norewind + 32'd1;
                    else if (!jal_rd_is_x1 && btb_hit && rewind_required)
                        num_jal_nx1_hit_rewind <= num_jal_nx1_hit_rewind + 32'd1;
                    else if (!jal_rd_is_x1 && btb_hit && !rewind_required)
                        num_jal_nx1_hit_norewind <= num_jal_nx1_hit_norewind + 32'd1;
                    else if (!jal_rd_is_x1 && !btb_hit && rewind_required)
                        num_jal_nx1_miss_rewind <= num_jal_nx1_miss_rewind + 32'd1;
                    else if (!jal_rd_is_x1 && !btb_hit && !rewind_required)
                        num_jal_nx1_miss_norewind <= num_jal_nx1_miss_norewind + 32'd1;
                end
                
                // JALR instructions
                if (is_jalr_instruction) begin
                    jalr_rs1_is_x1 = (instr_F2D[19:15] == 5'd1); // Check if rs1 = x1
                    // JALR is always taken, so BTB hit means it predicted taken
                    btb_hit = (bTaken_F1F2D == 1'b1);
                    rewind_required = needToFlush;
                    
                    // Increment the appropriate JALR counter
                    if (jalr_rs1_is_x1 && btb_hit && rewind_required)
                        num_jalr_x1_hit_rewind <= num_jalr_x1_hit_rewind + 32'd1;
                    else if (jalr_rs1_is_x1 && btb_hit && !rewind_required)
                        num_jalr_x1_hit_norewind <= num_jalr_x1_hit_norewind + 32'd1;
                    else if (jalr_rs1_is_x1 && !btb_hit && rewind_required)
                        num_jalr_x1_miss_rewind <= num_jalr_x1_miss_rewind + 32'd1;
                    else if (jalr_rs1_is_x1 && !btb_hit && !rewind_required)
                        num_jalr_x1_miss_norewind <= num_jalr_x1_miss_norewind + 32'd1;
                    else if (!jalr_rs1_is_x1 && btb_hit && rewind_required)
                        num_jalr_nx1_hit_rewind <= num_jalr_nx1_hit_rewind + 32'd1;
                    else if (!jalr_rs1_is_x1 && btb_hit && !rewind_required)
                        num_jalr_nx1_hit_norewind <= num_jalr_nx1_hit_norewind + 32'd1;
                    else if (!jalr_rs1_is_x1 && !btb_hit && rewind_required)
                        num_jalr_nx1_miss_rewind <= num_jalr_nx1_miss_rewind + 32'd1;
                    else if (!jalr_rs1_is_x1 && !btb_hit && !rewind_required)
                        num_jalr_nx1_miss_norewind <= num_jalr_nx1_miss_norewind + 32'd1;
                end
            end
        end
    end

    // FETCH
    IF fetchStage (
        .clk, 
        .rst_l, 
        .halted,  
        .instr_stall, 
        .alu_out, 
        .npc_jal, 
        .npc_offset, 
        .pc_indirect,
        .npc_plus4, 
        .pc, 
        .instr_addr, 
        .bTaken,
        .needToFlush,
        .ctrl_signals(ctrl_signals_D),
        .bcond,
        .sramReadData,
        .updatedSramReadData,
        .predScheme,
        .sramWE,
        .pcFromEx(pc_F1F2D),
        .bShouldBeTaken,
        .ctrl_signalsInDecode(ctrl_signals),
        .next_pc
    );

    always_comb begin
        if (needToFlush) flushInstr = 1'b1;
        else flushInstr = 1'b0;
    end

    // Pipeline register between FETCH1 and FETCH2
    registerF1F2 r1 (
        .clk, 
        .en(~instr_stall), 
        .pc, 
        .npc_plus4, 
        .pc_F1, 
        .npc_plus4_F1, 
        .instr, 
        .instr_F1,
        .bTaken,
        .bTaken_F1,
        .flushInstr,
        .flushInstr_F1,
        .sramReadData,
        .sramReadData_F1,
        .next_pc,
        .next_pc_F1
    );

    always_comb begin
        if (needToFlush) flushInstr2 = 1'b1;
        else flushInstr2 = 1'b0;
    end

    // Pipeline register between FETCH2 and DECODE
    registerF2D r2 (
        .clk, 
        .en(~instr_stall), 
        .pc_F1, 
        .npc_plus4_F1, 
        .pc_F1F2, 
        .npc_plus4_F1F2, 
        .instr_F1, 
        .instr_F1F2,
        .bTaken_F1,
        .bTaken_F1F2,
        .flushInstr_F1,
        .flushInstr_F1F2,
        .flushInstr2,
        .flushInstr2_F2,
        .sramReadData_F1,
        .sramReadData_F1F2,
        .next_pc_F1,
        .next_pc_F1F2
    );

    always_ff @(posedge clk) begin
        if (~rst_l) lastInstrStall <= 1'b0;
        else lastInstrStall <= instr_stall;
    end

    // DECODE
    decode decodeStage (
        .clk, 
        .rst_l, 
        .halted, 
        .instr_stall, 
        .instr(instr), 
        .pc(pc_F1F2), 
        .rs1_data, 
        .rs2_data, 
        .se_immediate,  
        .rd_data, 
        .rs1, 
        .rs2, 
        .ctrl_signals, 
        .timeToWrite, 
        .rdToWrite,
        .needToFlush,
        .flushInstr(flushInstr_F1F2),
        .flushInstr2(flushInstr2_F2),
        .lastInstrStall,
        .flushed
    );

    assign instrToProp = (instr_stall) ? 32'd0: instr;
    always_comb begin
        if (instr_stall) begin
            ctrl_signalsToProp.useImm = 1'b0;
            ctrl_signalsToProp.rfWrite = 1'b0;
            ctrl_signalsToProp.mem2RF = 1'b0;
            ctrl_signalsToProp.pc2RF = 1'b0;
            ctrl_signalsToProp.memRead = 1'b0;
            ctrl_signalsToProp.memWrite = 1'b0;
            ctrl_signalsToProp.imm_mode = IMM_DC;
            ctrl_signalsToProp.alu_op = ALU_DC;
            ctrl_signalsToProp.ldst_mode = LDST_DC;
            ctrl_signalsToProp.pc_source = PC_DC;
            ctrl_signalsToProp.btype = 3'd0;
            ctrl_signalsToProp.syscall = 1'b0;
            ctrl_signalsToProp.illegal_instr = 1'b0;
        end
        else begin
            ctrl_signalsToProp.useImm = ctrl_signals.useImm;
            ctrl_signalsToProp.rfWrite = ctrl_signals.rfWrite;
            ctrl_signalsToProp.mem2RF = ctrl_signals.mem2RF;
            ctrl_signalsToProp.pc2RF = ctrl_signals.pc2RF;
            ctrl_signalsToProp.memRead = ctrl_signals.memRead;
            ctrl_signalsToProp.memWrite = ctrl_signals.memWrite;
            ctrl_signalsToProp.imm_mode = ctrl_signals.imm_mode;
            ctrl_signalsToProp.alu_op = ctrl_signals.alu_op;
            ctrl_signalsToProp.ldst_mode = ctrl_signals.ldst_mode;
            ctrl_signalsToProp.pc_source = ctrl_signals.pc_source;
            ctrl_signalsToProp.btype = ctrl_signals.btype;
            ctrl_signalsToProp.syscall = ctrl_signals.syscall;
            ctrl_signalsToProp.illegal_instr = ctrl_signals.illegal_instr;
        end
    end

    // Pipeline register between DECODE and EXECUTE
    registerDE r3 (
        .clk, 
        .en(1'b1), 
        .pc_F1F2, 
        .npc_plus4_F1F2, 
        .instr_F1F2(instrToProp), 
        .rs1_data, 
        .rs2_data, 
        .se_immediate,  
        .ctrl_signals(ctrl_signalsToProp), 
        .pc_F1F2D, 
        .npc_plus4_F1F2D, 
        .instr_F2D, 
        .rs1_data_D, 
        .rs2_data_D, 
        .se_immediate_D,  
        .ctrl_signals_D, 
        .rs1, 
        .rs1_D,
        .bTaken_F1F2,
        .bTaken_F1F2D,
        .flushed,
        .flushed_D,
        .sramReadData_F1F2,
        .sramReadData_F1F2D,
        .next_pc_F1F2,
        .next_pc_F1F2D
    );

    // EXECUTE
    execute executeStage(
        .clk(clk), 
        .rst_l(rst_l),
        .rs2_data(rs2_data_D), 
        .se_immediate(se_immediate_D), 
        .rs1_data(rs1_data_D), 
        .instr(instr_F2D), 
        .ctrl_signals(ctrl_signals_D), 
        .forwardA(forwardA), 
        .forwardB(forwardB),  
        .alu_out_E(alu_out_E), 
        .alu_out_EM1(alu_out_EM1), 
        .alu_out_EM1M2(alu_out_EM1M2), 
        .alu_out(alu_out),
        .pc(pc_F1F2D),
        .npc_jal, 
        .npc_offset, 
        .pc_indirect,
        .bTaken(bTaken_F1F2D),
        .needToFlush,
        .bcond,
        .forwardStore,
        .rs2_data_out,
        .forwardLoadA,
        .forwardLoadB,
        .data_load_temp, 
        .rd_data, 
        .alu_src1_forwarded,
        .sramReadData(sramReadData_F1F2D),
        .updatedSramReadData,
        .predScheme,
        .sramWE,
        .branch_is_forward_out,
        .bShouldBeTaken,
        .instr_F2DE,
        .npc_plus4_F1F2DE,
        .instr_F2DEM1,
        .npc_plus4_F1F2DEM1,
        .next_pc_F1F2D
    );
    
    // Pipeline register between EXECUTE and MEMORY1
    registerEM1 r4 (
        .clk, 
        .en(1'b1), 
        .pc_F1F2D, 
        .npc_plus4_F1F2D, 
        .instr_F2D(instr_F2D), 
        .rs1_data_D(alu_src1_forwarded), 
        .rs2_data_D(rs2_data_out),  
        .alu_out, 
        .data_load_temp, 
        .ctrl_signals_D, 
        .pc_F1F2DE, 
        .npc_plus4_F1F2DE, 
        .instr_F2DE, 
        .rs1_data_DE, 
        .rs2_data_DE,  
        .alu_out_E, 
        .data_load_temp_E, 
        .ctrl_signals_DE, 
        .rs1_D, 
        .rs1_DE,
        .flushed_D,
        .flushed_DE
    );

    // MEMORY
    mem memStage (
        .clk, 
        .rst_l, 
        .instr(instr_F2DE), 
        .rs1_data(rs1_data_DE), 
        .rs2_data(rs2_data_DE), 
        .alu_out(alu_out_E), 
        .ctrl_signals(ctrl_signals_DE), 
        .data_store, 
        .data_store_mask,  
        .data_load_en, 
        .pc(pc_F1F2D),  
        .data_addr
    );
    
    // Pipeline register between MEMORY1 and MEMORY2
    registerM1M2 r5 (
        .clk, 
        .en(1'b1), 
        .npc_plus4_F1F2DE, 
        .instr_F2DE, 
        .alu_out_E, 
        .data_load_temp_E, 
        .ctrl_signals_DE, 
        .npc_plus4_F1F2DEM1, 
        .instr_F2DEM1, 
        .alu_out_EM1, 
        .data_load_temp_EM1, .ctrl_signals_DEM1, 
        .rs1_data_DE, .rs1_data_DEM1, .rs1_DE, .rs1_DEM1,
        .flushed_DE,
        .flushed_DEM1
    );

    // Pipeline register between MEMORY2 and WRITEBACK
    registerM2W r6 (
        .clk, 
        .en(1'b1), 
        .npc_plus4_F1F2DEM1, 
        .instr_F2DEM1, 
        .alu_out_EM1, 
        .data_load_temp_EM1, 
        .ctrl_signals_DEM1, 
        .npc_plus4_F1F2DEM1M2, 
        .instr_F2DEM1M2, 
        .alu_out_EM1M2, 
        .data_load_temp_EM1M2, 
        .ctrl_signals_DEM1M2, 
        .rs1_data_DEM1, 
        .rs1_data_DEM1M2, 
        .rs1_DEM1, 
        .rs1_DEM1M2,
        .flushed_DEM1,
        .flushed_DEM1M2
    );

    // WRITEBACK
    writeback writebackStage (
        .clk, 
        .rst_l, 
        .ctrl_signals(ctrl_signals_DEM1M2),
        .npc_plus4(npc_plus4_F1F2DEM1M2), 
        .alu_out(alu_out_EM1M2), 
        .instr(instr_F2DEM1M2), 
        .rd_data, 
        .timeToWrite, 
        .rdToWrite, 
        .rs1(rs1_DEM1M2), 
        .rs1_data(rs1_data_DEM1M2), 
        .syscall_halt, 
        .data_load
    );

    /* FORWARDING LOGIC */
    always_comb begin
        // Default: No forwarding
        forwardA = 2'b00;
        forwardB = 2'b00;

        // EX Hazard: Forward from ALU output (EX to EX)
        if (ctrl_signals_DE.rfWrite && (instr_F2DE[11:7] != 0)) begin
            if (instr_F2DE[11:7] == rs1_D) begin
                forwardA = 2'b10;
            end
            if (instr_F2DE[11:7] == instr_F2D[24:20] && 
                !ctrl_signals_D.useImm) begin
                forwardB = 2'b10;
            end
        end

        
        // Forwarding logic for store instructions
        if (ctrl_signals_D.memWrite & !ctrl_signals_DE.memWrite & 
            (instr_F2DE[11:7] == instr_F2D[24:20]) & (forwardB == 2'd0) & 
            !flushed_DE) begin
            forwardStore = 2'b10;
        end
        else if (ctrl_signals_D.memWrite & !ctrl_signals_DEM1.memWrite & 
            (instr_F2DEM1[11:7] == instr_F2D[24:20]) & (forwardB == 2'd0) & 
            (forwardStore == 2'd0) & !flushed_DEM1) begin
            forwardStore = 2'b01;
        end
        else if (ctrl_signals_D.memWrite & !ctrl_signals_DEM1M2.memWrite & 
            (instr_F2DEM1M2[11:7] == instr_F2D[24:20]) & (forwardB == 2'd0) & 
            (forwardStore == 2'd0) & !flushed_DEM1M2) begin
            forwardStore = 2'b11;
        end
        else forwardStore = 2'd0;

        // MEM1 Hazard: Forward from MEM1 stage (MEM1 to EX)
        if (ctrl_signals_DEM1.rfWrite && (instr_F2DEM1[11:7] != 0)) begin
            if (instr_F2DEM1[11:7] == rs1_D & (forwardA == 2'd0)) begin
                forwardA = 2'b01;
            end
            if (instr_F2DEM1[11:7] == instr_F2D[24:20] && 
                !ctrl_signals_D.useImm & (forwardB == 2'd0)) begin
                forwardB = 2'b01;
            end
        end


        // MEM2 Hazard: Forward from MEM2 stage (MEM2 to EX)- need to 
        // consider lw instr where you might need to forward something other 
        // than the alu_out
        if (ctrl_signals_DEM1M2.rfWrite & (instr_F2DEM1M2[11:7] != 0)) begin
            if (instr_F2DEM1M2[11:7] == rs1_D & (forwardA == 2'd0)) begin 
                forwardA = 2'b11;
            end
            if (instr_F2DEM1M2[11:7] == instr_F2D[24:20] & 
                !ctrl_signals_D.useImm & (forwardB == 2'd0)) begin
                forwardB = 2'b11;
            end
        end


    end

    always_ff @(posedge clk) begin
        $display($time, " INSTR IN DEC: %h INSTR IN MEM: %h rs1 %d rs2 %d rd %d, memRead %b", instr, instr_F2DE, rs1, rs2, instr_F2DE[11:7], ctrl_signals_DE.memRead);
    end

    /* STALLING LOGIC - Load Use Hazard 
       Forwarding does not resolve this dependency */
    always_comb begin
        instr_stall = 1'b0; // Default: No stall

        // Stall if a Load-Use Hazard occurs (Load value not available yet)
        if ((ctrl_signals_DE.memRead) &&  // Load instruction in EX stage
            ((rs1 == instr_F2DE[11:7]/* && forwardA == 2'b00*/) || 
            (rs2 == instr_F2DE[11:7] /*&& forwardB == 2'b00*/))) begin
            instr_stall = 1'b1;
        end
        else if ((ctrl_signals_D.memRead) &&  // Load instruction in EX stage
            ((rs1 == instr_F2D[11:7]/* && forwardA == 2'b00*/) || 
            (rs2 == instr_F2D[11:7] /*&& forwardB == 2'b00*/))) begin
            instr_stall = 1'b1;
        end
        // Stall for Ecall
        else if (ctrl_signals.syscall && (
                (ctrl_signals_D.rfWrite && instr_F2D[11:7] == 5'd10) ||
                (ctrl_signals_DE.rfWrite && instr_F2DE[11:7] == 5'd10) ||
                (ctrl_signals_DEM1.rfWrite && instr_F2DEM1[11:7] == 5'd10) ||
                (ctrl_signals_DEM1M2.rfWrite && instr_F2DEM1M2[11:7] == 5'd10)
        )) begin
            instr_stall = 1'b1;
        end 
        else if (ctrl_signals_D.syscall | ctrl_signals_DE.syscall | 
            ctrl_signals_DEM1.syscall | ctrl_signals_DEM1M2.syscall) begin
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

    assign data_stall       = 1'b0;
    
    // handles exceptions- allows all instructions to finish being written to
    // registers before halting
    assign exception_halt   = instr_mem_excpt | data_mem_excpt | 
        ctrl_signals.illegal_instr;
    logic haltedTemp, haltedTemp2, haltedTemp3;
    assign haltedTemp = (rst_l & (syscall_halt | exception_halt));

    always_ff @(posedge clk, negedge rst_l) begin
        if (~rst_l) begin
            haltedTemp2 <= 'd0;
            haltedTemp3 <= 'd0;
            halted <= 'd0;
        end
        else begin
            haltedTemp2 <= haltedTemp;
            haltedTemp3 <= haltedTemp2;
            if (haltedTemp3 == 'd1)
                halted <= haltedTemp3;
            else 
                halted <= 'd0;
        end
    end


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
    

/* PERFORMANCE STATISTICS REPORTING */
/*
variable declaration section
logic [31:0] total_branch_instr;  // Total number of branch instructions
logic [31:0] correct_branch_pred; // Correctly predicted branches
real branch_pred_accuracy;        // Branch prediction accuracy as a real number

// Then, replace your final block with this corrected version
`ifdef SIMULATION_18447
final begin
    $display("\n\n=========================================================================");
    $display("                      PERFORMANCE STATISTICS                              ");
    $display("=========================================================================");
    
    // Basic performance metrics
    $display("\n1. Basic Performance Metrics:");
    $display("   - Number of cycles elapsed:                  %d", 
        cycle_counter);
    $display("   - Number of RAW stall cycles:                %d", 
        num_raw_stall_cycles);
    $display("   - Number of instructions fetched:            %d", 
        num_instrs_fetched);
    $display("   - Number of instructions executed:           %d", 
        num_instr_exec); // need to account for flushing instruc
    
    // Instruction type breakdown
    $display("\n2. Instruction Type Breakdown:");
    $display("   - Number of ALU instructions executed:      %d", 
        num_alu_instrs);
    $display("   - Number of Load instructions executed:     %d", 
        num_load_instrs);
    $display("   - Number of Store instructions executed:    %d", 
        num_store_instrs);
    
    // Branch instruction statistics
    $display("\n3. Branch Instruction Statistics:");
    $display("   Forward branches, Taken, BTB Hit, Rewind Required:       %d", 
        num_br_fwd_t_hit_rewind);
    $display("   Forward branches, Taken, BTB Hit, No Rewind Required:    %d", 
        num_br_fwd_t_hit_norewind);
    $display("   Forward branches, Taken, BTB Miss, Rewind Required:      %d", 
        num_br_fwd_t_miss_rewind);
    $display("   Forward branches, Taken, BTB Miss, No Rewind Required:   %d", 
        num_br_fwd_t_miss_norewind);
    $display("   Forward branches, Not Taken, BTB Hit, Rewind Required:   %d", 
        num_br_fwd_nt_hit_rewind);
    $display("   Forward branches, Not Taken, BTB Hit, No Rewind Required: %d", 
        num_br_fwd_nt_hit_norewind);
    $display("   Forward branches, Not Taken, BTB Miss, Rewind Required:  %d", 
        num_br_fwd_nt_miss_rewind);
    $display("   Forward branches, Not Taken, BTB Miss, No Rewind Required: %d", 
        num_br_fwd_nt_miss_norewind);
    $display("   Backward branches, Taken, BTB Hit, Rewind Required:      %d", 
        num_br_bwd_t_hit_rewind);
    $display("   Backward branches, Taken, BTB Hit, No Rewind Required:   %d", 
        num_br_bwd_t_hit_norewind);
    $display("   Backward branches, Taken, BTB Miss, Rewind Required:     %d", 
        num_br_bwd_t_miss_rewind);
    $display("   Backward branches, Taken, BTB Miss, No Rewind Required:  %d", 
        num_br_bwd_t_miss_norewind);
    $display("   Backward branches, Not Taken, BTB Hit, Rewind Required:  %d", 
        num_br_bwd_nt_hit_rewind);
    $display("   Backward branches, Not Taken, BTB Hit, No Rewind Required: %d", 
        num_br_bwd_nt_hit_norewind);
    $display("   Backward branches, Not Taken, BTB Miss, Rewind Required: %d", 
        num_br_bwd_nt_miss_rewind);
    $display("   Backward branches, Not Taken, BTB Miss, No Rewind Required: %d", 
        num_br_bwd_nt_miss_norewind);
    
    // JAL instruction statistics
    $display("\n4. JAL Instruction Statistics:");
    $display("   JAL, rd=x1, BTB Hit, Rewind Required:       %d", 
        num_jal_x1_hit_rewind);
    $display("   JAL, rd=x1, BTB Hit, No Rewind Required:    %d", 
        num_jal_x1_hit_norewind);
    $display("   JAL, rd=x1, BTB Miss, Rewind Required:      %d", 
        num_jal_x1_miss_rewind);
    $display("   JAL, rd=x1, BTB Miss, No Rewind Required:   %d", 
        num_jal_x1_miss_norewind);
    $display("   JAL, rd!=x1, BTB Hit, Rewind Required:      %d", 
        num_jal_nx1_hit_rewind);
    $display("   JAL, rd!=x1, BTB Hit, No Rewind Required:   %d", 
        num_jal_nx1_hit_norewind);
    $display("   JAL, rd!=x1, BTB Miss, Rewind Required:     %d", 
        num_jal_nx1_miss_rewind);
    $display("   JAL, rd!=x1, BTB Miss, No Rewind Required:  %d", 
        num_jal_nx1_miss_norewind);
    
    // JALR instruction statistics
    $display("\n5. JALR Instruction Statistics:");
    $display("   JALR, rs1=x1, BTB Hit, Rewind Required:     %d", 
        num_jalr_x1_hit_rewind);
    $display("   JALR, rs1=x1, BTB Hit, No Rewind Required:  %d", 
        num_jalr_x1_hit_norewind);
    $display("   JALR, rs1=x1, BTB Miss, Rewind Required:    %d", 
        num_jalr_x1_miss_rewind);
    $display("   JALR, rs1=x1, BTB Miss, No Rewind Required: %d", 
        num_jalr_x1_miss_norewind);
    $display("   JALR, rs1!=x1, BTB Hit, Rewind Required:    %d", 
        num_jalr_nx1_hit_rewind);
    $display("   JALR, rs1!=x1, BTB Hit, No Rewind Required: %d", 
        num_jalr_nx1_hit_norewind);
    $display("   JALR, rs1!=x1, BTB Miss, Rewind Required:   %d", 
        num_jalr_nx1_miss_rewind);
    $display("   JALR, rs1!=x1, BTB Miss, No Rewind Required: %d", 
        num_jalr_nx1_miss_norewind);
    
    // Calculate total branch instructions to avoid division by zero
    total_branch_instr = 
        num_br_fwd_t_hit_rewind + num_br_fwd_t_hit_norewind + 
        num_br_fwd_t_miss_rewind + num_br_fwd_t_miss_norewind + 
        num_br_fwd_nt_hit_rewind + num_br_fwd_nt_hit_norewind + 
        num_br_fwd_nt_miss_rewind + num_br_fwd_nt_miss_norewind + 
        num_br_bwd_t_hit_rewind + num_br_bwd_t_hit_norewind + 
        num_br_bwd_t_miss_rewind + num_br_bwd_t_miss_norewind + 
        num_br_bwd_nt_hit_rewind + num_br_bwd_nt_hit_norewind + 
        num_br_bwd_nt_miss_rewind + num_br_bwd_nt_miss_norewind;
        
    // Calculate correct predictions (those that didn't require rewind)
    correct_branch_pred = 
        num_br_fwd_t_hit_norewind + num_br_fwd_nt_hit_norewind + 
        num_br_bwd_t_hit_norewind + num_br_bwd_nt_hit_norewind;
    
    // Calculate branch prediction accuracy with division by zero protection
    branch_pred_accuracy = (total_branch_instr > 0) ? 
        $itor(correct_branch_pred) / $itor(total_branch_instr) : 0.0;
    
    // Summary statistics
    $display("\n6. Summary Statistics:");
    $display("   - IPC (Instructions Per Cycle):              %f", 
        $itor(num_instr_exec) / $itor(cycle_counter));
    $display("   - Branch Prediction Accuracy:                %f", 
        branch_pred_accuracy);
    $display("   - Total branch instructions:                 %d", 
        total_branch_instr);
    
    $display("\n=========================================================================\n\n");
end
`endif
*/

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
    (input logic clk, rst_l, halted, instr_stall, needToFlush, bcond, sramWE, 
    input logic bShouldBeTaken,
    input logic [31:0] alu_out, npc_jal, npc_offset, pc_indirect, pcFromEx,
    input ctrl_signals_t  ctrl_signals, ctrl_signalsInDecode,
    output logic [31:0] npc_plus4, pc, next_pc,
    output logic [29:0] instr_addr,
    output logic bTaken,
    output logic [61:0] sramReadData,
    input logic [61:0] updatedSramReadData,
    input logic [1:0] predScheme);

    import MemorySegments::USER_TEXT_START;
    logic [61:0] sramReadData;

    // SRAM to hold previous branch predictions- used for branch always taken
    // and the 2-bit hysterisis prediction strategies
    sram btb (
        .clk, 
        .rst_l, 
        .we (sramWE), 
        .read_addr(pc[8:2]), 
        .write_addr(pcFromEx[8:2]), 
        .write_data(updatedSramReadData), 
        .read_data(sramReadData)
    );

    logic [29:0] tagPC, nextPCRead;
    logic [1:0] bHistory;
    assign {tagPC, bHistory, nextPCRead} = sramReadData;

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

    // Determines next_pc
    always_comb begin
        next_pc = npc_plus4;
        bTaken = 1'bx;
        if (needToFlush === 1'd1) begin // if a branch was previously mispredicted
            if (bShouldBeTaken) begin
                if ((ctrl_signals.pc_source==PC_cond)&&bcond) begin
                    next_pc = npc_offset;
                    bTaken = 1'dx;
                end
                else if (ctrl_signals.pc_source == PC_uncond) begin
                    next_pc = npc_jal;
                    bTaken = 1'dx;
                end
                else if (ctrl_signals.pc_source == PC_indirect) begin
                    next_pc = pc_indirect;
                    bTaken = 1'dx;
                end
            end
            else next_pc = pcFromEx + 32'd4;
        end
        else begin // otherwise behavior is determined based on the prediction strategy
            if (predScheme == 2'd0) begin // predicts not taken
                next_pc = npc_plus4;
                bTaken = 1'b0;
            end
            else if (predScheme == 2'd1) begin // 1-bit counter implementation
                if ({tagPC, 2'd0} === pc) begin
                    
                    // Use stored prediction (bHistory[0] is the prediction bit)
                    if (bHistory[0]) begin 
                        // Branch history bit is 1, predict branch as TAKEN
                        next_pc = {nextPCRead, 2'd0};
                        bTaken = 1'b1;
                    end else begin 
                        // Branch history bit is 0, predict branch as NOT TAKEN
                        next_pc = npc_plus4;
                        bTaken = 1'b0;
                    end
                end else begin
                    // No BTB entry exists for this PC, default to NOT TAKEN
                    next_pc = npc_plus4;
                    bTaken = 1'b0;
                end
            end
            else if (predScheme == 2'd2) begin // predicts based on 2 bit hysterisis counter
                if ((bHistory === 2'd2 | bHistory === 2'd3 ) & 
                    ({tagPC, 2'd0} == pc)) begin
                    next_pc = {nextPCRead, 2'd0};
                    bTaken = 1'b1;
                end
                else begin
                    next_pc = npc_plus4;
                    bTaken = 1'b0;
                end
            end
        end
    end

endmodule: IF

/* Decode the current instruction and handle register writeback (these can 
happen simultaneously) */
module decode 
    (input logic clk, rst_l, halted, timeToWrite, instr_stall, needToFlush, 
    input logic lastInstrStall,
    input logic flushInstr, flushInstr2,
    input logic [4:0] rdToWrite,
    input logic [31:0] instr, pc, rd_data,
    output logic [31:0] rs1_data, rs2_data, se_immediate,
    output logic [4:0] rs1, rs2, 
    output ctrl_signals_t  ctrl_signals,
    output logic flushed);

    ctrl_signals_t ctrl_signals_temp;
    riscv_decode Decoder(.rst_l, .stall(instr_stall), .instr, 
        .ctrl_signals(ctrl_signals_temp));

    logic [4:0]     rd;
    logic [31:0] rs1_dataTemp, rs2_dataTemp;
    assign  rs1             = (ctrl_signals.syscall)? 5'd10: instr[19:15];
    assign  rs2             = instr[24:20];
    assign  rd              = instr[11:7];

    // instantiate the register file
    register_file rf_file
    (.clk(clk), .rst_l(rst_l), .halted(halted), .rd_we(timeToWrite), 
    .rs1(rs1), .rs2(rs2), .rd(rdToWrite), .rd_data(rd_data), 
    .rs1_data(rs1_dataTemp), .rs2_data(rs2_dataTemp));

    // since the register file does not forward internally, we do it here
    // in the case that we are reading the data from the register that is
    // currently being written to
    logic timeToWrite2, match, timeToWrite22, match2;
    assign timeToWrite2 = 
        ((timeToWrite == 'b1) && ^timeToWrite !== 1'bx) ? 'b1: 'b0;
    assign match = 
        (((rs1 == rdToWrite) == 'b1) && ^rdToWrite !== 1'bx) ? 'b1:'b0;
    assign rs1_data = (match & timeToWrite2 & rdToWrite != 4'd0) ? rd_data: rs1_dataTemp;

    assign timeToWrite22 = 
        ((timeToWrite == 'b1) && ^timeToWrite !== 1'bx) ? 'b1: 'b0;
    assign match2 = 
        (((rs2 == rdToWrite) == 'b1) && ^rdToWrite !== 1'bx) ? 'b1:'b0;
    assign rs2_data = (match2 & timeToWrite22 & rdToWrite != 4'd0) ? rd_data: rs2_dataTemp;

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

    // If an instruction needs to be flushed- cancel out control signals
    always_comb begin
        if ((needToFlush & ~lastInstrStall) | flushInstr | flushInstr2) begin
            ctrl_signals.useImm = 1'b0;
            ctrl_signals.rfWrite = 1'b0;
            ctrl_signals.mem2RF = 1'b0;
            ctrl_signals.pc2RF = 1'b0;
            ctrl_signals.memRead = 1'b0;
            ctrl_signals.memWrite = 1'b0;
            ctrl_signals.imm_mode = IMM_DC;
            ctrl_signals.alu_op = ALU_DC;
            ctrl_signals.ldst_mode = LDST_DC;
            ctrl_signals.pc_source = PC_DC;
            ctrl_signals.btype = 3'd0;
            ctrl_signals.syscall = 1'b0;
            ctrl_signals.illegal_instr = 1'b0;
        end
        else begin // when an instruction does not need to be flushed
            ctrl_signals.useImm = ctrl_signals_temp.useImm;
            ctrl_signals.rfWrite = ctrl_signals_temp.rfWrite;
            ctrl_signals.mem2RF = ctrl_signals_temp.mem2RF;
            ctrl_signals.pc2RF = ctrl_signals_temp.pc2RF;
            ctrl_signals.memRead = ctrl_signals_temp.memRead;
            ctrl_signals.memWrite = ctrl_signals_temp.memWrite;
            ctrl_signals.imm_mode = ctrl_signals_temp.imm_mode;
            ctrl_signals.alu_op = ctrl_signals_temp.alu_op;
            ctrl_signals.ldst_mode = ctrl_signals_temp.ldst_mode;
            ctrl_signals.pc_source = ctrl_signals_temp.pc_source;
            ctrl_signals.btype = ctrl_signals_temp.btype;
            ctrl_signals.syscall = ctrl_signals_temp.syscall;
            ctrl_signals.illegal_instr = ctrl_signals_temp.illegal_instr;
        end
    end

    assign flushed = (needToFlush & ~lastInstrStall) | flushInstr | flushInstr2;

endmodule: decode

/* Updated Excecute Module with Forwarding 
   Handles calculations via the ALU with forwarding */
module execute
    (input logic clk, rst_l,
    input logic bTaken, forwardLoadA, forwardLoadB,
    input logic [1:0] forwardStore, predScheme,
    input logic [31:0] rs2_data, se_immediate, rs1_data, instr, data_load, pc, 
    input logic  [31:0] data_load_temp, rd_data, instr_F2DE,  npc_plus4_F1F2DE, 
    input logic  [31:0] instr_F2DEM1,  npc_plus4_F1F2DEM1, next_pc_F1F2D,
    input ctrl_signals_t  ctrl_signals,
    input logic [1:0] forwardA, forwardB, // Forwarding control signals
    input logic [31:0] alu_out_E, alu_out_EM1, alu_out_EM1M2, // Forwarded values
    output logic [31:0] alu_out,
    output logic [31:0] npc_jal, npc_offset, pc_indirect, rs2_data_out, 
    output logic [31:0] alu_src1_forwarded,
    output logic needToFlush, bcond, sramWE, bShouldBeTaken,
    input logic [61:0] sramReadData,
    output logic [61:0] updatedSramReadData,
    output logic branch_is_forward_out);

    import RISCV_ISA::*;

    logic [31:0] alu_src1_forwarded, alu_src2_forwarded, alu_src2;

    // Forwarding logic for store instructions
    always_comb begin
        case (forwardStore)
            2'b00: begin
                rs2_data_out = rs2_data; // Normal path (Register File Output)
            end
            2'b10: begin
                if (opcode_t'(instr_F2DE[6:0]) == OP_JAL | 
                    opcode_t'(instr_F2DE[6:0]) == OP_JALR) begin
                    rs2_data_out = npc_plus4_F1F2DE;
                end
                else
                    rs2_data_out = alu_out_E;     // EX forwarding
            end
            2'b01: begin
                if (opcode_t'(instr_F2DEM1[6:0]) == OP_JAL | 
                    opcode_t'(instr_F2DEM1[6:0]) == OP_JALR) begin
                    rs2_data_out = npc_plus4_F1F2DEM1;
                end
                else
                    rs2_data_out = alu_out_EM1;   // MEM1 forwarding
            end
            2'b11: begin 
                rs2_data_out = rd_data;
            end
            default: rs2_data_out = rs2_data;
        endcase
    end

    // Forwarding Logic for rs1- when non-store instruction
    always_comb begin
        case (forwardA)
            2'b00: alu_src1_forwarded = rs1_data;       // Normal path (Register File Output)
            2'b10: begin
                if (opcode_t'(instr_F2DE[6:0]) == OP_JAL | 
                    opcode_t'(instr_F2DE[6:0]) == OP_JALR) // jumps
                    alu_src1_forwarded = npc_plus4_F1F2DE;
                else
                    alu_src1_forwarded = alu_out_E;
                //alu_src1_forwarded = alu_out_E;      // EX forwarding

            end
            2'b01: begin
                if (opcode_t'(instr_F2DEM1[6:0]) == OP_JAL | 
                    opcode_t'(instr_F2DEM1[6:0]) == OP_JALR) // jumps
                    alu_src1_forwarded = npc_plus4_F1F2DEM1;
                else
                    alu_src1_forwarded = alu_out_EM1;
                //alu_src1_forwarded = alu_out_EM1;    // MEM1 forwarding
            end
            2'b11: alu_src1_forwarded = rd_data;        // MEM2 forwarding
            default: alu_src1_forwarded = rs1_data;
        endcase
    end

    // Forwarding Logic for rs2- when non-store instruction
    always_comb begin
        case (forwardB)
            2'b00: alu_src2_forwarded = rs2_data;       // Normal path (Register File Output)
            2'b10: alu_src2_forwarded = alu_out_E;      // EX forwarding
            2'b01: alu_src2_forwarded = alu_out_EM1;    // MEM1 forwarding
            2'b11: alu_src2_forwarded = rd_data;        // MEM2 forwarding
            default: alu_src2_forwarded = rs2_data;
        endcase
    end

    // Select either immediate value or forwarded rs2_data
    assign alu_src2 = 
        (!ctrl_signals.useImm) ? alu_src2_forwarded : se_immediate;

    // ALU Execution
    riscv_alu ALU(
        .alu_src1(alu_src1_forwarded), 
        .alu_src2(alu_src2), 
        .alu_op(alu_op_t'(ctrl_signals.alu_op)), 
        .alu_out(alu_out)
    );

    logic [31:0] boffset;

    // BCOND generation logic
    always_comb begin
        if (opcode_t'(instr[6:0]) == OP_BRANCH) begin
            case(ctrl_signals.btype)
                FUNCT3_BEQ: bcond = (alu_out==0);
                FUNCT3_BNE: bcond = 
                    ($signed(alu_src1_forwarded) != $signed(alu_src2));
                FUNCT3_BLT: bcond = 
                    ($signed(alu_src1_forwarded) < $signed(alu_src2));
                FUNCT3_BGE: bcond = 
                    ($signed(alu_src1_forwarded) >= $signed(alu_src2));
                FUNCT3_BLTU: bcond = alu_src1_forwarded < alu_src2;
                FUNCT3_BGEU: bcond = alu_src1_forwarded >= alu_src2;
                default: bcond = (alu_out==0);
            endcase
        end
        else bcond = (alu_out==0);
    end

    // boffset generation
    assign boffset = {{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};

    // calculates potential pc- for branching
    adder #($bits(pc)) jalAdder(.A(pc), 
                                .B(se_immediate), 
                                .cin(1'b0),
                                .sum(npc_jal), .cout());
    adder #($bits(pc)) Offset_PC_Adder(.A(pc), .B(boffset), .cin(1'b0),
            .sum(npc_offset), .cout()); 
    
    // TODO: NEED TO FORWARD PC_INDIRECT
    assign pc_indirect = {alu_out[31:1], 1'b0};

    // determines if the branch should have been taken
    //logic bShouldBeTaken;
    assign bShouldBeTaken = (((ctrl_signals.pc_source==PC_cond)&&bcond) |
        (ctrl_signals.pc_source == PC_uncond) |
        (ctrl_signals.pc_source == PC_indirect));
    
    // checks if the branch prediction was correct
    always_comb begin
        if (bShouldBeTaken === 1'bx | bTaken === 1'bx) needToFlush = 1'b0;
        else begin
            if (ctrl_signals.pc_source == PC_indirect) 
                needToFlush = (bShouldBeTaken != bTaken) | (next_pc_F1F2D != pc_indirect);
            else needToFlush = (bShouldBeTaken != bTaken);
        end
    end

    // based on the prediction strategy determines if and what needs to be 
    // written back to the BTB
    always_comb begin
        sramWE = 1'b0;
        updatedSramReadData = 62'dx;
        if (ctrl_signals.pc_source != PC_plus4)
            if (predScheme == 2'd1) begin // predicts always taken

                /* Updated info into sram
                    1.(left most) PC TAG
                    2. Branch history bit (taken or not taken)
                    3. Branch Target Address
                */

                sramWE = 1'b1; // always write to BTB regardless of branch outcome
                
                if (ctrl_signals.pc_source == PC_cond) begin
                    // For conditional branches, set prediction based on actual outcome
                    if (bcond) begin // Branch Taken
                        updatedSramReadData = {pc[31:2], 2'b01, npc_offset[31:2]};
                    end else begin // Branch Not Taken
                        updatedSramReadData = {pc[31:2], 2'b00, npc_offset[31:2]};
                    end
                end
                else if (ctrl_signals.pc_source == PC_uncond) begin
                    // For JAL instructions (always taken)
                    updatedSramReadData = {pc[31:2], 2'b01, npc_jal[31:2]};
                end
                else if (ctrl_signals.pc_source == PC_indirect) begin
                    // For JALR instructions (always taken)
                    updatedSramReadData = {pc[31:2], 2'b01, pc_indirect[31:2]};
                end
                else begin
                    // Not a branch/jump, don't update BTB/SRAM
                    sramWE = 1'b0;
                end
            end
            else if (predScheme == 2'd2) begin // prediction based on 2-bit hysterisis
                if (bShouldBeTaken) begin
                    sramWE = 1'b1;
                    if (ctrl_signals.pc_source == PC_cond && 
                        sramReadData[31:30] != 2'd3) begin
                        updatedSramReadData = {pc[31:2], 
                            sramReadData[31:30] + 2'd1, npc_offset[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_cond && 
                        sramReadData[31:30] == 2'd3) begin
                        updatedSramReadData = {pc[31:2], sramReadData[31:30], 
                            npc_offset[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_uncond && 
                        sramReadData[31:30] != 2'd3) begin
                        updatedSramReadData = {pc[31:2], 
                            sramReadData[31:30] + 2'd1, npc_jal[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_uncond && 
                        sramReadData[31:30] == 2'd3) begin
                        updatedSramReadData = {pc[31:2], sramReadData[31:30], 
                            npc_jal[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_indirect && 
                        sramReadData[31:30] != 2'd3) begin
                        updatedSramReadData = {pc[31:2], 
                            sramReadData[31:30] + 2'd1, pc_indirect[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_indirect && 
                        sramReadData[31:30] == 2'd3) begin
                        updatedSramReadData = {pc[31:2], sramReadData[31:30], 
                            pc_indirect[31:2]};
                    end
                end
                else if (~bShouldBeTaken) begin
                    sramWE = 1'b1;
                    if (ctrl_signals.pc_source == PC_cond && 
                        sramReadData[31:30] != 2'd0) begin
                        updatedSramReadData = {pc[31:2], 
                            sramReadData[31:30] - 2'd1, npc_offset[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_cond && 
                        sramReadData[31:30] == 2'd0) begin
                        updatedSramReadData = {pc[31:2], sramReadData[31:30], 
                            npc_offset[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_uncond && 
                        sramReadData[31:30] != 2'd0) begin
                        updatedSramReadData = {pc[31:2], 
                            sramReadData[31:30] - 2'd1, npc_jal[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_uncond && 
                        sramReadData[31:30] == 2'd0) begin
                        updatedSramReadData = {pc[31:2], sramReadData[31:30], 
                            npc_jal[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_indirect && 
                        sramReadData[31:30] != 2'd0) begin
                        updatedSramReadData = {pc[31:2], 
                            sramReadData[31:30] - 2'd1, pc_indirect[31:2]};
                    end
                    else if (ctrl_signals.pc_source == PC_indirect && 
                        sramReadData[31:30] == 2'd0) begin
                        updatedSramReadData = {pc[31:2], sramReadData[31:30], 
                            pc_indirect[31:2]};
                    end
                end
                else begin
                    sramWE = 1'b0;
                    updatedSramReadData = 62'dx;
                end
            end
            else begin
                sramWE = 1'b0;
                updatedSramReadData = 62'dx;
            end
    end
    assign branch_is_forward_out = ~boffset[31];
endmodule: execute


/* Handles memory stores and loads */
module mem
    (input logic clk, rst_l,
    input logic [31:0] instr, rs1_data, rs2_data, alu_out, pc,
    input ctrl_signals_t  ctrl_signals,
    output logic data_load_en,
    output logic [31:0] data_store,
    output logic [29:0] data_addr,
    output logic [3:0] data_store_mask);

    import RISCV_ISA::*;
    
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
        // subsection of data_load needs to be written back to the register 
        // file if a load operation
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

    // start to handle ecall in the writeback stage
    logic [31:0] a0_value;
    logic ctrl_signals_syscallTemp;
    assign a0_value = (rs1 == 5'd10 & (^rs1 !== 'x)) ? rs1_data: 32'd0;
    assign ctrl_signals_syscallTemp = 
        (^ctrl_signals.syscall === 'bx) ? 1'b0: ctrl_signals.syscall;
    assign syscall_halt = 
        ctrl_signals_syscallTemp && a0_value == ECALL_ARG_HALT;

endmodule: writeback
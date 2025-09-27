
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
    logic [31:0]    se_immediate, alu_src2;

    // PC offset
    assign boffset = {{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};

    // based on the type of instruction and its pc_source, choose next_pc
    always_comb begin
        if ((ctrl_signals.pc_source==PC_cond)&&bcond)
            next_pc = npc_offset;
        else if (ctrl_signals.pc_source == PC_uncond)
            next_pc = npc_jal;
        else if (ctrl_signals.pc_source == PC_indirect)
            next_pc = {alu_out[31:1], 1'b0};
        else 
            next_pc = npc_plus4;
    end
 
    // adders to determine potential next_pc
    adder #($bits(pc)) Next_PC_Adder(.A(pc), .B('d4), .cin(1'b0),
            .sum(npc_plus4), .cout());
    adder #($bits(pc)) Offset_PC_Adder(.A(pc), .B(boffset), .cin(1'b0),
            .sum(npc_offset), .cout());

    // instantiate a register to hold the current pc
    register #($bits(pc), USER_TEXT_START) PC_Register(.clk, .rst_l, 
        .en(~halted), .clear(1'b0), .D(next_pc),
            .Q(pc));
            
    assign instr_addr       = pc[31:2];    
    assign instr_stall      = 1'b0;

    // Decode the instruction and generate the control signals
    ctrl_signals_t  ctrl_signals;
    riscv_decode Decoder(.rst_l, .instr, .ctrl_signals);

    // load data manipulation
    logic [31:0] data_load_temp;

    /* Access the register file.
     * TODO: Instantiate the register file from register_file.sv here. Don't
     * forget to hookup the halted signal so that the register dump will be
     * triggered.  Once you hookup the register file, additest and addtest
     * should work. */

    logic [4:0]     rs1, rs2, rd;
    logic [31:0]    rs1_data, rs2_data, rd_data, rs2_data_temp;
    
    // we need to set rs1 = 10 if ecall is the current instruction
    assign  rs1             = (ctrl_signals.syscall)? 5'd10: instr[19:15];
    assign  rs2             = instr[24:20];
    assign  rd              = instr[11:7];

    always_ff @(posedge clk) begin
        //if (ctrl_signals.rfWrite)
            //$display("INSTR: %h, rd to write: %d writing %h", instr, rd, rd_data, $time);
        //if (data_store_mask != 0) $display($time, "INSTR: %h data_addr: %h data_store: %h", instr, data_addr, data_store);
        if (data_store_mask != 0)
        $display("INSTR: %h store mask: %h data_addr: %h data_store: %h", instr, data_store_mask, data_addr, data_store, $time);
    end
    // instantiate the register file
    register_file
    //#(parameter WAYS=SUPERSCALAR_WAYS, NUM_REGS=RISCV_ISA::NUM_REGS, WIDTH=XLEN, FORWARD=0)
    (.clk(clk), .rst_l(rst_l), .halted(halted), .rd_we(ctrl_signals.rfWrite), 
    .rs1(rs1), .rs2(rs2), .rd(rd), .rd_data(rd_data), .rs1_data(rs1_data), 
    .rs2_data(rs2_data));
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

    // se_immediate computation based on the type of immediate instruction
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

    adder #($bits(pc)) jalAdder(.A(pc), 
                                .B(se_immediate), 
                                .cin(1'b0),
                                .sum(npc_jal), .cout());

    /* if our instruction uses an immediate, then alu_src2 must be set to 
    se_immediate, but otherwise is rs2_data */
    assign alu_src2 = (!ctrl_signals.useImm) ? rs2_data : se_immediate;
    
    // instantiate the alu
    riscv_alu ALU(.alu_src1(rs1_data), .alu_src2(alu_src2), 
        .alu_op(alu_op_t'(ctrl_signals.alu_op)), .alu_out(alu_out));

    /* if we have a branch instruction, check if the branch condition is met-
    if so, set bcond to 1 and otherwise bcond = 0 meaning that the branch will
    not be taken */
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

    logic [31:0]         mult_out;   // assign mult_out = rs1_data * rs2_data ;                                                           
    // set first parameter to 0 for combinatonal; to 1 for pipelined.                                    
    // mult #(0, 32) multiplier (.A(rs1_data), .B(rs2_data), .O(mult_out), 
    // .CLK(clk));

    assign data_load_en     = ctrl_signals.memRead;
    assign data_addr        = alu_out[31:2];
    assign data_stall       = 1'b0;
    
    /* last 2 bits of alu_out determine which subsection of the word you need
    to load */
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

    /* assigns data_store and data_store_mask - for storing data based on 
    the given instuction */
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
                    data_store = data_load;
                end
            endcase
        end
        else begin // to avoid inferred latches
            data_store_mask = 4'b0;
            data_store = data_load;
        end
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
   
    // initializes variables in order to handle exceptions
    logic [31:0]    a0_value;
    logic           syscall_halt, exception_halt;
    
    // handles exceptions
    assign a0_value = (rs1 == 5'd10) ? rs1_data: 32'd0;
    assign syscall_halt = ctrl_signals.syscall && a0_value == ECALL_ARG_HALT;
    assign exception_halt   = instr_mem_excpt | data_mem_excpt | 
        ctrl_signals.illegal_instr;
    assign halted = rst_l & (syscall_halt | exception_halt);

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

/**
 * sim.c
 *
 * RISC-V 32-bit Instruction Level Simulator
 *
 * ECE 18-447
 * Carnegie Mellon University
 *
 * This is the core part of the simulator. The `process_instruction` function
 * will be invoked by the simulator each time it needs to simulate a single
 * processor cycle. This is responsible for simulating the next processor cycle.
 * This corresponds to simulating the next instruction, and updating the
 * register file, memory, and PC register appropriately as required by the next
 * instruction.
 *
 * This is where you can start add code and make modifications to implement the
 * rest of the instructions. You can add any additional files or change and
 * delete files as you need to implement the simulator, provided that they are
 * under the src directory. You may not change any files outside the src
 * directory. The only requirement is that you define a `process_instruction`
 * function with the same interface as below.
 *
 * The Makefile will automatically find any files you add, provided they are
 * under the src directory and have either a *.c or *.h extension. The files may
 * be nested in subdirectories under the src directory as well. Additionally,
 * the build system sets up the include paths so that you can place header files
 * in any subdirectory under the src directory, and include them from anywhere
 * else inside the src directory.
 **/

/*----------------------------------------------------------------------------*
 *  You may edit this file and add or change any files in the src directory.  *
 *----------------------------------------------------------------------------*/

// Standard Includes
#include <stdio.h>              // Printf and related functions
#include <stdbool.h>            // Boolean type and definitions

// 18-447 Simulator Includes
#include <riscv_isa.h>          // Definition of RISC-V opcodes, ISA registers
#include <riscv_abi.h>          // ABI registers and definitions
#include <sim.h>                // Definitions for the simulator
#include <memory.h>             // Interface to the processor memory
#include <register_file.h>      // Interface to the register file

/**
 * Simulates a single cycle on the CPU, updating the CPU's state as needed.
 *
 * This is the core part of the simulator. This simulates the current
 * instruction pointed to by the PC. This performs the necessary actions for the
 * instruction, and updates the CPU state appropriately.
 *
 * You implement this function.
 *
 * Inputs:
 *  - cpu_state     The current state of the CPU being simulated.
 *
 * Outputs:
 *  - cpu_state     The next state of the CPU being simulated. This function
 *                  updates the fields of the state as needed by the current
 *                  instruction to simulate it.
 * 
 * 
 **/
void process_instruction(cpu_state_t *cpu_state)
{
    // Fetch the 4-bytes for the current instruction
    uint32_t instr = mem_read32(cpu_state, cpu_state->pc);

    // Decode the opcode, 7-bit function code, and registers
    opcode_t opcode = instr & 0x7F;
    
    switch (opcode)
    {
        // General R-Type arithmetic operation: ADD, SUB, SLL, SLT, SLTU, XOR, 
        //SRL, SRA, OR, AND (pg 19)
        case OP_OP: {
            // form [funct7 - 7 bits | rs2 - 5 bits | rs1 - 5 bits | 
            //funct3 - 3 bits | rd - 5 bits | opcode - 7 bits]

            funct7_t funct7 = (instr >> 25) & 0x7F; // decoding type of funct7 operation
            riscv_isa_reg_t rs2 = (instr >> 20) & 0x1F; // decoding various registers
            riscv_isa_reg_t rs1 = (instr >> 15) & 0x1F;
            rtype_funct3_t rtype_funct3 = (instr >> 12) & 0x7; // decoding type of funct3 operation
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F;
            switch (rtype_funct3)
            {
                // 3-bit function code for add or subtract
                case FUNCT3_ADD_SUB: {
                    switch (funct7)
                    {
                        // 7-bit function code for typical integer 
                        // Add Instruction 
                        case FUNCT7_INT: {
                            // Read and add values from source registers rs1 and rs2
                            uint32_t sum = register_read(cpu_state, rs1) + 
                                            register_read(cpu_state, rs2);
                            
                            // Store result in destination register
                            register_write(cpu_state, rd, sum);

                            /* Update program counter to next instruction 
                               after execution */
                            cpu_state->pc = cpu_state->pc + sizeof(instr);
                            break;
                        }

                        // Subtract Instruction
                        case FUNCT7_ALT_INT:{
                            // Read and subtract values from source registers rs1 and rs2
                            uint32_t sum = register_read(cpu_state, rs1) - 
                                            register_read(cpu_state, rs2);
                            
                            // Store result in destination register
                            register_write(cpu_state, rd, sum);

                            /* Update program counter to next instruction 
                               after execution */
                            cpu_state->pc = cpu_state->pc + sizeof(instr);
                            break;
                        }

                        default: {
                            fprintf(stderr, 
                                    "Encountered unknown R-type ADD/SUB"
                                    "7-bit funct7 code 0x%01x. Halting "
                                    "simulation.\n", funct7);
                            cpu_state->halted = true;
                            break;
                        }
                    }
                    break;
                }

                // Shift left (logical)
                case FUNCT3_SLL: {
                    /* Logical left shift on on the value in register rs1 by 
                    the shift amount held in the lower 5 bits of register rs2 
                    (source register) */
                    
                    // Extract register values
                    uint32_t r1_value = register_read(cpu_state, rs1);
                    uint32_t r2_value = register_read(cpu_state, rs2) & 0x1F; 
                    // extract lower 5 bits of rs2

                    // Excecute left shift operation
                    r1_value = r1_value << r2_value;

                    // Update destination register with shifted value
                    register_write(cpu_state, rd, r1_value);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Shift right logical/arithmetic
                case FUNCT3_SRL_SRA: {
                    /* Right shift on on the value in register rs1 by the 
                    shift amount held in the lower 5 bits of register rs2 
                    (source register) */
                    switch (funct7)
                    {
                        // SRL (right shift logical)
                        case FUNCT7_INT: {
                            // Extract register values
                            uint32_t r1_value = register_read(cpu_state, rs1);
                            uint32_t r2_value = register_read(cpu_state, rs2) 
                                                & 0x1F; // extract lower 5 bits of rs2

                            // Excecute right shift operation with no sign extension
                            r1_value = r1_value >> r2_value;

                            // Update destination register with shifted value
                            register_write(cpu_state, rd, r1_value);

                            /* Update program counter to next instruction 
                                after execution */
                            cpu_state->pc = cpu_state->pc + sizeof(instr);
                            break;
                        }

                        // SRA (right shift arithmetic)
                        case FUNCT7_ALT_INT:{
                            // Extract register values
                            int32_t r1_value = register_read(cpu_state, rs1);
                            int32_t r2_value = register_read(cpu_state, rs2) & 
                                                0x1F; // get lower 5 bits of rs2

                            // Execute right shift operation with sign extension
                            r1_value = r1_value >> r2_value;

                            // Update destination register with shifted value
                            register_write(cpu_state, rd, r1_value);

                            /* Update program counter to next instruction 
                               after execution */
                            cpu_state->pc = cpu_state->pc + sizeof(instr);
                            break;
                        }

                        default: {
                            fprintf(stderr, "Encountered unknown R-type ADD/SUB"
                                    "7-bit funct7 code 0x%01x. Halting "
                                    "simulation.\n", funct7);
                            cpu_state->halted = true;
                            break;
                        }
                    }
                    break;
                }

                // XOR Function
                case FUNCT3_XOR: {
                    // Read and XOR values from source registers rs1 and rs2
                    uint32_t sum = register_read(cpu_state, rs1) ^ 
                                    register_read(cpu_state, rs2);

                    // Update result into destination register
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // OR Function
                case FUNCT3_OR: {
                    // Read and OR values from source registers rs1 and rs2
                    uint32_t sum = register_read(cpu_state, rs1) | 
                    register_read(cpu_state, rs2);

                    // Update result into destination register
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // AND Function
                case FUNCT3_AND: {
                    // Read and AND values from source registers rs1 and rs2
                    uint32_t sum = register_read(cpu_state, rs1) & 
                    register_read(cpu_state, rs2);
                    
                    // Update result into destination register
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Set < Signed (SLT)
                case FUNCT3_SLT: {
                    // Extract values from source registers rs1 and rs2
                    int32_t rs1_value = register_read(cpu_state, rs1);
                    int32_t rs2_value = register_read(cpu_state, rs2);

                    // Conduct signed comparison of the values
                    uint32_t result_comparison = 
                        (rs1_value < rs2_value) ? 1 : 0;

                    // Define result in destination register
                    register_write(cpu_state, rd, result_comparison);
                    
                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Set < Unsigned (SLTU)
                case FUNCT3_SLTU: {
                    // Extract values from source registers rs1 and rs2
                    uint32_t rs1_value = register_read(cpu_state, rs1);
                    uint32_t rs2_value = register_read(cpu_state, rs2);

                    // Conduct unsigned comparison of the values
                    uint32_t result_comparison = 
                        (rs1_value < rs2_value) ? 1 : 0;

                    // Define result in destination register
                    register_write(cpu_state, rd, result_comparison);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                default: {
                    fprintf(stderr, "Encountered unknown R-type "
                            "3-bit funct3 code 0x%01x. Halting "
                            "simulation.\n",
                            rtype_funct3);
                    cpu_state->halted = true;
                    break;
                }
            }
            break;
        }

        // General I-type arithmetic operations: ADDI, SLTI, SLTIU, XORI, 
        //ORI, ANDI, SLLI, SRLI, SRAI (pg 18)
        case OP_IMM: {
            // form [imm[11:0] - 12 bits | rs1 - 5 bits | funct3 - 3 bits | 
            //rd - 5 bits | opcode - 7 bits]
            itype_int_funct3_t itype_funct3 = (instr >> 12) & 0x7;
            int32_t itype_imm = ((int32_t)instr) >> 20;
            riscv_isa_reg_t rs1 = (instr >> 15) & 0x1F;
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F;
            switch (itype_funct3)
            {
                // Shift left (logical)
                case FUNCT3_SLLI: {
                    /* Logical left shift on on the value in register rs1 by 
                    the shift amount held in the lower 5 bits of I-immediate 
                    field */
                    
                    // Extract register values
                    uint32_t r1_value = register_read(cpu_state, rs1);

                    r1_value = r1_value << (itype_imm & 0x1F); // left shift 
                    // extract lower 5 bits of I immediate value

                    // Update destination register with shifted value
                    register_write(cpu_state, rd, r1_value);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Shift right logical/arithmetic
                case FUNCT3_SRLI_SRAI: {
                    /* Right shift on the value in register rs1 by the shift 
                    amount held in the lower 5 bits of the I-immediate field */

                    // Extract bit 30 to determine whether it's SRLI or SRAI
                    uint32_t is_arithmetic = (instr >> 30) & 0x1;

                    // Extract register values
                    uint32_t r1_value = register_read(cpu_state, rs1);
                    uint32_t imm_shift_val = itype_imm & 0x1F; 
                    // Extract lower 5 bits of I-immediate

                    if (is_arithmetic == 0) {
                        // SRLI (Logical Shift Right)
                        r1_value = r1_value >> imm_shift_val; // Perform 
                        // logical right shift
                    } else {
                        // SRAI (Arithmetic Shift Right)
                        int32_t signed_value = (int32_t)r1_value; // Treat as 
                        // signed value
                        r1_value = signed_value >> imm_shift_val; // Perform 
                        // arithmetic right shift
                    }

                    // Update destination register with shifted value
                    register_write(cpu_state, rd, r1_value);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Add Immediate (ADDI)
                case FUNCT3_ADDI: {
                    // Read value from source register rs1 and add it to immediate
                    uint32_t sum = register_read(cpu_state, rs1) + itype_imm;

                    // Write result to destination register
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // XOR Immediate (XORI)
                case FUNCT3_XORI: {
                    // Read value from source register rs1 and xor it to immediate
                    uint32_t sum = register_read(cpu_state, rs1) ^ itype_imm;

                    // Write result to destination register
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // OR Immediate (ORI)
                case FUNCT3_ORI: {
                    // Read value from source register rs1 and or it to immediate
                    uint32_t sum = register_read(cpu_state, rs1) | itype_imm;
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // AND Immediate (ANDI)
                case FUNCT3_ANDI: {
                    // Read value from source register rs1 and AND it to immediate
                    uint32_t sum = register_read(cpu_state, rs1) & itype_imm;

                    // Write result to destination register
                    register_write(cpu_state, rd, sum);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // // Set < Immediate Signed (SLTI)
                case FUNCT3_SLTI:{
                    // Signed Comparison
                    // Read value from source register rs1 and compare it to immediate 
                    int32_t rs1_value = register_read(cpu_state, rs1);
                    uint32_t result_comparison = 
                        (rs1_value < itype_imm) ? 1 : 0;
                    
                    // Write result to destination register
                    register_write(cpu_state, rd, result_comparison);
                    
                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Set < Immediate Unsigned (SLTIU)
                case FUNCT3_SLTIU:{
                    // Unsigned Comparison
                    // Read value from source register rs1 and compare it to immediate
                    uint32_t rs1_value = register_read(cpu_state, rs1);
                    uint32_t result_comparison = 
                        (rs1_value < (uint32_t)itype_imm) ? 1 : 0;
                    
                    // Write result to destination register
                    register_write(cpu_state, rd, result_comparison);

                    /* Update program counter to next instruction 
                       after execution */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                default: {
                    fprintf(stderr, "Encountered unknown I-type 3-bit "
                            "funct3 code 0x%01x. Halting simulation.\n",
                            itype_funct3);
                    cpu_state->halted = true;
                    break;
                }
            }
            break;
        }

        // Load operations (I-type): LB, LH, LW, LBU, LHU (pg 24)
        case OP_LOAD: {
            // form [imm[11:0] - 12 bits | rs1 - 5 bits | funct3 - 3 bits | 
            //rd - 5 bits | opcode - 7 bits]
            itype_load_funct3_t itype_load_funct3 = (instr >> 12) & 0x7;
            int32_t itype_imm = ((int32_t)instr) >> 20;
            riscv_isa_reg_t rs1 = (instr >> 15) & 0x1F;
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F;
            /* remember little endian order: i.e
             * in memory 0x01 0x02 0x03 0x04
             * read out 0x04 0x03 0x02 0x01
             */
            switch (itype_load_funct3)
            {
                // Load Byte (LB)
                case FUNCT3_LB: {
                    /* Loads a 8 bit value from memory, then sign-extends to 
                    32 bits before storing in rd (destination register) */

                    // Compute effective memory address to load to
                    uint32_t addr = register_read(cpu_state, rs1) + itype_imm;

                    // Determine byte position of the aligned 4 byte word
                    uint32_t byte_position = addr % 4;

                    // Read aligned word at start of word
                    uint32_t result_32 = 
                        mem_read32(cpu_state, addr - byte_position);

                    // Define offset for mask
                    uint32_t mask_offset = byte_position * 8;

                    // Extract target byte / creates mask for target byte
                    result_32 = result_32 & (0xFF << mask_offset);

                    /* Shift extracted byte to the least significant 8 bits & 
                       sign extend to 32 bits */
                    result_32 = (int8_t) (result_32 >> mask_offset);
                    /* Casted  extracted byte to a signed 8 bit 
                       integer. Ensures the sign bit is propogated when 
                       casting to a larger type (32 bits) */

                    /* Update CPU state w/ destination register and program counter */
                    register_write(cpu_state, rd, result_32);
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Load Halfword (LH)
                case FUNCT3_LH: {
                    /* Loads a 16 bit value from memory, then sign-extends to 
                    32 bits before storing in rd (destination register) */

                    // Compute effective memory address to load to
                    uint32_t addr = register_read(cpu_state, rs1) + itype_imm;

                    // Determine byte position within the extracted word
                    uint32_t byte_position = addr % 4;

                    // Read aligned word at start of word
                    uint32_t result_32 = mem_read32(cpu_state, addr - byte_position);

                    // Define offset for mask
                    uint32_t mask_offset = byte_position * 8;

                    // Extract target halfword / creates mask for target halfword
                    result_32 = result_32 & (0xFFFF << mask_offset);

                    /* Shift extracted halfword to the least significant 
                       16 bits & sign extend to 32 bits */
                    result_32 = (int16_t) (result_32 >> mask_offset);
                    /* Casted  extracted halfword to a signed 16 bit 
                       integer. Ensures the sign bit is propogated when 
                       casting to a larger type (32 bits) */

                    /* Update CPU state w/ destination register and program counter */
                    register_write(cpu_state, rd, result_32);
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Load Word (LB)
                case FUNCT3_LW: {
                     // Compute effective memory address to load to
                    uint32_t addr = register_read(cpu_state, rs1) + itype_imm;

                    // Read aligned word at start of word
                    uint32_t result = mem_read32(cpu_state, addr);

                     /* Update CPU state w/ destination register and program counter */
                    register_write(cpu_state, rd, result);
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Load Byte Unsigned (LBU)
                case FUNCT3_LBU: {
                    /* Loads a 8 bit value from memory, then zero extends to 
                    32 bits before storing in rd (destination register)*/

                    // Compute effective memory address to load to
                    uint32_t addr = register_read(cpu_state, rs1) + itype_imm;

                    // Determine byte position of the aligned 4 byte word
                    uint32_t byte_position = addr % 4;

                    // Read aligned word at start of word
                    uint32_t result_32 = mem_read32(cpu_state, addr - byte_position);

                    // Define offset for mask
                    uint32_t mask_offset = byte_position * 8;

                    // Extract target byte / creates mask for target byte
                    result_32 = result_32 & (0xFF << mask_offset);

                    // Shift extracted byte to the least significant 8 bits & sign extend to 32 bits
                    result_32 = (uint8_t) (result_32 >> mask_offset);
                    /* Casted  extracted byte to an unsigned 8 bit 
                       integer. Ensures the sign bit is NOT propogated when 
                       casting to a larger type (32 bits) */

                    /* Update CPU state w/ destination register and program counter */
                    register_write(cpu_state, rd, result_32);
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Load Halfword Unsigned (LBU)
                case FUNCT3_LHU: {
                    /* Loads a 16 bit value from memory, then zero-extends to 
                    32 bits before storing in rd (destination register) */

                    // Compute effective memory address to load to
                    uint32_t addr = register_read(cpu_state, rs1) + itype_imm;

                    // Determine byte position within the extracted word
                    uint32_t byte_position = addr % 4;

                    // Read aligned word at start of word
                    uint32_t result_32 = mem_read32(cpu_state, addr - byte_position);

                    // Define offset for mask
                    uint32_t mask_offset = byte_position * 8;

                    // Extract target halfword / creates mask for target halfword
                    result_32 = result_32 & (0xFFFF << mask_offset);

                    /* Shift extracted halfword to the least significant 
                        16 bits & sign extend to 32 bits */
                    result_32 = (uint16_t) (result_32 >> mask_offset);
                    /* Casted  extracted halfword to unsigned 16 bit 
                       integer. Ensures the sign bit is NOT propogated when 
                       casting to a larger type (32 bits) */

                    /* Update CPU state w/ destination register and program counter */
                    register_write(cpu_state, rd, result_32);
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                default: {
                    fprintf(stderr, "Encountered unknown/unimplemented 3-bit "
                            "load function code 0x%01x. Halting simulation.\n",
                            itype_load_funct3);
                    cpu_state->halted = true;
                    break;
                }
            }
            break;
        }

        // Store operations (S-type): SB, SH, SW (pg 24)
        case OP_STORE: {
            // form [imm[11:5] - 7 bits | rs2 - 5 bits | rs1 - 5 bits | 
            //funct3 - 3 bits | imm[4:0] - 5 bits | opcode - 7 bits]
            stype_funct3_t stype_funct3 = (instr >> 12) & 0x7;
            uint32_t stype_offset = (((int32_t)instr >> 25) << 5) | ((instr >> 7) & 0x1F);
            riscv_isa_reg_t rs1 = (instr >> 15) & 0x1F;
            riscv_isa_reg_t rs2 = (instr >> 20) & 0x1F;
            switch (stype_funct3)
            {
                // Store Byte (SB)
                case FUNCT3_SB: {
                    // Compute memory address to store byte to
                    uint32_t addr = register_read(cpu_state, rs1) + stype_offset;   

                    // Read byte to be written from source register
                    uint8_t insert_byte = register_read(cpu_state, rs2);

                    // Figure out byte position within word of computed address
                    uint32_t byte_position = addr % 4;

                    // Fetch original data at start of word
                    uint32_t original_data = mem_read32(cpu_state, addr - byte_position);

                    // Define mask offset
                    uint32_t mask_offset = byte_position * 8;

                    // Mask out byte area of interest
                    original_data = original_data & ~((0xFF) << mask_offset);

                    // Insert byte extracted from source register into byte area of interest
                    original_data = original_data | (insert_byte << mask_offset);

                    // Write target byte into address
                    mem_write32(cpu_state, addr - byte_position, original_data);

                    /* Update CPU state w/ destination register and program counter */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Store Halfword (SH)
                case FUNCT3_SH: {
                    // Compute memory address to store halfword to
                    uint32_t addr = register_read(cpu_state, rs1) + stype_offset;   

                    // Read halfword to be written from source register
                    uint16_t insert_halfword = register_read(cpu_state, rs2);

                    // Figure out byte position within word of computed address
                    uint32_t byte_position = addr % 4;

                    // Fetch original data at start of word
                    uint32_t original_data = mem_read32(cpu_state, addr - byte_position);

                    // Define mask offset
                    uint32_t mask_offset = byte_position * 8;

                    // Mask out halfword area of interest
                    original_data = original_data & ~((0xFFFF) << mask_offset);

                    // Insert halfword extracted from source register into byte area of interest
                    original_data = original_data | (insert_halfword << mask_offset);

                    // Write target byte into address
                    mem_write32(cpu_state, addr - byte_position, original_data);

                    /* Update CPU state w/ destination register and program counter */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                // Store Word (SW)
                case FUNCT3_SW: {
                    // Compute Memory Address to store word to
                    uint32_t addr = register_read(cpu_state, rs1) + stype_offset;

                    // Read word to be stored from source register
                    uint32_t result_32 = register_read(cpu_state, rs2);

                    // Write target word into computed address
                    mem_write32(cpu_state, addr, result_32);

                    /* Update CPU state w/ destination register and program counter */
                    cpu_state->pc = cpu_state->pc + sizeof(instr);
                    break;
                }

                default: {
                    fprintf(stderr, "Encountered unknown/unimplemented 3-bit "
                        "S-type function code 0x%01x. Halting simulation.\n",
                        stype_funct3);
                    cpu_state->halted = true;
                    break;
                }
            }
            break;
        }

        // Load Upper Immediate operation (U-type) (pg 19)
        case OP_LUI: {
            // form [imm[31:12] - 20 bits| rd - 5 bits | opcode - 7 bits]
            /* Places U-immediate value in the top 20 bits of the destination 
               register 'rd' filling in the lowest 12 bits with zeros */
            
            // Decode destination register from U-type instruction
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F; 

            // Decode immediate value from instruction with lowest 12 bits masked to zero
            uint32_t lui_immediate = instr & 0xFFFFF000;

            // Fill in value of immediate value to destination register in the top 20 bits, lower 12 bits is masked to zero
            register_write(cpu_state, rd, lui_immediate);

            // Update program counter after instruction finishes executing
            cpu_state->pc = cpu_state->pc + sizeof(instr);

            break;
        }


        // Add Upper Immediate to PC operation (U-type) (pg 19)
        case OP_AUIPC: {
            // form [imm[31:12] - 20 bits| rd - 5 bits | opcode - 7 bits]
            /* Forms 32 bit offset from 20 bit U-immediate, filling in the 
               lowest 12 bits with zero, adds this offset to the address of 
               the AUIPIC instruction, then places the result in 
               destination register 'rd' */
            
            // Decode destination register from U-type instruction
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F; 

            // Decode immediate value from instruction with lowest 12 bits masked to zero
            uint32_t lui_immediate = instr & 0xFFFFF000;

            // Add offset to address of AUIPIC instruction, which is currently where the program counter is at
            uint32_t destination_value = cpu_state->pc + lui_immediate;

            // Fill in added value to the destination register
            register_write(cpu_state, rd, destination_value);

            // Update program counter after instruction finishes executing
            cpu_state->pc = cpu_state->pc + sizeof(instr);
            break;
        }

        // Jump and Link operation (UJ-type)
        case OP_JAL: {
            // form [imm[20 | 10 : 1 | 11 | 19 : 12] - 20 bits| rd - 5 bits | 
            //opcode - 7 bits]
            // restores the immediate value to the correct order
            int32_t imm = (((instr & 0x80000000) >> 11) |
                ((instr & 0x7FE00000) >> 20) |
                ((instr & 0x00100000) >> 9) |
                (instr & 0x000FF000));
            imm = (imm << 11) >> 11;
            int32_t target = cpu_state->pc + imm;
            // check that the target is 4 byte aligned
            if (target % 4 != 0) {
                cpu_state->halted = true;
                break;
            }
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F;
            // only write if rd > 0 since if rd = 0 then this stays 0
            if (rd > 0) {
                register_write(cpu_state, rd, cpu_state->pc + 4);
            }
            // update the pc
            cpu_state->pc = target;
            break;
        }

        // Jump and Link Register operation (I-type)
        case OP_JALR: {
            // form [imm[11:0] - 12 bits | rs1 - 5 bits | 000 | rd - 5 bits | 
            //opcode - 7 bits]
            // shift the immediate and sign extend
            int32_t imm = ((int32_t)(instr & 0xFFF00000)) >> 20;
            riscv_isa_reg_t rs1 = (instr >> 15) & 0x1F;
            //calculate the target
            uint32_t target_temp = register_read(cpu_state, rs1) + imm;
            uint32_t target = target_temp & 0xFFFFFFFE;
            // ensure that the target is 4 byte aligned
            if (target % 4 != 0) {
                cpu_state->halted = true;
                break;
            }
            riscv_isa_reg_t rd = (instr >> 7) & 0x1F;
            // write only if the destination register is not 0
            if (rd > 0) {
                register_write(cpu_state, rd, cpu_state->pc + 4);
            }
            // update the pc
            cpu_state->pc = target;
            break;
        }

        // Branch operations (SB-type): BEQ, BNE, BLT, BGE, BLTU, BGEU (pg 22)
        case OP_BRANCH: {
            // form [ imm[12 | 10:5] - 7 bits | rs2 - 5 bits | rs1 - 5 bits | 
            //funct3 - 3 bits | imm[4:1 | 11] - 5 bits | opcode - 7 bits]
            sbtype_funct3_t sbtype_funct3 = (instr >> 12) & 0x7;
            uint32_t sbtype_offset_12 = (uint32_t)((int32_t)instr >> 31);
            uint32_t sbtype_offset_11 = (instr >> 7) & 0x1;
            uint32_t sbtype_offset_10_5 = (instr >> 25) & 0x3F; // 5 bits
            uint32_t sbtype_offset_4_1 = (instr >> 8) & 0xF;
            uint32_t sbtype_offset_0 = 0; 
            int32_t sbtype_offset = (int32_t)((sbtype_offset_12 << 12) | 
                (sbtype_offset_11 << 11) | (sbtype_offset_10_5 << 5) | 
                (sbtype_offset_4_1 << 1) | sbtype_offset_0);
            riscv_isa_reg_t rs1 = (instr >> 15) & 0x1F;
            riscv_isa_reg_t rs2 = (instr >> 20) & 0x1F;
            switch (sbtype_funct3)
            {
                // 3-bit function code for BEQ
                case FUNCT3_BEQ: {
                    uint32_t target = cpu_state->pc + sbtype_offset;
                    cpu_state->pc = (register_read(cpu_state, rs1) == 
                        register_read(cpu_state, rs2)) ? 
                        target : cpu_state->pc + sizeof(instr);
                    break;
                }
                // branches only if rs1 != rs2
                case FUNCT3_BNE: {
                    uint32_t target = cpu_state->pc + sbtype_offset;
                    cpu_state->pc = (register_read(cpu_state, rs1) != 
                    register_read(cpu_state, rs2)) ? target : 
                    cpu_state->pc + sizeof(instr);
                    break;
                }
                // branches only if rs1 < rs2
                case FUNCT3_BLT: {
                    uint32_t target = cpu_state->pc + sbtype_offset;
                    cpu_state->pc = ((int32_t)register_read(cpu_state, rs1) < 
                    (int32_t)register_read(cpu_state, rs2)) ? target : 
                    cpu_state->pc + sizeof(instr);
                    break;
                }
                // branches only if rs1 >= rs2
                case FUNCT3_BGE: {
                    uint32_t target = cpu_state->pc + sbtype_offset;
                    cpu_state->pc = ((int32_t)register_read(cpu_state, rs1) >= 
                    (int32_t)register_read(cpu_state, rs2)) ? target : 
                    cpu_state->pc + sizeof(instr);
                    break;
                }
                // branches only if rs1 <= rs2 (both unsigned)
                case FUNCT3_BLTU: {
                    uint32_t target = cpu_state->pc + sbtype_offset;
                    cpu_state->pc = ((uint32_t)register_read(cpu_state, rs1) < 
                    (uint32_t)register_read(cpu_state, rs2)) ? target : 
                    cpu_state->pc + sizeof(instr);
                    break;
                }
                // branches only if rs1 >= rs2 (unsigned)
                case FUNCT3_BGEU: {
                    uint32_t target = cpu_state->pc + sbtype_offset;
                    cpu_state->pc = ((uint32_t)register_read(cpu_state, rs1) 
                    >= (uint32_t)register_read(cpu_state, rs2)) ? target : 
                    cpu_state->pc + sizeof(instr);
                    break;
                }
                // error handling of unrecognized op code
                default: {
                    fprintf(stderr, "Encountered unknown/unimplemented 3-bit "
                        "SB-type function code 0x%01x. Halting simulation.\n",
                        sbtype_funct3);
                    cpu_state->halted = true;
                    break;
                }
            }
            break;
        }

        // General system operation (I-type): ECALL
        case OP_SYSTEM: {
            // form [funct12 - 12 bits | all 0's | opcode - 7 bits]
            itype_funct12_t sys_funct12 = (instr >> 20) & 0xFFF;
            switch (sys_funct12)
            {
                // 12-bit function code for ECALL
                case FUNCT12_ECALL: {
                    uint32_t a0_value = register_read(cpu_state, REG_A0);
                    if (a0_value == ECALL_ARG_HALT) {
                        fprintf(stdout, "ECALL invoked with halt argument, "
                                "halting the simulator.\n");
                        cpu_state->halted = true;
                    }
                    else {
                        cpu_state->pc = cpu_state->pc + sizeof(instr);
                    }
                    break;
                }

                default: {
                    fprintf(stderr, "Encountered unknown/unimplemented 12-bit "
                            "system function code 0x%03x. Halting "
                            "simulation.\n", sys_funct12);
                    cpu_state->halted = true;
                    break;
                }
            }
            break;
        }

        default: {
            fprintf(stderr, "Encountered unknown opcode 0x%02x. Halting "
                    "simulation.\n", opcode);
            cpu_state->halted = true;
            break;
        }
    }

    return;
}
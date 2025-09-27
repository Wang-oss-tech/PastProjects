// William Wang
// www2
// top.sv
`default_nettype none

`ifndef STRUCTS
`define STRUCTS

  typedef enum logic [3:0] {START    = 4'h1,
                            ENTER    = 4'h2,
                            ARITH_OP = 4'h4, 
                            DONE     = 4'h8} oper_t; 
                            
  typedef struct packed { // what appears at the data input 
    oper_t       op;
    logic [15:0] payload; 
    } keyIn_t; 
    
`endif


//////////////////////
////             ////
////    top     ////
////           ////
//////////////////

module top();

    //inputs to calculator
    logic    clock, reset_N;
    keyIn_t  data;

    //outputs from calculator
    logic [15:0]  result;
    logic         stackOverflow, unexpectedDone, protocolError, dataOverflow, 
                correct, finished;
    logic [7:0][15:0] stackOut;

    TA_calc  brokenCalc(.*);

    //the system clock
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Testing Variables in testbench
    // Arithmetic Operations
    logic [15:0] data_a;
    logic [15:0] data_b;

    // Stack
    logic [3:0]  count_stack;
    logic [3:0]  prev_count_stack;

    // Testbench Status Variables
    logic ADDING;
    logic FINISHED;

    // Adjust count of stack based on commands
    always_ff @(posedge clock, negedge reset_N) begin
      if (~reset_N) 
        count_stack <= 0;
      else if (START == data.op)
        count_stack <= 1; // starting stack with one element
      else if (ENTER == data.op)
        count_stack <= 1 + count_stack; // `entering` element into stack
      else if (ARITH_OP == data.op) begin
        // If these ARITH_OPs below, decrease stack size
        // ADD: 16'h1, SUBTRACT: 16'h2, AND: 16'h4, POP: 16'h20
        if (data.payload == 16'h20 ||     // POP
            data.payload == 16'h4  ||     // AND
            data.payload == 16'h2  ||     // SUBTRACT
            data.payload == 16'h1)        // ADD
        count_stack <= count_stack - 1;
      end
      // save stack size
      else count_stack <= count_stack; 
      
      // other operations does not adjust stack size
      prev_count_stack <= count_stack;
    end

    //this task should contain your testbench
    task runTestbench(input int phase);
      begin
        /* * * * * * * * * * * * 
         * YOUR TESTBENCH HERE *
         * * * * * * * * * * * */

        // Resetting Stack
        reset_N = 0;
        #1 reset_N = 1;

        // Testing Adding Correctness
        $display("*************ARITHMETIC CORRECTNESS TESTS*************");
        $display("\n----------START OF 10 ADDING TESTS------------");
        for (int i = 1; i <= 10; i++) begin
          ADDING = 1;
          data_a = $urandom;
          data_b = $urandom;
          @(posedge clock);
          data.payload <= data_a;
          data.op <= START;
          @(posedge clock);
          data.payload <= data_b;
          data.op <= ENTER;
          @(posedge clock);
          // 16'h1 -> ADD operation for ARITH_OP
          data.payload <= 16'h1;
          data.op <= ARITH_OP;
          @(posedge clock);
          @(posedge clock);
          // Check 
          INCORRECT_ADDING_ERROR: assert(data_a + data_b == result) begin
            $display("......Passed!!");
          end
          else begin
            assert (~correct);
            $display("CORRECTNESS FAILED: add incorrect, offend assertion");
            $display("Expecting sum of  %0d but got %0d\n", (data_a + data_b), result);
          end
          
          @(posedge clock);

          // Reset for each clock cycle
          reset_N = 0;
          # 1 reset_N = 1;
        end
        $display("----------END OF 10 ADDING TESTS------------");


        $display("\n----------START OF ANDING TEST------------");
        // Resetting Stack
        @(posedge clock);
        reset_N = 0;
        #1 reset_N = 1;

        data.payload <= 16'd8;
        data.op <= START;
        @(posedge clock);
        data.payload <= 16'd0;
        data.op <= ENTER;
        @(posedge clock);
        // 16'h4 -> AND operation for ARITH_OP
        data.payload <= 16'h4;
        data.op <= ARITH_OP;
        @(posedge clock);
        @(posedge clock);
        INCORRECT_ANDING_ERROR: assert(result == 16'd0) begin
          $display("......Passed!!");
        end
        else begin
          assert(~correct)
          $display("CORRECTNESS FAILED: AND incorrect, offend assertion");
          $display("Expecting result of  %0d but got %0d\n", 16'd0, result);
        end
        $display("----------END OF ANDING TEST------------");


        $display("\n----------START OF SUBTRACTING TEST------------");
        // Resetting Stack
        @(posedge clock);
        reset_N = 0;
        #1 reset_N = 1;

        // set add status variable off
        ADDING = 0; 
        data_a = $urandom;
        data_b = $urandom;
        @(posedge clock);
        data.payload <= data_a;
        data.op <= START;
        @(posedge clock);
        data.payload <= data_b;
        data.op <= ENTER;
        @(posedge clock);
        // 16'h2 -> SUBTRACTION operation for ARITH_OP
        data.payload <= 16'h2;
        data.op <= ARITH_OP;
        @(posedge clock);
        @(posedge clock);
        // Check 
        INCORRECT_SUBTRACTING_ERROR: assert(data_a - data_b == result) begin
          $display("......Passed!!");
        end
        else begin
          assert (~correct);
          $display("CORRECTNESS FAILED: SUBTRACT incorrect, offend assertion");
          $display("Expecting result of  %0d but got %0d\n", (data_a - data_b), result);
        end
        $display("----------END OF SUBTRACTING TEST------------");

        $display("\n----------START OF SWAPPING TEST------------");
        // Resetting Stack
        @(posedge clock);
        reset_N = 0;
        #1 reset_N = 1;

        data.payload <= 16'd38; // [0]: 38
        data.op <= START;
        @(posedge clock);
        data.payload <= 16'd40; // [0]:0 [1]: 40
        data.op <= ENTER;
        @(posedge clock);
        // 16'h8 -> SWAP operation for ARITH_OP
        data.payload <= 16'h8;
        data.op <= ARITH_OP;
        @(posedge clock);
        @(posedge clock);
        STACK_COUNT: assert(count_stack == 2) 
          $display("SWAP stack count...passed");
        else 
          $display("ERROR: SWAP changes stack count. Expected 2, Got: %0d", count_stack);
        
        SWAPPING_ERROR_TOP: assert(stackOut[0] == 16'd38) begin
          $display("top...passed");
        end
        else begin
          assert(~correct);
          $display("CORRECTNESS FAILED: SWAPPING incorrect, offend assertion");
          $display("Expecting result of  %0d but got %0d\n", 16'd38, stackOut[0]);
        end
        SWAPPING_ERROR_BOTTOM: assert(stackOut[1] == 16'd40) begin
          $display("bottom...passed");
        end
        else begin
          assert(~correct);
          $display("CORRECTNESS FAILED: SWAPPING incorrect, offend assertion");
          $display("Expecting result of  %0d but got %0d\n", 16'd40, stackOut[1]);
        end
        $display("----------END OF SWAPPING TEST------------");

        $display("\n----------START OF NEGATING TEST------------");
        // Resetting Stack
        @(posedge clock);
        reset_N = 0;
        #1 reset_N = 1;

        data.payload <= 16'h1; // 0000 0000 0000 0001
        data.op <= START;
        @(posedge clock);
        // 16'h10-> NEGATE operation for ARITH_OP
        data.payload <= 16'h10;
        data.op <= ARITH_OP;
        @(posedge clock);
        @(posedge clock);
        // 16'h1 complement = 1111 1111 1111 1111

        INCORRECT_NEGATING_ERROR: assert(result == 16'hffff) begin
          $display("......Passed!!");
        end
        else begin
          assert(~correct);
          $display("CORRECTNESS FAILED: Negating incorrect, offend assertion");
          $display("Expecting result of  %0h but got %0h\n", 16'hffff, result);
        end
        $display("----------END OF NEGATING TEST------------");


        $display("\n----------START OF POPPING TEST------------");
        // Resetting Stack
        @(posedge clock);
        reset_N = 0;
        #1 reset_N = 1;

        data.op <= START;
        data.payload <= 16'd1;
        @(posedge clock);
        // 16'h20-> POP operation for ARITH_OP
        data.payload <= 16'h20;
        data.op <= ARITH_OP;
        @(posedge clock);
        @(posedge clock);
        /* With only one element left, result(value at the top of the stack) 
        should be at 0 */
        INCORRECT_POPPING_ERROR: assert(result == 16'd0) begin
          $display("......Passed!!");
        end
        else begin
          assert(~correct);
          $display("CORRECTNESS FAILED: Popping incorrect, offend assertion");
          $display("Expecting result of  %0d but got %0d\n", 16'd0, result);
        end
       $display("----------END OF POPPING TEST------------");

      $display("\n*************END OF ARITHMETIC CORRECTNESS TEST***************");
      
      $display("\n*************DONE & OVERFLOW TEST***************\n");
      $display("----------START OF DONE TEST------------");
       // Resetting Stack
       @(posedge clock);
       reset_N = 0;
       #1 reset_N = 1;

       FINISHED <= 1;
       data.op <= START;
       data.payload <= 16'h1;
       @(posedge clock);
       data.op <= DONE;
       @(posedge clock);
       INCORRECT_DONE_ERROR: assert(correct) begin
        $display("......Correct Asserted!!");
       end else begin
        $display("CORRECTNESS FAILED: Expected `correct` to be asserted ", 
                  "since program finishes with no errors\n");
       end 
        
       INCORRECT_FINISHED_ERROR: assert(finished) begin
        $display("......Finished Asserted!!");
       end else begin
        $display("CORRECTNESS FAILED: Expected `finished` to be asserted ", 
                  "since program finishes\n");
       end
       @(posedge clock);
      $display("----------END OF DONE TEST------------");

      $display("\n----------START OF DATAOVEFLOW TEST------------");
      // Resetting Stack
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;

      $display("Adding Overflow");
      data.payload <= 16'h7FFF; // 0111 1111 1111 1111, 32767
      data.op <= START;
      @(posedge clock);
      data.op <= ENTER;
      data.payload <= 16'h1;    // 0000 0000 0000 0001, 32767
      @(posedge clock);
      // 16'h1 -> ADD operation for ARITH_OP
      data.payload <= 16'h1;
      data.op <= ARITH_OP;
      @(posedge clock);
      ADDING_OVERFLOW_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when dataOverflow error occurs\n");
      end
      ADDING_DATAOVEFLOW_ERROR: assert(dataOverflow) begin
        $display("......Passed!!");
      end else begin
        $display("CORRECTNESS FAILED: Expected dataOverflow to be asserted.\n");
      end

      $display("Subtracting Overflow");
      // 16'h20-> POP operation for ARITH_OP
      data.payload <= 16'h20;
      data.op <= ARITH_OP;
      @(posedge clock);
      data.payload <= 16'h7FFF; // 0111 1111 1111 1111
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 16'h8001; // 1000 0000 0000 0001
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 16'h2; // sub
      data.op <= ARITH_OP;
      @(posedge clock);
      SUBTRACTING_OVERFLOW_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when dataOverflow error occurs\n");
      end
      SUBTRACTING_DATAOVEFLOW_ERROR: assert(dataOverflow) begin
        $display("......Passed!!");
      end else begin
        $display("CORRECTNESS FAILED: Expected dataOverflow to be asserted.\n");
      end
      // Clear stack with pop
      data.op <= ARITH_OP;
      data.payload <= 16'h20; // pop
      @(posedge clock);
      $display("----------END OF DATAOVERFLOW TEST------------");
      $display("\n*************DONE & OVERFLOW TEST***************\n");

      $display("*************STACK OVERFLOW & UNEXPECTED DONE TEST***************\n");
      $display("----------START OF STACK_OVERFLOW & UNEXPECTED DONE TEST------------");
      // Resetting Stack
      reset_N = 0;
      #1 reset_N = 1;

      // Random Input Data
      data_a <= $urandom;
      @(posedge clock);
      data.payload <= data_a;
      data.op <= START;
      data_a <= $urandom;
      for (int j = 0; j < 8; j++) begin
        @(posedge clock);
        data.payload <= data_a;
        data.op <= ENTER;
        data_a <= $urandom; // update random value
      end
      @(posedge clock);
      STACK_OVERFLOW_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when dataOverflow error occurs\n");
      end
      STACK_OVERFLOW_ERROR: assert(stackOverflow) begin
        $display("#1 StackOverflow Test......Passed!!");
      end else begin
        $display("StackOverflow Error: Expected stackOverflow to be asserted.\n");
      end
      // SET DONE
      data.op <= DONE;  
      @(posedge clock);

      /* Unexpected Done Test */
      reset_N = 0;
      #1 reset_N = 1;

      // Fill up stack
      data.payload <= 1; 
      data.op <= START;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1; 
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.op <= DONE;
      @(posedge clock);
      UNEXPECTED_DONE_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when dataOverflow error occurs\n");
      end
      UNEXPECTED_DONE_ERROR: assert(unexpectedDone) begin
        $display("Unexpected Done Test......Passed!!");
      end else begin
        $display("unexpectedDone Error: missing unexpectedDone (calling done when its not one element left)\n");
      end
      $display("----------END  OF STACK_OVERFLOW & UNEXPECTED DONE TEST------------\n");

      $display("----------START OF CHECK_STACK TEST------------");
      // Resetting Stack
      reset_N = 0;
      #1 reset_N = 1;

      // Fill up stack
      data.payload <= 1; 
      data.op <= START;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1; 
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1; 
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 1; 
      data.op <= ENTER;
      @(posedge clock);
      
      assert(stackOut[0] == 1) // silent if correct
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[0]);
      assert(stackOut[1] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[1]);
      assert(stackOut[2] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[2]);
      assert(stackOut[3] == 1)
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[3]);
      assert(stackOut[4] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[4]);
      assert(stackOut[5] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[5]);
      assert(stackOut[6] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[6]);
      assert(stackOut[7] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[7]);
      $display("----------END  OF CHECK_STACK TEST------------\n");



      $display("----------START OF SWAP_STACK TEST------------");
      // Resetting Stack
      reset_N = 0;
      #1 reset_N = 1;

      // Fill up stack
      data.payload <= 1; 
      data.op <= START;
      @(posedge clock);
      data.payload <= 2;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 3; 
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 4;
      data.op <= ENTER;
      @(posedge clock);
      data.payload <= 5;
      @(posedge clock);
      data.payload <= 6;
      data.op <= ENTER;
      @(posedge clock);
      // 16'h8 -> SWAP operation for ARITH_OP
      data.payload <= 16'h8;
      data.op <= ARITH_OP;
      @(posedge clock);
      @(posedge clock);
      assert(stackOut[0] == 5) // silent if correct
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 5", stackOut[0]);
      assert(stackOut[1] == 6) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 6", stackOut[1]);
      assert(stackOut[2] == 4) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 4", stackOut[2]);
      assert(stackOut[3] == 3)
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 3", stackOut[3]);
      assert(stackOut[4] == 2) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 2", stackOut[4]);
      assert(stackOut[5] == 1) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 1", stackOut[5]);
      assert(stackOut[6] == 0) 
      else $error("STACK ERROR: INCORRECT ELEMENT, got: %0d, expected 0", stackOut[6]);
      $display("----------END OF SWAP_STACK TEST------------\n");




      $display("\n*************END: STACK OVERFLOW & UNEXPECTED DONE TEST***************\n");

      $display("************* START of Protocol Error Tests***************\n");
      reset_N = 0;
      #1 reset_N = 1;

      $display("----------START OF Invalid Op Error TEST------------");
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      data.payload <= 16'h25;
      data.op <= ARITH_OP;
      @(posedge clock);
      InvalidOp_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      InvalidOp_ERROR: assert(protocolError) begin
        $display("ProtcolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.\n");
      end

      $display("----------END OF Invalid Op Error TEST------------\n");

      $display("----------START OF Two Element Op Error TEST------------");
      // SUBTRACTING
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      // 16'h2 -> SUB Operation on one element
      data.payload <= 16'h2;
      data.op <= ARITH_OP;
      @(posedge clock);
      twoElOp_SUB_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      twoElOp_SUB_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "Subtracting with one element\n");
      end

      // ADDING
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      // 16'h1 -> ADD Operation on one element
      data.payload <= 16'h1;
      data.op <= ARITH_OP;
      @(posedge clock);
      twoElOp_ADDING_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      twoElOp_ADDING_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "Adding with one element\n");
      end

      // SWAPPING
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      // 16'h8 -> ADD Operation on one element
      data.payload <= 16'h8;
      data.op <= ARITH_OP;
      @(posedge clock);
      twoElOp_SWAP_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      twoElOp_SWAP_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "SWAPPING with one element\n");
      end

      // ANDING
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      // 16'h4 -> AND Operation on one element
      data.payload <= 16'h4;
      data.op <= ARITH_OP;
      @(posedge clock);
      twoElOp_AND_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      twoElOp_AND_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "ANDING with one element\n");
      end

      $display("----------END OF Two Element Op Error TEST------------\n");

      $display("----------START OF One Element Op Error TEST------------");
      // POP
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      // 16'h20 -> POP Operation on one element
      data.payload <= 16'h20;
      data.op <= ARITH_OP;
      @(posedge clock);
      // 16'h20 -> POP Operation on one element
      data.payload <= 16'h20;
      data.op <= ARITH_OP;
      @(posedge clock);
      oneElOp_POP_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      oneElOp_POP_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "Popping with no elements left\n");
      end
      $display("----------END OF One Element Op Error TEST------------\n");

      $display("----------START OF Negate Error TEST------------");
      // NEGATE
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= data_a;
      @(posedge clock);
      // 16'h20 -> POP Operation on one element
      data.payload <= 16'h20;
      data.op <= ARITH_OP;
      @(posedge clock);
      // 16'h10 -> Negate Operation on one element
      data.payload <= 16'h10;
      data.op <= ARITH_OP;
      @(posedge clock);
      oneElOp_NEGATE_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      oneElOp_NEGATE_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "Negating with no elements left\n");
      end
      $display("----------END OF Negate Error TEST------------\n");

      $display("----------START OF START-START Error TEST------------");
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= 16'd1;
      @(posedge clock);
      data.payload <= 16'd1;
      data.op <= START;
      @(posedge clock);
      startStart_CORRECT_ERROR: assert(~correct) else begin
        $display("CORRECTNESS FAILED: Correct shouldn't be asserted when error occurs\n");
      end
      startStart_NEGATE_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "calling two starts consecutively\n");
      end
      $display("----------END OF START-START Error TEST------------\n");

      $display("----------START OF betweenStartDone Error TEST------------");
      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;
      data_a <= $urandom;
      data.op <= START;
      data.payload <= 16'd1;
      @(posedge clock);
      // Popping only element in stack
      data.payload <= 16'h20;
      data.op <= ARITH_OP;
      @(posedge clock);
      data.op <= DONE;
      betweenStartDone_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("Protocol Error: Expected protocolError to be asserted.", 
                  "no elements between Start and done\n");
      end
      @(posedge clock);
      betweenStartDone_FINISHED_ERROR: assert(finished) begin
        $display("......Finished Asserted!!");
       end else begin
        $display("CORRECTNESS FAILED: Expected `finished` to be asserted ", 
                  "since program finishes\n");
       end
      $display("----------END OF betweenStartDoneTEST------------\n");


      $display("----------START OF tooMany_Operations Error TEST------------");

      reset_N = 0;
      # 1 reset_N = 1;

      @(posedge clock);
      reset_N = 0;
      #1 reset_N = 1;

      data.op <= START;
      data.payload <= 16'd1;
      @(posedge clock);
      // Popping only element in stack
      data.payload <= 16'h1;
      data.op <= ENTER;
      @(posedge clock);
      // Loading both enter and addition (multiplc commands at once)
      data.payload <= 16'h20;
      data.op <= ENTER;
      data.payload <= 16'h21; // add
      data.op <= ARITH_OP;
      @(posedge clock);
      tooMany_Operations_ERROR: assert(protocolError) begin
        $display("ProtocolError Test......Passed!!");
      end else begin
        $display("PROTOCOL ERROR: Expected protocolError to be asserted.", 
                  "too many operations at once");
      end
      $display("----------END OF tooMany_operations ------------\n");
      $display("\n************* END Protocol Error Tests***************\n");




      end
    endtask
      
    /* * * * * * * * * * * * * 
     * YOUR ASSERTIONS HERE  *
     * * * * * * * * * * * * */
    
    /* Stack Overflow Assertion */
    property prop_stackOverflow();
        @(posedge clock) 
          disable iff(~reset_N)
            data.op != DONE |=> (count_stack < 4'd8 || 
                                 count_stack == 4'd15);
    endproperty

    assert_stackOverflow : assert property(prop_stackOverflow())     
    else begin
      assert(stackOverflow)
        $display("^^CORRECT: Overflow detected..stackOverflow correctly asserted!!\n");
      else 
        $error("STACK OVERFLOW ERROR AT TIME %0d, stackOverflow expected but not asserted\n", $stime);
    end

    /* Unexpected Done */
    property prop_unexpectedDone();
        @(posedge clock)
          disable iff(~reset_N)
            data.op == DONE |=> (prev_count_stack == 1 ||
                                 count_stack == 1);
    endproperty

    assert_unexpectedDone: assert property(prop_unexpectedDone())    // silent if properly asserted
    else begin
      assert(unexpectedDone)
        $display("^^CORRECT: Unexpected Done detected..signal correctly asserted!!\n");
      else 
        $error("UNEXPECTED DONE ERROR AT TIME %0d, UNEXPECTED DONE expected but not asserted\n", $stime);
    end

    /* Protocols */
    // Protocol 1: there aren't enough items on the stack to do the specified operation;
    // operations that require 2 element (add, subtract, and, swap)
    property prop_protocol_2_element_operations();
        @(posedge clock) 
          disable iff(~reset_N)
            !ADDING &&
            data.op == ARITH_OP &&
            (data.payload == 16'h1 ||
             data.payload == 16'h2 ||
             data.payload == 16'h4 ||
             data.payload == 16'h8) |=> (prev_count_stack >= 2);
    endproperty

    protocol_1_error_2elementOp: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end


    // operations that require 1 element (negate, pop)
    property prop_protocol_1_element_operations();
        @(posedge clock) 
          disable iff(~reset_N)
            !ADDING &&
            data.op == ARITH_OP &&
            (data.payload == 16'h10 ||
             data.payload == 16'h20) |=> (prev_count_stack >= 1);
    endproperty

    protocol_1_error_1elementOp: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end

    // Protocol 2: START appears again before DONE;
    property prop_protocol_2();
        @(posedge clock) 
          disable iff(~reset_N)
            !FINISHED && data.op == DONE |-> data.op == START;
    endproperty

    protocol_2_error: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end

    // Protocol 3: between START and DONE, there should always be 
    // at least one element in the stack (never 0) — START puts the 
    // first one there, and DONE leaves the last one (the result) on the stack.
    property prop_protocol_3();
        @(posedge clock) 
          disable iff(~reset_N)
            data.op == START |=> count_stack != 0;
    endproperty
    protocol_3_error: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end

    // Protocol 4: the command is invalid
    property prop_protocol_4();
        @(posedge clock) 
          disable iff(~reset_N)
            data.op == ARITH_OP |-> (data.payload == 16'h1 || 
                                     data.payload == 16'h2 || 
                                     data.payload == 16'h4 || 
                                     data.payload == 16'h8 || 
                                     data.payload == 16'h10 || 
                                     data.payload == 16'h20);
    endproperty
    protocol_4_error: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end

    // Check that stack count decreases after (add, subtract, and, swap)
    property op_decrease_stack();
        @(posedge clock) 
          disable iff(~reset_N)
            data.op == ARITH_OP && (data.payload == 16'h1 || 
                                    data.payload == 16'h2 || 
                                    data.payload == 16'h4 || 
                                    data.payload == 16'h20) |=>
                                    (count_stack == 4'd15 || count_stack == prev_count_stack - 1);
    endproperty

    protocol_stack_decrease_error: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end


    // check that stack count remains the same with (negate, popo)
    property op_remain_stack();
        @(posedge clock) 
          disable iff(~reset_N)
            data.op == ARITH_OP && (data.payload == 16'h8 || 
                                    data.payload == 16'h10) |=>
                                    (count_stack == prev_count_stack);
    endproperty
    protocol_stack_remain_error: assert property(prop_unexpectedDone())
    else begin
      assert(protocolError)
        $display("^^CORRECT: Protocol Error detected..signal correctly asserted!!\n");
      else 
        $error("PROTOCOL ERROR AT TIME %0d, protocolError expected but not asserted\n", $stime);
    end





endmodule: top
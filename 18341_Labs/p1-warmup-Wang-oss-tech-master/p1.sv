`default_nettype none

/* Downstream module that captures the 
/ calculated sum and holds it for display */
module downStream
    (input logic done, ck, reset,
     input logic [7:0] displayValue,
     output logic [7:0] sum);
      
    always_ff @(posedge ck) 
        if (reset) sum <= 0; // clear sum
        else if (done) sum <= displayValue;

endmodule: downStream

// P1 Chip Interface that connects all Ports and instantiations
module p1
    (input logic CLOCK_50,
     input logic [3:0] KEY,
     output logic [17:0] LEDR,
     output logic [6:0] HEX3, HEX2, HEX1, HEX0);

    // Seven-Segment Display
    logic [3:0] BCD7, BCD6, BCD5, BCD4, BCD3, BCD2, BCD1, BCD0;
    logic [7:0] blank;
    logic [6:0] HEX7, HEX6, HEX5, HEX4;

    // Status Signal of Testbench
    logic [7:0] valueToinA, sum, sum_final, tbSum;
    logic done, go_l;

    // Synchronizers for KEY[2] and KEY[0]
    logic sync_KEY_2, sync_KEY_0;

    // Synchronizing key inputs
    Synchronizer sync_key_2 (
        .async(KEY[2]),
        .clock(CLOCK_50),
        .sync(sync_KEY_2)
    );

    Synchronizer sync_key_0 (
        .async(KEY[0]),
        .clock(CLOCK_50),
        .sync(sync_KEY_0)
    );

    // Testbench Stream
    tatb tb (
        .ck(CLOCK_50),
        .done(done),
        .reset_l(sync_KEY_2), 
        .Button0(sync_KEY_0),
        .valueToinA(valueToinA),
        .tbSum(tbSum),
        .go_l(go_l),
        .L0(LEDR[0]),
        .outResult(sum_final));

    // Adder Stream
    sumItUp DUT(
        .ck(CLOCK_50),
        .reset_l(sync_KEY_2),
        .go_l(go_l),
        .inA(valueToinA),
        .done(done),
        .sum(sum));

    // Down Stream
    downStream dStream(
        .done(done),
        .ck(CLOCK_50),
        .reset(~sync_KEY_2),
        .displayValue(sum),
        .sum(sum_final)
    );

    assign blank = 8'd0;

    // Seven Segment Display
    SevenSegmentDisplay display(.BCD3(tbSum[7:4]),
                                .BCD2(tbSum[3:0]),
                                .BCD1(sum_final[7:4]),
                                .BCD0(sum_final[3:0]),
                                .*);
endmodule: p1
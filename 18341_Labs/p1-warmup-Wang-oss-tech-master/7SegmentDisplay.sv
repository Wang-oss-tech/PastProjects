`default_nettype none

/* BCDtoSevenSegment converts a 4 bit value into a 7 bit value (segment)
   which indicates which segments should be on for its corresponding value */
module BCDtoSevenSegment
    (input logic [3:0] bcd,
     output logic [6:0] segment);

    always_comb begin
        unique case (bcd)
            // 0
            4'b0000: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 0;
                end
            
            // 1
            4'b0001: begin
                segment[0] = 0;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 0;
                segment[4] = 0;
                segment[5] = 0;
                segment[6] = 0;
                end

            // 2
            4'b0010: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 0;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 0;
                segment[6] = 1;
                end

            // 3
            4'b0011: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 0;
                segment[5] = 0;
                segment[6] = 1;
                end

            // 4
            4'b0100: begin
                segment[0] = 0;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 0;
                segment[4] = 0;
                segment[5] = 1;
                segment[6] = 1;
                end

            // 5
            4'b0101: begin
                segment[0] = 1;
                segment[1] = 0;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 0;
                segment[5] = 1;
                segment[6] = 1;
                end

            // 6
            4'b0110: begin
                segment[0] = 1;
                segment[1] = 0;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 1;
                end

            // 7
            4'b0111: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 0;
                segment[4] = 0;
                segment[5] = 0;
                segment[6] = 0;
                end

            // 8
            4'b1000: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 1;
                end

            // 9
            4'b1001: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 0;
                segment[5] = 1;
                segment[6] = 1;
                end

            // A
            4'b1010: begin
                segment[0] = 1;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 0;
                segment[6] = 1;
                end
            
            // B
            4'b1011: begin
                segment[0] = 0;
                segment[1] = 0;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 1;
                end

            // C
            4'b1100: begin
                segment[0] = 1;
                segment[1] = 0;
                segment[2] = 0;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 0;
                end 

            // D
            4'b1101: begin
                segment[0] = 0;
                segment[1] = 1;
                segment[2] = 1;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 0;
                segment[6] = 1;
                end 

            // E
            4'b1110: begin
                segment[0] = 1;
                segment[1] = 0;
                segment[2] = 0;
                segment[3] = 1;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 1;
                end 
        
            // F
            4'b1111: begin
                segment[0] = 1;
                segment[1] = 0;
                segment[2] = 0;
                segment[3] = 0;
                segment[4] = 1;
                segment[5] = 1;
                segment[6] = 1;
                end 

        endcase
   
    end
    
endmodule: BCDtoSevenSegment

/* SeventSegmentDisplay takes in seven 4 bit values and converts each into 
   its corresponding segment value (which indicates which segments should be on
   and also accounts for which segments should be off (blank) */
module SevenSegmentDisplay
    (input logic [3:0] BCD7, BCD6, BCD5, BCD4, BCD3, BCD2, BCD1, BCD0,
    input logic [7:0] blank,
    output logic [6:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);

    // retrieve seven segment values and map to appropriate hex
    logic [6:0] h7, h6, h5, h4, h3, h2, h1, h0;

    BCDtoSevenSegment b7(.bcd(BCD7), .segment(h7));
    BCDtoSevenSegment b6(.bcd(BCD6), .segment(h6));
    BCDtoSevenSegment b5(.bcd(BCD5), .segment(h5));
    BCDtoSevenSegment b4(.bcd(BCD4), .segment(h4));
    BCDtoSevenSegment b3(.bcd(BCD3), .segment(h3));
    BCDtoSevenSegment b2(.bcd(BCD2), .segment(h2));
    BCDtoSevenSegment b1(.bcd(BCD1), .segment(h1));
    BCDtoSevenSegment b0(.bcd(BCD0), .segment(h0));

    // flip hex values and account for blanks
    assign HEX7 = (blank[7]) ? 7'b111_1111 : ~h7; 
    assign HEX6 = (blank[6]) ? 7'b111_1111 : ~h6; 
    assign HEX5 = (blank[5]) ? 7'b111_1111 : ~h5; 
    assign HEX4 = (blank[4]) ? 7'b111_1111 : ~h4; 
    assign HEX3 = (blank[3]) ? 7'b111_1111 : ~h3; 
    assign HEX2 = (blank[2]) ? 7'b111_1111 : ~h2; 
    assign HEX1 = (blank[1]) ? 7'b111_1111 : ~h1; 
    assign HEX0 = (blank[0]) ? 7'b111_1111 : ~h0;

endmodule: SevenSegmentDisplay


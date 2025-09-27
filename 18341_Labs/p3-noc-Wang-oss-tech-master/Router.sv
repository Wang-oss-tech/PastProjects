`default_nettype none
`include "Router.svh"
`include "RouterPkg.pkg"

////// Network on Chip (NoC) 18-341
////// Router module

/* The Router module is designed for packet routing in a network-on-chip (NoC) architecture, 
    parameterized by a ROUTERID to distinguish between different routers in the network.*/
module Router #(parameter ROUTERID = 0) (
    input logic             clock, reset_n,

    input logic [3:0]       free_outbound,     // Node is free
    input logic [3:0]       put_inbound,       // Node is transferring to router
    input logic [3:0][7:0]  payload_inbound,   // Data sent from node to router

    output logic [3:0]      free_inbound,      // Router is free
    output logic [3:0]      put_outbound,      // Router is transferring to node
    output logic [3:0][7:0] payload_outbound); // Data sent from router to node

    logic [3:0][3:0] queue, queue_enable, QUEUE_PAUSE;
    logic [3:0] receiving_enable, QUEUE_FULL, read_enable, readReady;
    
    pkt_t [3:0] received_data, // data received from the node
                queue_output; // output of the queue, goes to the input of sender


    always_comb begin
        // Initialize queue destinations and disable all queue_enable flags
        for (int i = 0; i <= 3; i++) begin
            queue[i] = received_data[i].dest;
            for (int j = 0; j <= 3; j++) begin
                queue_enable[i][j] = 0; // Initialize all enables to zero
            end
        end
        

        // Process queue based on ROUTERID
        for (int i = 0; i < 4; i++) begin
            int queueIndex = -1; // Initialize with an invalid value

            // Determine the appropriate queue index based on ROUTERID and destination
            if (ROUTERID == 0) begin
                case (queue[i])
                    4'd0: queueIndex = 0;
                    4'd1: queueIndex = 2;
                    4'd2: queueIndex = 3;
                    default: queueIndex = 1; // For destinations >= 4'd3
                endcase
            end else if(ROUTERID == 1) begin
                case (queue[i])
                    4'd3: queueIndex = 0;
                    4'd4: queueIndex = 1;
                    4'd5: queueIndex = 2;
                    default: queueIndex = 3; // For destinations <= 4'd2
                endcase
            end

            // Enable the appropriate queue based on the determined index, if valid
            if (queueIndex != -1) begin
                queue_enable[queueIndex][i] = receiving_enable[i];
            end
        end
    end
    
    genvar i;
    generate
        for (i = 0; i <= 3; i++) begin : gen_instantiations

            // 4 receivers to transfer packet to queue 
            router_receiver #(ROUTERID, i) receiver (
                .clock(clock),
                .reset_n(reset_n),
                .QUEUE_PAUSE(QUEUE_PAUSE),
                .payload_inbound(payload_inbound[i]),
                .put_inbound(put_inbound[i]),
                .QUEUE_FULL(QUEUE_FULL),
                .free_inbound(free_inbound[i]),
                .write_enable(receiving_enable[i]),
                .received_data(received_data[i])
            );

            // 4 senders to transfer packet from queue to node
            router_sender sender_inst(
                .clock(clock), 
                .reset_n(reset_n), 
                .readReady(readReady[i]), 
                .free_outbound(free_outbound[i]), 
                .queue_output(queue_output[i]), 
                .payload_outbound(payload_outbound[i]), 
                .put_outbound(put_outbound[i]), 
                .read_enable(read_enable[i])
            );

            // internal queue between receiver and sender
            internalQueue #(i) queue(
                .clock(clock), 
                .reset_n(reset_n), 
                .received_data(received_data), 
                .queue_enable(queue_enable[i]), 
                .read_enable(read_enable[i]), 
                .QUEUE_FULL(QUEUE_FULL[i]), 
                .readReady(readReady[i]), 
                .QUEUE_PAUSE(QUEUE_PAUSE[i]), 
                .queue_output(queue_output[i])
            );
        end : gen_instantiations
    endgenerate
endmodule : Router

/* The internalQueue module functions as an intermediary storage within a router, 
managing packet buffering and prioritization based on queue availability and data flow requirements */
module internalQueue #(parameter QUEUEID = 0)(
    input logic clock, reset_n,
    input logic [3:0] queue_enable,
    input pkt_t [3:0] received_data,
    input logic read_enable,
    output pkt_t queue_output,
    output logic QUEUE_FULL, readReady,
    output logic [3:0] QUEUE_PAUSE);

    pkt_t queue_input;
    logic write_enable_FIFO;
    logic scheduled;
    logic [1:0] writePtr;

    always_comb begin
        scheduled = 0;
        write_enable_FIFO = 0;
        queue_input = '0; 
        for (int i = 0; i < 4; i++) begin
            QUEUE_PAUSE[i] = 0;
        end

        if (~QUEUE_FULL && |queue_enable) begin
            for (int i = 0; i < 4; i++) begin
                if (queue_enable[i] && !scheduled) begin
                    write_enable_FIFO = 1;
                    queue_input = received_data[i];
                    scheduled = 1;
                    break; // Exit the loop once the first enabled queue is processed
                end else if (queue_enable[i] && scheduled) begin
                    QUEUE_PAUSE[i] = 1;
                end
            end
        end
    end

    always_ff @(posedge clock or negedge reset_n) begin
        if (~reset_n) writePtr <= 0;
        else if (~|queue_enable) begin // Update writePtr when queues are not enabled
            if (QUEUEID == (1 + writePtr)) writePtr <= 2 + writePtr; // Skip next if it matches QUEUEID
            else writePtr <= 1 + writePtr; // Normal increment otherwise
        end
    end

    // Instance of the FIFO queue 
    queue_FIFO FIFO_LARGE_QUEUE(
        .clock(clock),
        .reset_n(reset_n),
        .data_in(queue_input),
        .we(write_enable_FIFO),
        .re(read_enable),
        .data_out(queue_output),
        .full(QUEUE_FULL),
        .readReady(readReady) 
    );
endmodule : internalQueue



/* Processes inbound packets to the internal queue */
module router_receiver #(parameter ROUTERID = 0, RECEIVERID = 0)(
    input logic clock, reset_n, put_inbound,
    input logic [7:0] payload_inbound,
    input logic [3:0] QUEUE_FULL,
    input logic [3:0][3:0] QUEUE_PAUSE,
    output pkt_t received_data,
    output logic write_enable, free_inbound); 

    logic [3:0] destination_node; // destination node of packet
    logic       RECEIVER_FULL; // receiver full based on queue status (correponding to destination port)
    logic       STOP_RECEIVING, receiver_count_enable, receiver_count_reset;
    logic [2:0] receiver_count;
    reg RECEIVER_FULL;

    // Append 8 bits to the packet from node to router each clock cycle
    // until packet is full
    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            received_data <= 0;
        end
        else if (put_inbound) begin
            received_data <= {received_data[31:0], payload_inbound} [31:0];
        end
    end

    // counter for receiver
    always_ff @(posedge clock, negedge reset_n) begin
        if(~receiver_count_reset) begin
            receiver_count <= 3'b0;
        end
        else if (receiver_count_enable) begin
            receiver_count <= receiver_count + 3'd1;
        end
        else begin
            receiver_count <= receiver_count;
        end
    end


    // Use always_comb to set RECEIVER_FULL based on ROUTERID and dest
    always_comb begin
        case (ROUTERID)
            0: begin // If ROUTERID is 0
                case (destination_node)
                    4'd0: RECEIVER_FULL = QUEUE_FULL[0];
                    4'd1: RECEIVER_FULL = QUEUE_FULL[2];
                    4'd2: RECEIVER_FULL = QUEUE_FULL[3];
                    default: RECEIVER_FULL = QUEUE_FULL[1];
                endcase
            end
            1: begin // If ROUTERID is 1
                case (destination_node)
                    4'd3: RECEIVER_FULL = QUEUE_FULL[0];
                    4'd4: RECEIVER_FULL = QUEUE_FULL[1];
                    4'd5: RECEIVER_FULL = QUEUE_FULL[2];
                    default: RECEIVER_FULL = QUEUE_FULL[3];
                endcase
            end
            // Add additional ROUTERID cases if necessary
            default: RECEIVER_FULL = 1'b0; // Default or safe state
        endcase
    end

    // Continuous assignment for STOP_RECEIVING, moved outside of always_comb
    assign STOP_RECEIVING = QUEUE_PAUSE[0][RECEIVERID] | 
                            QUEUE_PAUSE[1][RECEIVERID] | 
                            QUEUE_PAUSE[2][RECEIVERID] | 
                            QUEUE_PAUSE[3][RECEIVERID] | 
                            RECEIVER_FULL;

    
    router_receiver_controlPath receiver_controlPath(.clock, 
                                                     .reset_n, 
                                                     .put_inbound,
                                                     .STOP_RECEIVING,
                                                     .receiver_count,
                                                     .write_enable,
                                                     .receiver_count_enable,
                                                     .receiver_count_reset,
                                                     .free_inbound);
endmodule: router_receiver

/* Controls the traffic of packets from node to queue */
module router_receiver_controlPath #(
    parameter ROUTERID = 0, 
    parameter RECEIVERID = 0
)(
    input logic clock, 
    input logic reset_n, 
    input logic put_inbound, 
    input logic STOP_RECEIVING,
    input logic [2:0] receiver_count,
    output logic write_enable, 
    output logic receiver_count_enable, 
    output logic receiver_count_reset, 
    output logic free_inbound
);

    logic packet_ready;
    typedef enum logic [2:0] {
        START,
        LOAD,
        WRITE
    } state_t;

    state_t current_state, next_state;

    // State transition logic
    always_ff @(posedge clock or negedge reset_n) begin
        if (~reset_n) 
            current_state <= START;
        else 
            current_state <= next_state;
    end

    // Next state and output logic
    always_comb begin
        // Default assignments
        packet_ready = (receiver_count == 3'd4);
        free_inbound = 1'b1;
        write_enable = 1'b0;
        receiver_count_enable = 1'b0;
        receiver_count_reset = 1'b0;

        // Determine next state and outputs based on current state and inputs
        case (current_state)
            START: begin
                next_state = put_inbound ? LOAD : START;
                receiver_count_enable = put_inbound;
                receiver_count_reset = put_inbound;
            end
            LOAD: begin
                next_state = packet_ready ? WRITE : LOAD;
                free_inbound = 1'b0;
                receiver_count_enable = ~packet_ready;
                receiver_count_reset = 1'b1;
            end
            WRITE: begin
                next_state = STOP_RECEIVING ? WRITE : START;
                free_inbound = ~STOP_RECEIVING;
                write_enable = 1'b1;
            end
            default: begin
                next_state = START;
            end
        endcase
    end
endmodule

/* Processes outbound packets from internal queue to ports */
module router_sender(
    input logic clock, reset_n,
    input logic free_outbound, readReady,
    input pkt_t queue_output, 
    output logic [7:0] payload_outbound,
    output logic put_outbound, read_enable);


    logic sender_count_enable, sender_count_reset;
    logic [2:0] sender_count;

    // counter for sender
    always_ff @(posedge clock, negedge reset_n) begin
        if(~sender_count_reset) begin
            sender_count <= 3'b0;
        end
        else if (sender_count_enable) begin
            sender_count <= sender_count + 3'd1;
        end
        else begin
            sender_count <= sender_count;
        end
    end

    // splice packet
    logic [3:0][7:0] payload;
    always_comb begin
        payload[0] = queue_output[31:24];
        payload[1] = queue_output.data[23:16];
        payload[2] = queue_output.data[15:8];
        payload[3] = queue_output.data[7:0];
    end

    // use mux to choose segment of payload based on count
    always_comb begin
        case(sender_count)
            2'd0: payload_outbound = payload[0];
            2'd1: payload_outbound = payload[1];
            2'd2: payload_outbound = payload[2];
            2'd3: payload_outbound = payload[3];
            default: payload_outbound = 'bx;
        endcase
    end

    router_sender_controlPath senderCP(.clock,
                                       .reset_n,
                                       .free_outbound,
                                       .readReady,
                                       .sender_count,
                                       .sender_count_enable,
                                       .sender_count_reset,
                                       .put_outbound,
                                       .read_enable);
endmodule: router_sender

/* Controls the traffic of packets from queue to node */
module router_sender_controlPath(
    input logic clock, reset_n, free_outbound, readReady,
    input logic [2:0] sender_count,
    output logic sender_count_enable, sender_count_reset, put_outbound, read_enable);

    // Define state enumeration with 2-bit width
    typedef enum logic [1:0] {PENDING, SEND} state_t;
    state_t current_state, next_state;

    // Flip-flop for state transitions
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n)
            current_state <= PENDING;
        else
            current_state <= next_state;
    end

    // Logic to determine if a packet is ready to be sent
    logic packet_ready;
    assign packet_ready = (sender_count == 3'd3);

    // Combinational logic for state transitions and outputs
    always_comb begin
        // Default values
        sender_count_enable = 0;
        sender_count_reset = 0;
        put_outbound = 0;
        read_enable = 0;
        next_state = current_state; // By default, stay in the current state

        case (current_state)
            PENDING: begin
                if (free_outbound & readReady) begin
                    next_state = SEND;
                end
            end
            SEND: begin
                sender_count_enable = 1;
                sender_count_reset = 1;
                put_outbound = 1;
                if (packet_ready) begin
                    next_state = PENDING;
                    read_enable = 1;
                end
            end
        endcase
    end
endmodule

/* FIFO protocol for the internal queue in the router */
module queue_FIFO #(parameter WIDTH=32, DEPTH=8) (
    input logic              clock, reset_n,
    input logic [WIDTH-1:0]  data_in,
    input logic              we, re,
    output logic [WIDTH-1:0] data_out,
    output logic             full, readReady);

    logic [WIDTH-1:0] Q[DEPTH];
    logic [2:0] putPtr, getPtr;
    logic [3:0] count;
    logic q_not_avail;
    logic empty;

    assign empty = (count == 4'd0);
    assign full = (count == DEPTH);
    
    always_ff @(posedge clock, negedge reset_n) begin
      if (~reset_n) begin
        count <= 0;
        putPtr <= 0;
        getPtr <= 0;
        q_not_avail <= 0;
        readReady <= 0;
      end
      else begin
        // Handle read (re) and write (we) operations while considering queue status (empty, q_not_avail)
        if (re) begin
            if (empty) begin
                // Case: Read when queue is  empty
                if (q_not_avail) begin
                    if (we) begin
                        // Case: Read & Write when queue is empty and not available
                        q_not_avail <= 1;
                        data_out <= data_in;
                        readReady <= 1;
                    end else begin
                        // Case: Read when queue is empty, not available, and no write
                        readReady <= 0;
                        q_not_avail <= 0;
                    end
                end
            end else begin
                // Case: Read when queue is not empty
                if (we && q_not_avail) begin
                    // Case: Read & Write when queue is not empty and not available
                    readReady <= 1;
                    data_out <= Q[getPtr];
                    q_not_avail <= 1;
                    getPtr <= (getPtr + 1'd1) % DEPTH;
                    Q[putPtr] <= data_in;
                    putPtr <= (putPtr + 1'd1) % DEPTH;
                end else begin
                    // Case: Read only, queue not empty
                    data_out <= Q[getPtr];
                    q_not_avail <= 1;
                    getPtr <= (getPtr + 1'd1) % DEPTH;
                    count <= count - 1'd1;
                    readReady <= 1;
                end
            end
        end else if (we && (!full)) begin
            // Handle write operations when queue is not full
            if (q_not_avail) begin
                count <= count + 1'd1;
                Q[putPtr] <= data_in;
                putPtr <= (putPtr + 1'd1) % DEPTH;
            end else begin
                q_not_avail <= 1;
                data_out <= data_in;
                readReady <= 1;
            end
        end

      end
    end
endmodule : queue_FIFO
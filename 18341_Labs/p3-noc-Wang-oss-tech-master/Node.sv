`default_nettype none
`include "Router.svh"
`include "RouterPkg.pkg"

//////
////// Network on Chip (NoC) 18-341
////// Node module
//////
module Node #(parameter NODEID = 0) (
  input logic clock, reset_n,

  //Interface to testbench: the blue arrows
  input  pkt_t pkt_in,        // Data packet from the TB
  input  logic pkt_in_avail,  // The packet from TB is available (up for one clk period when !cQ_full)
  output logic cQ_full,       // The queue is full (cq_full, pkt_in cannot be asserted in here)
  output pkt_t pkt_out,       // Outbound packet from node to TB
  output logic pkt_out_avail, // The outbound packet is available (when all 32 bits become available)

  //Interface with the router: black arrows
  input  logic       free_outbound,    // Router is free
  output logic       put_outbound,     // Status signal - Node is transferring to router
  output logic [7:0] payload_outbound, // Data sent from node to router

  output logic       free_inbound,     // Node is free
  input  logic       put_inbound,      // Status signal - Router is transferring to node
  input  logic [7:0] payload_inbound); // Data sent from router to node

  logic [31:0] data_out;
  logic get_enable, queue_empty;

  // Instantiation of FIFO
  FIFO queueFIFO (.clock,
                  .reset_n,
                  .data_in(pkt_in),
                  .we(pkt_in_avail),
                  .re(get_enable),
                  .data_out,
                  .full(cQ_full),
                  .empty(queue_empty));

  // node to router (packet in, payload out)
  nodeToRouter nodeToRouter (.packet_inbound(data_out),
                             .reset_n,
                             .clock,
                             .get_enable,
                             .pkt_to_router_avail(~queue_empty), // queue is not empty
                             .put_outbound,
                             .free_outbound,
                             .payload_outbound);

  // router to node (pcket output, payload input)
  routerToNode routerToNode (.packet_outbound(pkt_out), 
                             .payload_inbound, 
                             .reset_n,
                             .clock,
                             .put_inbound,
                             .pkt_out_avail,
                             .free_inbound);
endmodule : Node

/*
 *  Create a FIFO (First In First Out) buffer with depth 4 using the given
 *  interface and constraints
 *    - The buffer is initally empty
 *    - Reads are combinational, so data_out is valid unless empty is asserted
 *    - Removal from the queue is processed on the clock edge.
 *    - Writes are processed on the clock edge
 *    - If a write is pending while the buffer is full, do nothing
 *    - If a read is pending while the buffer is empty, do nothing
 */
module FIFO #(parameter WIDTH=32) (
    input logic              clock, reset_n,
    input logic [WIDTH-1:0]  data_in,
    input logic              we, re,
    output logic [WIDTH-1:0] data_out,
    output logic             full, empty);

    // FIFO Storage & Pointers
    logic [31:0] Q[4]; // FIFO Buffer with depth of 4 and bit width of 32
    logic [1:0] putPtr, getPtr; // 2 bits for overflowing purposes
    logic [2:0] count;

    // Combination Logic
    always_comb begin
      // 1) Defining full and empty signals
      if (!re && count == 3'd4) begin
        full = 1'b1;
      end else begin
        full = 1'b0;
      end
      empty = (count == 0);
      // 2) Combinationally reading queue 
      //    based on position of read/get pointer,
      //    if empty asserted, values are not valid
      data_out = empty ? {WIDTH{1'b0}} :Q[getPtr];
    end

    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            // Reset logic clears the FIFO pointers and count
            putPtr <= 0;
            getPtr <= 0;
            count <= 0;
        end else begin
            // Simultaneous read and write operation
            if (we && re && !full && !empty) begin
                // Writing the incoming data and advancing both pointers without changing the count
                Q[putPtr] <= data_in;
                putPtr <= (putPtr + 1) & 2'b11; // Using bitwise AND for circular logic, equivalent to % 4
                getPtr <= (getPtr + 1) & 2'b11;
            end else if (we && !full) begin
                // Write operation when FIFO is not full
                Q[putPtr] <= data_in;
                putPtr <= (putPtr + 1) & 2'b11; // Incrementing the write pointer
                count <= count + 1; // Incrementing the count as a new item is added
            end
            
            if (re && !empty && !(we && !full && !empty)) begin
                // Read operation, with an additional check to avoid decrementing count 
                // when a simultaneous write operation occurred and FIFO was not full
                getPtr <= (getPtr + 1) & 2'b11; // Incrementing the read pointer
                count <= count - 1; // Decrementing the count as an item is removed
            end
        end
    end

endmodule : FIFO

// Control Path from Node To Router
module controlPath 
  (input logic  pkt_to_router_avail, free_outbound, reset_n, clock,
   output logic [2:0] count,
   output logic put_outbound, get_enable);

  enum logic [1:0] {WAIT, READ, SEND} s, nS;

  // Consolidated always_ff block
  always_ff @(posedge clock,  negedge reset_n) begin
    if(!reset_n) begin
      s <= WAIT;
      count <= 0;
    end 
    else begin
      s <= nS;
      if ((count == 3'd4) || 
          (s == SEND) || 
          (s == READ && free_outbound))
          count <= count + 1;
      else 
          count <= 0;
    end
  end

  // Next State and Output Logic
  always_comb begin
    case (s)
      WAIT: begin
        // Output
        get_enable = 1'b1;
        put_outbound = 1'b0;

        // Next State
        if(pkt_to_router_avail) begin
          nS = READ;
        end 
        else begin
          nS = WAIT;
        end
      end
      
      SEND: begin
        // Counter to determine node is transferring to router (put_outbound)
        if (count > 0 && count < 5) put_outbound = 1'b1;
        else put_outbound = 1'b0;

        if (count == 3'd4 && pkt_to_router_avail) begin
          nS = READ;
          get_enable = 1'b1;
        end
        else if (count == 3'd4 && !pkt_to_router_avail) begin
          nS = WAIT;
          get_enable = 1'b1;
        end
        else begin
          get_enable = 1'b0;
          nS = SEND;
        end
      end

      READ: begin
        // Output
        if (count > 0 && count < 5) put_outbound = 1'b1;
        else put_outbound = 1'b0;
        get_enable = 1'b0;

        // Next State
        if (free_outbound) begin
          nS = SEND;
        end
        else begin
          nS = READ;
        end
      end

    endcase
  end
endmodule: controlPath


module nodeToRouter (
    input  logic [31:0] packet_inbound,      // 32-bit inbound packet for transmission
    input  logic        reset_n, clock,      // System reset and clock signals
    input  logic        pkt_to_router_avail, // Indicator if packet is available for router
    input  logic        free_outbound,       // Indicates if router is ready to receive data
    output logic        put_outbound,        // Signal to start data transfer to router
    output logic        get_enable,          // Signal to fetch and send next packet segment
    output logic [7:0]  payload_outbound     // 8-bit data segment being sent to router
);

    logic [2:0] segment_index; // Tracks which 8-bit segment of the packet is being sent
    logic [31:0] packet_buffer; // Temporary storage for the packet being sent

    // Control logic for packet transmission
    controlPath control_fsm (
        .clock(clock),
        .reset_n(reset_n),
        .pkt_to_router_avail(pkt_to_router_avail),
        .free_outbound(free_outbound),
        .put_outbound(put_outbound),
        .get_enable(get_enable),
        .count(segment_index)
    );

    // Load packet into buffer and manage buffer state
    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            packet_buffer <= 0; // Clear packet buffer on reset
        end else if (get_enable) begin
            // Load the inbound packet into the buffer when enabled
            packet_buffer <= packet_inbound;
        end
    end

    // Determine which segment of the packet to send based on the current segment index
    always_comb begin
        // Select the appropriate 8-bit segment from the packet buffer
        case (segment_index)
            3'd1: payload_outbound = packet_buffer[31:24]; // First segment to send
            3'd2: payload_outbound = packet_buffer[23:16]; // Second segment
            3'd3: payload_outbound = packet_buffer[15:8];  // Third segment
            3'd4: payload_outbound = packet_buffer[7:0];   // Fourth and last segment
            default: payload_outbound = 8'b0;              // Default state when idle
        endcase
    end

endmodule : nodeToRouter


// The routerToNode module is designed to receive data packets from a router 8 bits at a time.
// Once a complete 32-bit packet has been assembled, it signals that the packet is available.
module routerToNode(
    input  logic [7:0] payload_inbound, // Incoming 8-bit data from the router
    input  logic reset_n,               // Active low reset
    input  logic clock,                 // System clock
    input  logic put_inbound,           // Signal indicating data is being transferred to the node
    output logic pkt_out_avail,         // Signal indicating a complete packet is available
    output logic free_inbound,          // Signal indicating the node is ready to receive data
    output logic [31:0] packet_outbound // Assembled 32-bit data packet
);

    // Logic to determine when a complete packet is available.
    // A packet is considered available when there is no ongoing data transfer
    // to the node and the node is not ready to receive new data.
    always_comb begin
        pkt_out_avail = ~(put_inbound || free_inbound);
    end

    // Sequential logic for assembling the 32-bit packet from 8-bit segments
    // and managing the node's ability to receive more data.
    always_ff @(posedge clock, negedge reset_n) begin
        if (!reset_n) begin
            // On reset, clear the packet buffer and indicate the node is ready to receive data.
            packet_outbound <= 32'd0;
            free_inbound <= 1'b1;
        end
        else if (~put_inbound) begin
            // When not receiving data (transaction done), mark the node as ready to receive.
            free_inbound <= 1'b1;
        end
        else if (put_inbound) begin
            // When receiving data, append the incoming 8-bit segment to the packet buffer
            // and indicate that the node is busy (not ready to receive more data).
            packet_outbound <= {packet_outbound[23:0], payload_inbound};
            free_inbound <= 1'b0; // Node is busy receiving data.
        end
    end
endmodule : routerToNode
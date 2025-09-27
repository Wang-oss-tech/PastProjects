`ifndef USB_H
  `define USB_H

  `define TRUE 1
  `define FALSE 0

  // USB field lengths
  `define SYNC_BITS 8
  `define PID_BITS 4
  `define ENDP_BITS 4
  `define ADDR_BITS 7
  `define PAYLOAD_BITS 64
  `define CRC5_BITS 5
  `define CRC16_BITS 16
  `define EOP_BITS 3

  // Some common USB values
  `define SYNC 8'b00000001
  //Below is for prelab
  // `define DEVICE_ADDR 7'h3F
  //Below is for final
  `define DEVICE_ADDR 7'h5
  `define ADDR_ENDP 4'h4
  `define DATA_ENDP 4'h8
  `define CRC16_RESIDUE 16'h80_0d
  `define CRC5_RESIDUE 5'h0c
  `define LAST_ADDR 16'hffff
  `define TIMEOUT 256
  `define STUFF_LENGTH 7
  `define TX_RETRIES 7
  `define MAX_PKT_SIZE_NO_EOP 80
  // the maximum number of bits in a packet is no more than 2^7
  `define COUNT_BITS 7
`endif

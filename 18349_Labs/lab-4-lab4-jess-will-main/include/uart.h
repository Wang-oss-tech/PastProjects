/**
 * @file uart.h
 *
 * @brief UART Communication Function Prototypes
 *
 * This header file declares function prototypes for initializing,
 * transmitting, and receiving data through UART communication.
 *
 * @date 10/29/2023
 * @author William Wang (www2) and Jessica Chan (jchan4)
 * 
 */

#ifndef _UART_H_
#define _UART_H_

void uart_init(int baud);

int uart_put_byte(char c);

int uart_get_byte(char *c);

int uart_write(int file, char *ptr, int len);

int uart_read(int file, char *ptr, int len);

#endif /* _UART_H_ */

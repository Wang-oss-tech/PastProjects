/**
 * @file uart_polling.h
 *
 * @brief UART Communication Function Prototypes (Polling)
 *
 * This header file declares function prototypes for initializing and 
 * utilizing UART communication in polling mode. It provides functions for
 * initialization, transmitting and receiving single bytes, and sending strings.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */


#ifndef _UART_POLLING_H_
#define _UART_POLLING_H_

void uart_polling_init(int baud);

void uart_polling_put_byte(char c);

char uart_polling_get_byte();

#endif /* _UART_POLLING_H_ */

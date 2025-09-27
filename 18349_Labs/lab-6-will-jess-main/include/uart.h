/**
 * @file
 *
 * @brief
 *
 * @date
 *
 * @author
 */

#ifndef _UART_H_
#define _UART_H_

/** @brief  Built-in file descriptors */
//@{
#define FD_STDIN 0
#define FD_STDOUT 1
//@}

void uart_init(int baud);

int uart_put_byte(char c);

int uart_get_byte(char *c);

int uart_write( int file, char *ptr, int len );

int uart_read(int file, char *ptr, int len );

#endif /* _UART_H_ */

#ifndef _UART_POLLING_H_
#define _UART_POLLING_H_


void uart_polling_init (int baud);
void uart_polling_put_byte (char c);
char uart_polling_get_byte ();
void uart_put_string(char* input);

#endif /* _UART_POLLING_H_ */

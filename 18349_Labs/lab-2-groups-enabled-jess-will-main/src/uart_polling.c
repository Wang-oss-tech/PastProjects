/* uart_polling.c :  This code implements functions to initialize, transmit, and receive data 
    via a UART module on a microcontroller. It includes register mappings and configurations 
    specific to the UART module.*/
    
#include <gpio.h>
#include <rcc.h>
#include <unistd.h>
#include <uart_polling.h>
#include <stdio.h>

/** @brief The UART register map. */
struct uart_reg_map {
    volatile uint32_t SR;   /**< Status Register */
    volatile uint32_t DR;   /**<  Data Register */
    volatile uint32_t BRR;  /**<  Baud Rate Register */
    volatile uint32_t CR1;  /**<  Control Register 1 */
    volatile uint32_t CR2;  /**<  Control Register 2 */
    volatile uint32_t CR3;  /**<  Control Register 3 */
    volatile uint32_t GTPR; /**<  Guard Time and Prescaler Register */
};

/** @brief Baud rate */
#define USART_BRR 0x8B
// USART_BRR value is 0x8B
// USARTDIV value is 8.68

/** @brief Base address for UART2 */
#define UART2_BASE  (struct uart_reg_map *) 0x40004400

/** @brief Enable  Bit for UART Config register */
#define UART_EN (1 << 13)
#define UART_TRANSMITTER_EN (1 << 3)
#define UART_RECEIVER_EN (1 << 2)

/** @brief Enable Bit for Clock register */
#define UART_CLOCK_EN (1 << 17)

/** @brief 7th bit - Transmit Data Register (TXE)
 * 1 - data is transferred
 * 0 - data is not transferred
 * 0x00000040
*/
#define TXE (1 << 7)

/** @brief 5th bit - Read Data Register (RXNE)
 * 1 - received data is ready to be read
 * 0 - data is not yet received
 * 0x00000010 
*/
#define RXNE (1 << 5)


/**
 * @brief initializes UART to given baud rate with 8-bit word length, 1 stop bit, 0 parity bits
 *
 * @param baud Baud rate
 */
void uart_polling_init (int baud){
    (void) baud; 

    // set clock before initializing
    struct rcc_reg_map *uart_clock = RCC_BASE;
    uart_clock->apb1_enr |= UART_CLOCK_EN;

    // define base address for uart
    struct uart_reg_map *uart = UART2_BASE;

    // initialize GPIO pins
    gpio_init(GPIO_A, 2, MODE_ALT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT7); // TX line
    gpio_init(GPIO_A, 3, MODE_ALT, OUTPUT_OPEN_DRAIN, OUTPUT_SPEED_LOW, PUPD_NONE, ALT7); // RX line

    // Enable bits in UART
    uart->CR1 |= UART_TRANSMITTER_EN;
    uart->CR1 |= UART_RECEIVER_EN;
    uart->BRR = USART_BRR;
    uart->CR1 |= UART_EN;
    return;
}

/**
 * @brief transmits a byte over UART
 *
 * @param c character to be sent
 */
void uart_polling_put_byte (char c){    
    struct uart_reg_map *uart = UART2_BASE;
    // wait to turn empty (1)
    while ((uart->SR & TXE) == 0) { // while full
        ; // do nothing
    } 
    uart->DR = c;
    return;
}

/**
 * @brief receives a byte over UART
 * 
 */
char uart_polling_get_byte (){
    struct uart_reg_map *uart = UART2_BASE;
    // wait for regiter to have something in it
    while ((uart->SR & RXNE) == 0) { // while empty
        ; // do nothing
    }
    return uart->DR;
}

/**
 * @brief UART helper function to put strings onto uart
 * 
 * @param input string to sent to UART
 */
void uart_put_string(char* input){
    int i = 0;
    while (input[i]!= '\0'){
        uart_polling_put_byte(input[i]);
        i++;
    }
}
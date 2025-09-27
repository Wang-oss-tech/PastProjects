/**
 * @file uart.c
 *
 * @brief This code implements functions to initialize, transmit, and receive data 
    via a UART module on a microcontroller. It includes register mappings and configurations 
    specific to the UART module and is now modified to an interrupt version 
 *
 * @date 10/24/2023
 *
 * @author William Wang (www2) Jessica Chan (jchan4)
 */

#include <unistd.h>
#include <rcc.h>
#include <uart.h>
#include <nvic.h>
#include <gpio.h>
#include <stdio.h>
#include <lcd_driver.h>

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

/** @brief Flag indicating if the TRANSMIT queue is full (1 for full, 0 for not full) */
volatile int TRANSMITfull;

/** @brief Flag indicating if the TRANSMIT queue is empty (1 for empty, 0 for not empty) */
volatile int TRANSMITempty;

/** @brief Index indicating the position for buffering in the TRANSMIT queue */
volatile int TRANSMITindex_buff;

/** @brief Index indicating the position for handling in the TRANSMIT queue */
volatile int TRANSMITindex_handler;

/** @brief Size of the TRANSMIT queue */
volatile int TRANSMITsize;

/** @brief Array to store characters in the TRANSMIT queue */
volatile char TRANSMITqueue[16];

/** @brief Flag indicating if the RECEIVE queue is full (1 for full, 0 for not full) */
volatile int RECEIVEfull;

/** @brief Flag indicating if the RECEIVE queue is empty (1 for empty, 0 for not empty) */
volatile int RECEIVEempty;

/** @brief Index indicating the position for buffering in the RECEIVE queue */
volatile int RECEIVEindex_buff;

/** @brief Index indicating the position for handling in the RECEIVE queue */
volatile int RECEIVEindex_handler;

/** @brief Size of the RECEIVE queue */
volatile int RECEIVEsize;

/** @brief Array to store characters in the RECEIVE queue */
volatile char RECEIVEqueue[16];

/** @brief Baud rate */
#define USART_BRR 0x8B

/** @brief Base address for UART2 */
#define UART2_BASE  (struct uart_reg_map *) 0x40004400

/** @brief Enable  Bit for UART Config register */
#define UART_EN (1 << 13)

/** @brief Bit mask for enabling the UART transmitter */
#define UART_TRANSMITTER_EN (1 << 3)

/** @brief Bit mask for enabling the UART receiver */
#define UART_RECEIVER_EN (1 << 2)


/** @brief Enable Bit for Clock register */
#define UART_CLOCK_EN (1 << 17)

/** @brief 7th bit - Transmit Data Register (TXE)
*/
#define TXE (1 << 7)

/** @brief 5th bit - Read Data Register (RXNE)*/
#define RXNE (1 << 5)

/** @brief &th bit - Transmit Interrupt enable bit (TXIE)
    0: Interrupt is inhibited
    1: An USART interrupt is generated whenever TXE=1 in the USART_SR register
*/
#define TXIE (1 << 7)

/** @brief 5th bit - Receiver Interrupt enable bit (RXNEIE)
    0: Interrupt is inhibited
    1: An USART interrupt is generated whenever ORE=1 or RXNE=1 in the USART_SR register
*/
#define RXNEIE (1 << 5)


/** @brief Transmit State - empty */
#define EMPTY 0

/** @brief Transmit State - full */
#define FULL 16



/** @brief UART IRQ_HANDLER NUMBER for NVIC */
#define UART_IRQ_NUMBER 38

/** @brief Attribute for indicating that a variable is intentionally unused */
#define UNUSED __attribute__((unused))


/**
 * @brief Initializes UART with specified baud rate and configures GPIO pins.
 *
 * This function sets up the UART module for data transmission and reception.
 * It configures the clock, GPIO pins, and enables the necessary UART settings.
 *
 * @param baud The desired baud rate for UART communication.
 */
void uart_init(int baud) {
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

    // Initialize Transmit Buffer Parameters
    TRANSMITsize = 0;
    TRANSMITindex_buff = 0;
    TRANSMITindex_handler = 0;
    TRANSMITempty = 1;
    TRANSMITfull = 0;

    // Initialize Receive Buffer Parameters
    RECEIVEsize = 0;
    RECEIVEindex_buff = 0;
    RECEIVEindex_handler = 0;
    RECEIVEempty = 1;
    RECEIVEfull = 0;

    uart->CR1 |= RXNEIE;
    nvic_irq(UART_IRQ_NUMBER, IRQ_ENABLE); // enable nvic

    return;
}


/**
 * @brief Puts a byte into the UART transmit buffer for asynchronous transmission.
 *
 * This function attempts to place a byte into the UART transmit buffer for later
 * asynchronous transmission. If the buffer is full, the function returns -1.
 *
 * @param c The character to be transmitted.
 * @return 0 on success, -1 if the transmit buffer is full.
 */
int uart_put_byte(char c) {
    nvic_irq(UART_IRQ_NUMBER, IRQ_DISABLE); // Disable UART interrupts

    if (TRANSMITfull) {
        nvic_irq(UART_IRQ_NUMBER, IRQ_ENABLE); // Enable UART interrupts
        return -1; // Return -1 if the transmit buffer is full
    }

    // Place the byte in the transmit queue
    TRANSMITqueue[TRANSMITindex_buff] = c;
    TRANSMITindex_buff = (TRANSMITindex_buff + 1) % 16; // Update buffer index
    TRANSMITsize++; // Update buffer size

    // Enable the transmit interrupt in UART control register
    struct uart_reg_map *uart = UART2_BASE;
    uart->CR1 |= TXIE;

    TRANSMITempty = (TRANSMITsize == EMPTY); // Update buffer empty flag
    TRANSMITfull = (TRANSMITsize == FULL); // Update buffer full flag

    nvic_irq(UART_IRQ_NUMBER, IRQ_ENABLE); // Re-enable UART interrupts
    return 0; // Return 0 to indicate successful byte placement in the transmit queue
}


/**
 * @brief Gets a byte from the UART receive buffer for asynchronous reception.
 *
 * This function attempts to retrieve a byte from the UART receive buffer for later
 * asynchronous processing. If the buffer is empty, the function returns -1.
 *
 * @param c Pointer to a character variable where the received byte will be stored.
 * @return 0 on success, -1 if the receive buffer is empty.
 */
int uart_get_byte(char *c) {
    nvic_irq(UART_IRQ_NUMBER, IRQ_DISABLE); // Disable UART interrupts

    if (RECEIVEempty) {
        nvic_irq(UART_IRQ_NUMBER, IRQ_ENABLE); // Enable UART interrupts
        return -1; // Return -1 if the receive buffer is empty
    }

    // Retrieve the next byte from the receive queue
    *c = RECEIVEqueue[RECEIVEindex_buff];
    RECEIVEindex_buff = (RECEIVEindex_buff + 1) % 16; // Update buffer index
    RECEIVEsize--; // Update buffer size

    RECEIVEempty = (RECEIVEsize == EMPTY); // Update buffer empty flag
    RECEIVEfull = (RECEIVEsize == FULL); // Update buffer full flag

    nvic_irq(UART_IRQ_NUMBER, 1); // Re-enable UART interrupts
    return 0; // Return 0 to indicate successful byte retrieval
}


/**
 * @brief Writes data to the UART for asynchronous transmission.
 *
 * This function writes a specified number of bytes from the provided buffer to the UART
 * for asynchronous transmission. It is designed to be compatible with the standard output
 * file descriptor (file = 1). If the file descriptor is not stdout (file != 1), the function
 * returns -1 without performing any actions.
 *
 * @param file File descriptor (1 for stdout).
 * @param ptr Pointer to the data buffer.
 * @param len Number of bytes to write.
 * @return 0 on success, -1 if the file descriptor is not stdout.
 */

int uart_write(int file, char *ptr, int len) {
    if (file != 1) return -1; // check that file is stdout, failure (-1) if not
    for(int i = 0; i < len; i++){
        while(uart_put_byte(ptr[i]) == -1);
    }
    return 0; // success in uart_arite
}

/**
 * @brief Reads data from the UART for asynchronous reception.
 *
 * This function reads a specified number of bytes from the UART for asynchronous reception.
 * It is designed to be compatible with the standard input file descriptor (file = 0). If the
 * file descriptor is not stdin (file != 0), the function returns -1 without performing any actions.
 * Special handling is provided for certain control characters: End of Transmission (Ctrl-D), Backspace (Ctrl-H),
 * and newline characters. The function returns the number of bytes read.
 *
 * @param file File descriptor (0 for stdin).
 * @param ptr Pointer to the data buffer for storing received bytes.
 * @param len Maximum number of bytes to read.
 * @return Number of bytes read, or -1 if the file descriptor is not stdin.
 */
int uart_read(int file, char *ptr, int len) {
    if (file != 0) return -1; // checks that file is stdin

    int i = 0;
    while (i < len) {
        while(uart_get_byte(&ptr[i]) == -1);
        if (ptr[i] == 4) { // return count when character equals to 4
            return i;
        } else if (ptr[i] == '\b'){ // backspace case
            while(uart_put_byte('\b') == -1);
            while(uart_put_byte(' ') == -1);
            while(uart_put_byte('\b') == -1);
            if (i != 0) i--;
        } else if (ptr[i] == '\n' || ptr[i] == '\r'){ // new line case
            while(uart_put_byte('\r') == -1); // echo back
            while(uart_put_byte('\n') == -1); // echo back
            i++;
            return i;
        } else { // non-special character
            while(uart_put_byte(ptr[i]) == -1);
            i++;
        }   
    }
    return 0;
}


/**
 * @brief Handles UART interrupts for both transmission and reception.
 *
 * This function is the interrupt service routine (ISR) for UART. It handles both transmission and reception
 * events. When the transmit data register (DR) is empty and there is data in the transmit queue, it sends
 * the next byte. When a byte is received, it is placed in the receive queue. The function also manages the
 * state of transmit and receive buffers, updating their indices and sizes accordingly.
 */
void uart_irq_handler() {
    struct uart_reg_map *uart = UART2_BASE; // define uart struct
    char temp;
    
    nvic_irq(UART_IRQ_NUMBER, 0); // disable nvic

    // transmit handling
    if ((uart->SR & TXE) && !TRANSMITempty) {
        //asm("bkpt"); 
        temp = TRANSMITqueue[TRANSMITindex_handler];
        uart->DR = temp;
        TRANSMITindex_handler = (TRANSMITindex_handler + 1) % 16;
        TRANSMITsize--;
        if (TRANSMITsize == 0) 
            uart->CR1 = (uart->CR1 & ~TXIE); // disable transmitting
        TRANSMITempty = (TRANSMITsize == EMPTY);
        TRANSMITfull = (TRANSMITsize == FULL);
    }
    
    // receive handling
    if ((uart->SR & RXNEIE) && !RECEIVEfull) { 
        RECEIVEqueue[RECEIVEindex_handler] = uart->DR;
        RECEIVEindex_handler = (RECEIVEindex_handler + 1) % 16;
        RECEIVEsize++;
        RECEIVEempty = (RECEIVEsize == EMPTY);
        RECEIVEfull = (RECEIVEsize == FULL);
    }

    nvic_clear_pending(UART_IRQ_NUMBER);
    nvic_irq(UART_IRQ_NUMBER, 1); // enable nvic
}



/**
 * @file i2c.c
 *
 * @brief I2C Communication Functions
 *
 * This source file contains functions for initializing and communicating
 * using the I2C protocol in master mode. It provides functions for
 * initialization, starting, stopping, and writing data to an I2C slave device.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */

#include <gpio.h>
#include <i2c.h>
#include <unistd.h>
#include <rcc.h>

/** @brief Enable Bit for Clock register */
#define CLOCK_EN (1 << 17)


/**
 * @struct i2c_reg_map
 * @brief I2C register map structure
 */
struct i2c_reg_map {
    volatile uint32_t I2C_CR1;  /**< Control Register 1 */
    volatile uint32_t I2C_CR2;  /**< Control Register 2*/
    volatile uint32_t I2C_OAR1; /**< Own Address Register 1 */
    volatile uint32_t I2C_OAR2; /**< Own Address Register 2 */
    volatile uint32_t I2C_DR;   /**< Data Register */
    volatile uint32_t I2C_SR1;  /**< Status Register 1 */
    volatile uint32_t I2C_SR2;  /**< Status Register 2 */
    volatile uint32_t I2C_CCR;  /**< Clock Control Register */
    volatile uint32_t I2C_TRISE;/**< Trise Register*/
    volatile uint32_t I2C_FLTR; /**< FLTR Register*/
};

// Definitions 
/** @brief Base Address of the I2C */
#define I2C_BASE (struct i2c_reg_map *) 0x40005400


/** @brief I2C Start Bit CR1 */
#define I2C_C1_START (1 << 8)

/** @brief I2C Stop Bit CR1 */
#define I2C_C1_STOP (1 << 9)

/** @brief I2C Stop Bit SR1 */
#define I2C_SR1_STOPF (1 << 4)

/** @brief I2C SR1 TxE bit*/
#define I2C_SR1_TXE (1 << 7)

/** @brief I2C SR1 BTF bit*/
// 0: DR empty
// 1: DR not empty
#define I2C_SR1_BTF (1 << 2)

/** @brief I2C SR1 ADDR bit*/
#define I2C_SR1_ADDR (1 << 1)

/** @brief I2C Peripheral Enable */
#define I2C_PE 1

/** @brief Peripheral clock enable bit*/
#define I2C_CLK (1 << 21)

/** @brief CCR Constant value*/
#define I2C_CCR_VAL  0x50 

/** @brief Acknowledge bit of the I2C Communication Protocol*/
#define I2C_ACK (1 << 10) 


/**
 * @brief Initializes the I2C communication as a master.
 *
 * This function initializes the I2C peripheral as a master with the specified clock speed.
 *
 * @param clk The desired clock speed for I2C communication.
 */
void i2c_master_init(uint16_t clk) {
    (void) clk; 
               
    // define base address for I2C
    struct i2c_reg_map *I2C = I2C_BASE;

    struct rcc_reg_map *i2c_clock = RCC_BASE;
    i2c_clock->apb1_enr |= I2C_CLK;

    // Initialize SCL and SDA pins
    gpio_init(GPIO_B, 8, MODE_ALT, OUTPUT_OPEN_DRAIN, OUTPUT_SPEED_LOW, PUPD_NONE, ALT4); // SCL
    gpio_init(GPIO_B, 9, MODE_ALT, OUTPUT_OPEN_DRAIN, OUTPUT_SPEED_LOW, PUPD_NONE, ALT4); // SDA

    // Enable bits in I2C
    I2C->I2C_CR2 |= 0x10; //16 MHz clock frequency as mentioned in the handout
    I2C->I2C_CCR = I2C_CCR_VAL;
    I2C->I2C_CR1 |= I2C_ACK;
    I2C->I2C_CR1 |= I2C_PE;
    return;
}

/**
 * @brief Initiates a start condition for I2C communication.
 *
 * This function sends a start condition on the I2C bus.
 */
void i2c_master_start() {
    struct i2c_reg_map *I2C = I2C_BASE;
    I2C->I2C_CR1 |= I2C_C1_START; // set control bit = 1 == start bit

    // EV5
    while ((I2C->I2C_SR1 & 1) == 0); // start bit not set, do nothing
    return;
}


/** @brief: Stops I2C, implemented by activating stop bit in I2C
 * 
 */
void i2c_master_stop() {
    struct i2c_reg_map *I2C = I2C_BASE;

    // EV8_2
    while(!((I2C->I2C_SR1 & I2C_SR1_TXE) || (I2C->I2C_SR1 & I2C_SR1_BTF)));
    I2C->I2C_CR1 |= I2C_C1_STOP;
    
    return;
}

/** @brief: Write to input buffer to slave address
 * 
 * @param buf is the buffer of the data, 
 * @param len is the length of the buffer
 * @param slave_addr is where the i2c address is supposed to write to
 *        
 */
int i2c_master_write(uint8_t *buf, uint16_t len, uint8_t slave_addr){
    i2c_master_start();
    struct i2c_reg_map *I2C = I2C_BASE;

    // finish EV5 - sending the slave address // DOUBLE CHECK WITH TA
    I2C->I2C_DR = (slave_addr << 1);

    // EV6
    while((I2C->I2C_SR1 & I2C_SR1_ADDR) == 0) ; // wait for addr to be set to 1
    uint16_t sr2_r = I2C->I2C_SR2;
    (void)sr2_r;

    // EV8_1
    while((I2C->I2C_SR1 & I2C_SR1_TXE) == 0) ; // waitin for TXE to be set to 1

    // iterate sending data and EV8
    for (int i = 0; i < len; i++) {
        I2C->I2C_DR = buf[i]; // writing data
        while((I2C->I2C_SR1 & I2C_SR1_TXE) == 0) ; // EV8
    }
    i2c_master_stop();

    for (int wait = 0; wait < 10000; wait++);
    return 0;
}

/** @brief unused function, must stay on file per instructions */
int i2c_master_read(uint8_t *buf, uint16_t len, uint8_t slave_addr) {
    (void) buf;
    (void) len;
    (void) slave_addr;
    return 0;
}

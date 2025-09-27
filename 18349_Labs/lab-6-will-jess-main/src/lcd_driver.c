/**
 * @file lcd_driver.c
 *
 * @brief LCD driver functions for initialization, printing, cursor control, and clearing display.
 *
 * This file provides functions to initialize the LCD, print strings, set cursor position, and clear the display.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */
    
#include <i2c.h>
#include <lcd_driver.h>
#include <unistd.h>
#include <FreeRTOS.h>
#include <task.h>


/** @brief I2C Slave Address for the LCD */
#define SLAVE_ADDR_VAL (0x4E >> 1)

/** @brief Bit mask for the backlit control (always set to 1) */
#define P3 (1 << 3) // backlit always 1

/** @brief Bit mask for the Enable pin */
#define EN (1 << 2)

/** @brief Bit mask for the Disable pin */
#define NOT_EN (0 << 2)

/** @brief Bit mask for write operation */
#define WRITE (0  << 1)

/** @brief Bit mask to set the RS (Register Select) pin */
#define RS_SET (1)

/* Structure of sending bits: */
/* [higher/lower | back_lit bit | EN/NOT_EN | R/W | RS_Bit] */

/** @brief: Initialize LCD Driver 
 * 
*/
void lcd_driver_init() {
    /* shift register by 1 bit to the right before 
    inputting it into i2c_master_write */
    i2c_master_init((uint16_t)34468);

    uint8_t buf1[4];
    buf1[0] = (0x30 | P3 | EN);
    buf1[1] = (0x30 | P3 | NOT_EN);
    buf1[2] = (0x00 | P3 | EN);
    buf1[3] = (0x00 | P3 | NOT_EN);
    
    uint8_t buf2[4];
    buf2[0] = (0x20 | P3 | EN);
    buf2[1] = (0x20 | P3 | NOT_EN);
    buf2[2] = (0x00 | P3 | EN);
    buf2[3] = (0x00 | P3 | NOT_EN);

    // sets up LCD
    // systick_delay(15);
    vTaskDelay(pdMS_TO_TICKS(15));
    i2c_master_write(buf1, 4, SLAVE_ADDR_VAL);
    
    // systick_delay(5);
    vTaskDelay(pdMS_TO_TICKS(5));
    i2c_master_write(buf1, 4, SLAVE_ADDR_VAL);

    // systick_delay(1);
    vTaskDelay(pdMS_TO_TICKS(1));
    i2c_master_write(buf1, 4, SLAVE_ADDR_VAL);

    i2c_master_write(buf2, 4, SLAVE_ADDR_VAL);

    // clears display
    lcd_clear();
	// return;
}

/** @brief: Print string to LCD 
 * 
 * 
 * @param input string to print to lcd
*/
void lcd_print(char *input){
    taskENTER_CRITICAL(); 
    uint8_t buf[4];
    int i = 0;
    while (input[i] != '\0') {
        // the DRAM address when you reach the end lmao
        if (i == 16) lcd_set_cursor(1,0);
        if (i == 32) lcd_clear();

        buf[0] = ((input[i] & 0xF0) | P3 | EN | WRITE | RS_SET);
        buf[1] = ((input[i] & 0xF0) | P3 | NOT_EN | WRITE | RS_SET);
        buf[2] = (((input[i] << 4 ) & 0xF0) | P3 | EN | WRITE | RS_SET);
        buf[3] = (((input[i] << 4 ) & 0xF0) | P3 | NOT_EN | WRITE | RS_SET);

        i2c_master_write(buf, 4, SLAVE_ADDR_VAL);
        i++;
    }
    taskEXIT_CRITICAL();
    return;
}


/** @brief: Set cursor on LCD given row and column 
 * 
 * @param row in LCD
 * @param col in LCD
*/
void lcd_set_cursor(uint8_t row, uint8_t col){
    taskENTER_CRITICAL(); 
    uint8_t buf[4];
    uint8_t addr = 0x40 + row * 16 + col;
    addr = addr >> 1 | (1 << 7);

    buf[0] = ((addr & 0xF0) | P3 | EN);
    buf[1] = ((addr & 0xF0) | P3 | NOT_EN);
    buf[2] = (((addr << 4) & 0xF0) | P3 | EN);
    buf[3] = (((addr << 4) & 0xF0) | P3 | NOT_EN);

    i2c_master_write(buf, 4, SLAVE_ADDR_VAL);
    taskEXIT_CRITICAL();
    return;
}

/** @brief: Clear LCD */
void lcd_clear() {
    taskENTER_CRITICAL(); 
    uint8_t buf[4];

    // Send buffer signal
    buf[0] = (0x00 | P3 | EN);
    buf[1] = (0x00 | P3 | NOT_EN);
    buf[2] = ((0x01 << 4) | P3 | EN);
    buf[3] = ((0x01 << 4) | P3 | NOT_EN);

    // Send the command to the LCD via I2C
    i2c_master_write((uint8_t*)buf, 4, SLAVE_ADDR_VAL);
     
    // Wait for approximately 2 seconds for the clear operation to complete
    for (int i = 0; i < 2000000; i++) ;
    taskEXIT_CRITICAL();
}
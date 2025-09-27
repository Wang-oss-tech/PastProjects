/* lcd_driver.c: This code provides functions to interface with an I2C-connected LCD display on a microcontroller. 
    It includes initialization, string printing, cursor setting, and display clearing. The code translates data for 
    communication with the LCD module using I2C.*/
    
#include <i2c.h>
#include <lcd_driver.h>
#include <unistd.h>

#define SLAVE_ADDR_VAL (0x4E >> 1)
#define P3 (1 << 3) // backlit always 1
#define EN (1 << 2)
#define NOT_EN (0 << 2)
#define WRITE (0  << 1)
#define RS_SET (1)

/* Structure of sending bits: */
/* higher/lower | back_lit bit | EN/NOT_EN | R/W | RS_Bit */

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
    i2c_master_write(buf1, 4, SLAVE_ADDR_VAL);
    i2c_master_write(buf1, 4, SLAVE_ADDR_VAL);
    i2c_master_write(buf1, 4, SLAVE_ADDR_VAL);
    i2c_master_write(buf2, 4, SLAVE_ADDR_VAL);

    // clears display
    lcd_clear();
	return;
}

/** @brief: Print string to LCD 
 * 
 * 
 * @param input string to print to lcd
*/
void lcd_print(char *input){
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
    return;
}


/** @brief: Set cursor on LCD given row and column 
 * 
 * @param row in LCD
 * @param col in LCD
*/
void lcd_set_cursor(uint8_t row, uint8_t col){
    uint8_t buf[4];
    uint8_t addr = 0x40 + row * 16 + col;
    addr = addr >> 1 | (1 << 7);

    buf[0] = ((addr & 0xF0) | P3 | EN);
    buf[1] = ((addr & 0xF0) | P3 | NOT_EN);
    buf[2] = (((addr << 4) & 0xF0) | P3 | EN);
    buf[3] = (((addr << 4) & 0xF0) | P3 | NOT_EN);

    i2c_master_write(buf, 4, SLAVE_ADDR_VAL);
    return;
}

/** @brief: Clear LCD */
void lcd_clear() {
    uint8_t buf[4];
    buf[0] = (0x00 | P3 | EN);
    buf[1] = (0x00 | P3 | NOT_EN);
    buf[2] = ((0x01 << 4) | P3 | EN);
    buf[3] = ((0x01 << 4) | P3 | NOT_EN);

    i2c_master_write((uint8_t*)buf, 4, SLAVE_ADDR_VAL);
     
    for (int i = 0; i < 2000000; i++) ; // do nothing, wait for clear
    return;
}
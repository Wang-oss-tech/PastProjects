/**
 * @file lcd.h
 *
 * @brief LCD Driver Function Prototypes
 *
 * This header file declares function prototypes for initializing and
 * controlling an LCD display. It provides functions for initializing the
 * display, printing text, setting the cursor position, and clearing the display.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */

#ifndef _LCD_DRIVER_H_
#define _LCD_DRIVER_H_

#include <unistd.h>

void lcd_driver_init();
void lcd_print(char *input);
void lcd_set_cursor(uint8_t row, uint8_t col);
void lcd_clear();

#endif /* _LCD_DRIVER_H_ */

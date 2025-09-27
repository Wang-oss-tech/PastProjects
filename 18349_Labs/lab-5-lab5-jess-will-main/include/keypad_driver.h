/**
 * @file keypad_driver.h
 *
 * @brief Keypad Driver Function Prototypes
 *
 * This header file declares function prototypes for initializing and reading 
 * the keypad. The `keypad_read` function returns the current character being pressed.
 * If no character is pressed, it returns '\0'.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */


#ifndef _KEYPAD_DRIVER_H_
#define _KEYPAD_DRIVER_H_

#include <unistd.h>

/*
 * keypad_init: Initialize the keypad.
 */
void keypad_init();

/*
 * keypad_read: Return the current character that is being pressed. If
 * no character is pressed, return '\0'
 *
 * For example, if you press 1 and call this function, it should return '1'!
 * Don't worry about handing two or more buttons pressed at once.
 */
char keypad_read();

#endif /* _KEYPAD_DRIVER_H_ */

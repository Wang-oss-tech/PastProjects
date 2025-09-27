/* keypad_driver.c: This code provides functions to interface with a keypad on a microcontroller. 
    It includes initialization for configuring GPIO pins and a function to read key presses by scanning 
    rows and columns. The code facilitates interaction with a keypad using GPIO pins.*/
    
#include <gpio.h>
#include <keypad_driver.h>
#include <unistd.h>
#include <gpio.h>

/** 
 * @brief Initialize Keypad Inputs
 */
void keypad_init() {
    // Initialize pins for keypad
    gpio_init(GPIO_A, 5, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // D13 == COL2
    gpio_init(GPIO_A, 6, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // D12 == ROW1
    gpio_init(GPIO_A, 7, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // D11 == COL1
    gpio_init(GPIO_B, 6, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // D10 == ROW4
    gpio_init(GPIO_C, 7, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // D9 == COL3
    gpio_init(GPIO_A, 9, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // D8 == ROW3
    gpio_init(GPIO_A, 8, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // D7 == ROW2
    return;
}

/** 
 * @brief Read from keypad, implemented by activating each row and 
 *        and evaluating column status
 */
char keypad_read() {
    // Clear all pins inputs before reading
    gpio_clr(GPIO_A, 6);
    gpio_clr(GPIO_A, 8);
    gpio_clr(GPIO_A, 9);
    gpio_clr(GPIO_B, 6);

    gpio_set(GPIO_A, 6); // Set ROW1
    if (gpio_read(GPIO_A, 7)) {
        while (gpio_read(GPIO_A, 7));
        return '1'; // Read COL1
    }
    if (gpio_read(GPIO_A, 5)){
        while (gpio_read(GPIO_A, 5));
        return '2'; // Read COL2
    }
    
    if (gpio_read(GPIO_C, 7)){
        while (gpio_read(GPIO_C, 7));
        return '3'; // Read COL3
    }
    gpio_clr(GPIO_A, 6);

    gpio_set(GPIO_A, 8); // Set ROW2
    if (gpio_read(GPIO_A, 7)){
        while (gpio_read(GPIO_A, 7));
        return '4'; // Read COL1
    }
    
    if (gpio_read(GPIO_A, 5)){
        while (gpio_read(GPIO_A, 5));
        return '5'; // Read COL2
    } 
    
    if (gpio_read(GPIO_C, 7)){
        while (gpio_read(GPIO_C, 7));
        return '6'; // Read COL3
    }
    gpio_clr(GPIO_A, 8);
    
    gpio_set(GPIO_A, 9); // Set ROW3
    if (gpio_read(GPIO_A, 7)) {
        while (gpio_read(GPIO_A, 7));
        return '7'; // Read COL1
    }
    if (gpio_read(GPIO_A, 5)) {
        while (gpio_read(GPIO_A, 5));
        return '8'; // Read COL2
    }
    if (gpio_read(GPIO_C, 7)) {
        while (gpio_read(GPIO_C, 7));
        return '9'; // Read COL3
    }
    gpio_clr(GPIO_A, 9);

    gpio_set(GPIO_B, 6); // Set ROW4
    if (gpio_read(GPIO_A, 7)) {
        while (gpio_read(GPIO_A, 7));
        return '*'; // Read COL1
    }
    if (gpio_read(GPIO_A, 5)) {
        while (gpio_read(GPIO_A, 5));
        return '0'; // Read COL2
    }
    if (gpio_read(GPIO_C, 7)) {
        while (gpio_read(GPIO_C, 7));
        return '#'; // Read COL3
    }
    gpio_clr(GPIO_B, 6);
    
    return '\0'; // No key pressed
}

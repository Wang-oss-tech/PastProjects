/* main.c:  This code sets up and controls various peripherals on a microcontroller, 
    including UART, GPIO, I2C, an LCD display, and a keypad. 
    It implements a simple password-based lock/unlock mechanism. */

#include <gpio.h>
#include <i2c.h>
#include <printk.h>
#include <uart_polling.h>
#include <unistd.h>
#include <lcd_driver.h>
#include <keypad_driver.h>

int main() {
    // Initialize UART with a specific baud rate (e.g., 9600 baud)
    uart_polling_init(115200);

    char input;
    while (1) {
        // Get a byte from UART
        input = uart_polling_get_byte();
        
        // Send the received byte back through UART
        uart_polling_put_byte(input);
        
        // Check if the received byte is 'S'
        if (input == 'S') {
            // Get the next byte
            input = uart_polling_get_byte();
            
            // Send the received byte back through UART
            uart_polling_put_byte(input);

            // Check if the next byte is 't'
            if (input == 't') {
                // Get the next byte
                input = uart_polling_get_byte();
                
                // Send the received byte back through UART
                uart_polling_put_byte(input);
                
                // Check if the next byte is 'a'
                if (input == 'a') {
                    // Get the next byte
                    input = uart_polling_get_byte();
                    
                    // Send the received byte back through UART
                    uart_polling_put_byte(input);
                    
                    // Check if the next byte is 'r'
                    if (input == 'r') {
                        // Get the next byte
                        input = uart_polling_get_byte();
                        
                        // Send the received byte back through UART
                        uart_polling_put_byte(input);
                        
                        // Check if the next byte is 't'
                        if (input == 't') {
                            // Exit the loop if 'Start' is received
                            break;
                        }
                    }
                }
            }
        }
    }
 
    // Buttons
    gpio_init(GPIO_A, 10, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_UP, ALT0); // D2 TOP BUTTON
    gpio_init(GPIO_B, 5, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_UP, ALT0); // D4 LOWER BUTTON

    // LEDs
    gpio_init(GPIO_A, 0, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // GREEN LED
    gpio_init(GPIO_A, 1, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // RED LED

    // Initialization
    keypad_init();
    i2c_master_init(1);
    lcd_driver_init();
    gpio_set(GPIO_A, 1); // 
    gpio_clr(GPIO_A, 0);

    // Read Keypad Value
    char keypad_input[2];
    keypad_input[1] = '\0';

    char attempted_password[32];
    for (int k = 0; k < 32; k++) 
        attempted_password[k] = '\0';
    int i = 0;
    uart_put_string("\nLOCKED\n");

    while (1) {
        keypad_input[0] = keypad_read();

        if (keypad_input[0] != '\0') {
            attempted_password[i] = keypad_input[0];
            lcd_print(keypad_input);
            if (i == 16) lcd_set_cursor(1,0);
            else if (i == 32){
                lcd_clear();
                uart_put_string("INCORRECT PASSWORD, TRY AGAIN!\n");
                gpio_set(GPIO_A, 1); // set red led
                gpio_clr(GPIO_A, 0); // clear green led
                i = -1;
            }
            i++;
        }

        // Enter Pressed
        if (!(gpio_read(GPIO_A, 10))) {
            // Success
            if ((attempted_password[0] == '#') &&
                (attempted_password[1] == '3') && 
                (attempted_password[2] == '4') && 
                (attempted_password[3] == '9') &&
                (attempted_password[4] = '\n')) {
                uart_put_string("UNLOCKED!\n");
                gpio_set(GPIO_A, 0); //set green 
                gpio_clr(GPIO_A, 1); //clear red
            } else { // Unsuccessful
                uart_put_string("INCORRECT PASSWORD, TRY AGAIN!\n");
                gpio_set(GPIO_A, 1); // set red led
                gpio_clr(GPIO_A, 0); // clear green led
                i = 0;
            }

            lcd_clear();
        }

        // Clear/Lock Pressed
        if (!(gpio_read(GPIO_B, 5))) {
            gpio_set(GPIO_A, 1); // set red led
            gpio_clr(GPIO_A, 0); // clear green led
            lcd_clear();
            i = 0;
            uart_put_string("LOCKED\n");
        }
    }
    return 0;
}




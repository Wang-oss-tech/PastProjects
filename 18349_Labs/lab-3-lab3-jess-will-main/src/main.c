/**
 * @file main.c
 *
 * @brief This file contains the main program for controlling two servo motors.
 *        It initializes various hardware components, including UART, GPIO, I2C,
 *        LCD, keypad, and timers. It provides a command-line interface over UART
 *        for enabling/disabling servo channels and setting their angles using a keypad.
 *
 * @date 10/29/2023
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <gpio.h>
#include <i2c.h>
#include <printk.h>
#include <uart.h>
#include <unistd.h>
#include <lcd_driver.h>
#include <keypad_driver.h>
#include <systick.h>
#include <stdio.h>
#include <uart_polling.h>
#include <timer.h>
#include <stdlib.h>
#include <string.h>
#include <servo.h>
#include <nvic.h>

/** @brief Enable channel */
#define CHANNEL_ENABLE 1

/** @brief Disable channel */
#define CHANNEL_DISABLE 0

/** @brief Channel Number 1 */
#define CHANNEL1 1

/** @brief Channel Number 2 */
#define CHANNEL2 2

/** @brief String Version of Channel 1 */
#define CHANNEL1_STRING 49

/** @brief String Version of Channel 2 */
#define CHANNEL2_STRING 50

/** @brief STDIN Constant */
#define STDIN 0

/** @brief STDOUT Constant */
#define STDOUT 1

/** @brief Period of Servo Timer */
#define PERIOD 200

/** @brief Timer Value */
#define TIMER2 2

/** @brief Variable to hold the state of channel 1 (0 for disable, 1 for enable) */
volatile int channel1 = 0;

/** @brief Variable to hold the state of channel 2 (0 for disable, 1 for enable) */
volatile int channel2 = 0;

/** @brief Variable to keep count (used for some specific purpose in your code) */
volatile int count = 0;

/** @brief Variable to store the desired angle for channel 1 */
volatile int set_angle_1;

/** @brief Variable to store the desired angle for channel 2 */
volatile int set_angle_2;

/** @brief Helper function for command error for enable and disable */
void error() {
    uart_write(STDOUT,"ERROR: Please re-enter\n",24);
    uart_write(STDOUT, "\n > ", 4);
}

/** 
 * @brief Helper function for command error for angle insertion
*/
void angle_error() {
    uart_write(STDOUT,"ERROR: Innvalid angle, please re-enter\n",40);
    lcd_clear();
}

/**
 * @brief This function handles the control of servos based on timer interrupts.
 * It disables timers 2 and 4, checks the servo channels, and updates servo states.
 * 
 */
void servo_handler(){
    nvic_irq(TIMER4_NVIC_IRQ, IRQ_DISABLE); // disable timer 4
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_DISABLE); // disable timer 2

    if (channel1 == 1){
        if ((0 <= count) && (count < ((set_angle_1/10) + 6))){
            servo_enable(CHANNEL1, CHANNEL_ENABLE);
        } if ((((set_angle_1/10) + 6) <= count) && (count < PERIOD)) {
            servo_enable(CHANNEL1, CHANNEL_DISABLE);
        }
    } else {
        servo_enable(CHANNEL1, CHANNEL_DISABLE);
    }
    
    if (channel2 == 1){
        if ((0 <= count) && (count < ((set_angle_2/10) + 6))){
            servo_enable(CHANNEL2, CHANNEL_ENABLE);
        } if ((((set_angle_2/10) + 6) <= count) && (count < PERIOD)) {
            servo_enable(CHANNEL2, CHANNEL_DISABLE);
        }
    } else {
        servo_enable(CHANNEL2, CHANNEL_DISABLE);
    }

    count++;
    count %= 200;
    
    timer_clear_interrupt_bit(TIMER2); // clear interrupt bit 
    nvic_irq(TIMER4_NVIC_IRQ, IRQ_ENABLE); // enable timer 4
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_ENABLE); // enable timer 2
}

/** 
 * @brief Main function to control servo motors based on user input via UART and keypad
 * 
 */
int main() {
    // Initialize UART
    uart_init(115200);

    /* Timer Blinking LED Feature */
    gpio_init(GPIO_A, 1, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // RED LED
    timer_init(4, 734, 65484); // triggers interrupt every 5 second

    /* Put it Together */
    uart_write(STDOUT, "\nWelcome to Servo Controller!\n", 30);
    uart_write(STDOUT, "Enter 'enable <ch>' to enable SERVO\n", 37);
    uart_write(STDOUT, "Enter 'disable <ch>' to disable SERVO\n", 39);
    uart_write(STDOUT, "Set the servo angle using the keypad", 37);

    /* Initialization for Servo Put it Together */
    servo_init();
    keypad_init();
    lcd_driver_init();

    /* Take in Servo Commands */
    char channel[10];

    /* Enable TIMER 2 for servo */
    timer_init(2, 0, 1600); 

    /* Take in parameter for servo */
    while(1) {
        int channelNumber; 
        uart_write(STDOUT, "\n > ", 4);
        uart_read(STDIN, channel, 10);
        if ((channel[8] == CHANNEL1_STRING) || (channel[8] == CHANNEL2_STRING)) { // disable case
            channelNumber = channel[8];

            // error checking for each character
            if (channel[0] != 'd') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[1] != 'i') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[2] != 's') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[3] != 'a') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[4] != 'b') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[5] != 'l') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[6] != 'e') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else {
                if (channelNumber == CHANNEL1_STRING) {
                    uart_write(STDOUT, "Disabled channel 1\n", 20);
                    channel1 = CHANNEL_DISABLE; // disabled channel1
                } else if (channelNumber == CHANNEL2_STRING) {
                    uart_write(STDOUT, "Disabled channel 2\n", 20);
                    channel2 = CHANNEL_DISABLE; // disabled channel2
                } 
            }
        } 
        else if ((channel[7] == CHANNEL1_STRING) || (channel[7] == CHANNEL2_STRING)) { // enable case
            channelNumber = channel[7];

            // error checking for each character
            if (channel[0] != 'e') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[1] != 'n') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[2] != 'a') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[3] != 'b') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[4] != 'l') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else if (channel[5] != 'e') {
                error(); 
                uart_read(STDIN, channel, 10);
            } else {
                if (channelNumber == CHANNEL1_STRING) {
                    uart_write(STDOUT, "Enabled channel 1\n", 19);
                    channel1 = CHANNEL_ENABLE; // enable channel 1
                    channel2 = CHANNEL_DISABLE; // disable channel 2
                } else if (channelNumber == CHANNEL2_STRING) {
                    uart_write(STDOUT, "Enabled channel 2\n", 19);
                    channel2 = CHANNEL_ENABLE; // enable channel 2
                    channel1 = CHANNEL_DISABLE; // disable channel 1
                } 
            }

            /* Write to minicom after succesfully enabling channel/servo */
            uart_write(STDOUT, "Enter angle using keypad\n",26);

            /* Read Keypad Value */
            char keypad_input[2];
            keypad_input[1] = '\0';

            /* Initialize Angle Array*/
            char angle[4];
            for (int k = 0; k < 4; k++) 
                angle[k] = '\0';

            /* Read Keypad Input */
            int i = 0;
            while (keypad_read() != '#') { // treat '#' as enter case
                keypad_input[0] = keypad_read();
                if (keypad_input[0] == '*') angle_error();

                if (keypad_input[0] != '\0') {
                    angle[i] = keypad_input[0];
                    lcd_print(keypad_input);
                    i++;
                } 
            }
            lcd_print("#");

            /* Convert (string)angle to (int)angle */
            int angle_int;
            angle_int = atoi(angle);

            /* Set angle to global variable after conversion*/
            if ((angle_int > 180) || (angle_int < 0)){
                angle_error();
            } else if (channel1 == CHANNEL_ENABLE){
                set_angle_1 = angle_int;
                uart_write(STDOUT, "Rotate Complete \n",18);
            } else if (channel2 == CHANNEL_ENABLE){
                set_angle_2 = angle_int;
                uart_write(STDOUT, "Rotate Complete \n",18);
            }
            lcd_clear();

        } else { // error case where user does not enter the correct command
            error(); 
            uart_read(STDIN, channel, 10);
        }
    }
    while(1);
} 
/**
 * @file servo.c
 *
 * @brief Functions for controlling servo motors, including initialization, enabling, and setting positions.
 *
 * This file provides functions to initialize the servo motors, enable/disable specific channels, and set positions.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */


#include <unistd.h>
#include <gpio.h>
#include <timer.h>
#include <nvic.h>

/** @brief Attribute for indicating that a variable is intentionally unused */
#define UNUSED __attribute__((unused))

/** @brief Integer variable for setting angle of servo 1 */
int set_angle_1_i;

/** @brief Integer variable for setting angle of servo 2 */
int set_angle_2_i;

/**
 * @brief Initialize GPIO pins for servo
 * 
 */
void servo_init(){
    gpio_init(GPIO_B, 0, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // A3-> channel 1
    gpio_init(GPIO_A, 0, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // A0-> channel 2
}

/**
* @brief Enable or disable servo motor control
*
* @param channel channel to enable or disable
* @param enabled 1 to enable, 0 to disable
*
* @return 0 on success or -1 on failure
*/
int servo_enable(uint8_t channel, uint8_t enabled){
    if (enabled) {
        // set pulse to high
        if (channel == 1)  gpio_set(GPIO_B, 0);
        else if (channel == 2) gpio_set(GPIO_A, 0); 
        return 0; // success
    } else {
        // set channel output to low (no pulse)
        if(channel == 1) gpio_clr(GPIO_B, 0);
        else if (channel == 2) gpio_clr(GPIO_A, 0);
        return 0; // success
    }
    return -1; // failure
}

/**
* @brief Set a servo motor to a given position
*
* @param channel channel to control
* @param angle servo angle in degrees (0-180)
*
* @return 0 on success or -1 on failure
*/
int servo_set(uint8_t channel, uint8_t angle){ 
    if (channel == 1){
        set_angle_1_i = 60 + angle;
        return 0; // success
    } else if (channel == 2){
        set_angle_2_i = 60 + angle;
        return 0; // success
    }
    return -1; // failure
}



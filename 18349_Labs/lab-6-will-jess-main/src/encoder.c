/**
 * @file encoder.c
 *
 * @brief This file contains the implementation of an encoder interface for FreeRTOS.
 *        The encoder is connected to two GPIO pins, and changes in its rotational state
 *        are captured using interrupts. The current position of the encoder is tracked
 *        and can be read using the encoder_read() function.
 *
 * @date 12/05/2022
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <FreeRTOS.h>
#include <task.h>
#include <adc.h>
#include <unistd.h>
#include <uart.h>
#include <stdio.h>
#include <atcmd.h>
#include <string.h>
#include <stdlib.h>
#include <nvic.h>
#include <timer.h>
#include <lcd_driver.h>
#include <servo.h>
#include <keypad_driver.h>
#include <gpio.h>
#include <exti.h>
#include <encoder.h>

/** @brief Encoder A input signal */
volatile uint32_t ENC_A = 0;

/** @brief Encoder B input signal */
volatile uint32_t ENC_B = 0;

/** @brief State variable representing the current state of the encoder */
volatile uint32_t state = 0;

/** @brief Variable holding the current position of the encoder */
volatile uint32_t current_position = 0;

/**
 * @brief Initializes the encoder interface by configuring GPIO pins, enabling external interrupts,
 *        and setting up NVIC IRQs. The encoder is connected to two GPIO pins (ENC A and ENC B),
 *        and changes in its rotational state are captured using interrupts.
 *        
 */
void encoder_init() {
    gpio_init(GPIO_B, 3, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_HIGH, PUPD_PULL_DOWN, ALT0); // ENC A , yellow, D3
    gpio_init(GPIO_A, 10, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_HIGH, PUPD_PULL_DOWN, ALT0); // ENC B, white, D2 
    enable_exti(GPIO_B, 3, EXTI_RISING_FALLING_EDGE);
    enable_exti(GPIO_A, 10, EXTI_RISING_FALLING_EDGE);   
    nvic_irq(9, IRQ_ENABLE);
    nvic_irq(40, IRQ_ENABLE);
}

/**
 * @brief Stops the encoder interface by disabling the external interrupt associated with it.
 *        This function is useful when the encoder monitoring is no longer needed.
 *
 * 
 */
void encoder_stop() {
    disable_exti(10);
}

/**
 * @brief Reads the current position of the encoder.
 *
 * @return The current position of the encoder.
 */
uint32_t encoder_read() {
    return current_position;
}

/**
 * @brief Interrupt service routine (ISR) for handling encoder events.
 *
 * This ISR is triggered by changes in the state of the encoder. It updates the current
 * position of the encoder based on the transition between its two signals (ENC A and ENC B).
 * The function also takes care of handling overflow by resetting the position to zero when
 * it reaches a predefined maximum value.
 */
void encoder_irq_handler() {
    exti_clear_pending_bit(10);
    exti_clear_pending_bit(3);

    UBaseType_t x;
    x = taskENTER_CRITICAL_FROM_ISR();       

    uint32_t nextState = (gpio_read(GPIO_B, 3) * 10) + (gpio_read(GPIO_A, 10));

    switch (state) {
        case 0: 
            if (nextState == 1) current_position++;
            else if (nextState == 10) current_position++;
            break;
        case 1:
            if (nextState == 11) current_position++;
            else if (nextState == 0) {
                if (current_position == 0) current_position = 1196;
                current_position--;
            }
            break;
        case 11:
            if (nextState == 10) current_position++;
            else if (nextState == 1) {
                if (current_position == 0) current_position = 1196;
                current_position--;
            }
            break;
        case 10:
            if (nextState == 0) current_position++;
            else if (nextState == 11) {
                if (current_position == 0) current_position = 1196;
                current_position--;
            }
            break;
        default:
            break;
    } state = nextState;

    if (current_position == 1196) current_position = 0; // reset overflow
  
    taskEXIT_CRITICAL_FROM_ISR(x);
}




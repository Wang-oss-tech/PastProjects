/**
 * @file motor_driver.c 
 *
 * @brief Motor implementation of lab 6
 *
 * @date 12/13/2023
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <motor_driver.h>
#include <unistd.h>
#include <gpio.h>
#include <timer.h>
#include <encoder.h>

/** @brief Definition of UNUSED parameter */
#define UNUSED __attribute__((unused))


/** @brief Initialize the motor controller with specified GPIO ports and timer settings.
 *  @param port_a, port_b, port_pwm: GPIO ports for MOTOR IN1, IN2, and EN respectively.
 *  @param channel_a, channel_b, channel_pwm: GPIO channels for MOTOR IN1, IN2, and EN respectively.
 *  @param timer: Timer number for PWM configuration.
 *  @param timer_channel: Timer channel for PWM configuration.
 *  @param alt_timer: Unused alternative timer parameter.
 */
void motor_init(gpio_port port_a, gpio_port port_b,  gpio_port port_pwm,
                 uint32_t channel_a,  uint32_t channel_b,  uint32_t channel_pwm,
                 uint32_t timer,  uint32_t timer_channel,  UNUSED uint32_t alt_timer) {



    // Initialize GPIO pins for MOTOR IN1, IN2, and EN
    gpio_init(port_a, channel_a, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // MOTOR IN1
    gpio_init(port_b, channel_b, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // MOTOR IN2
    gpio_init(port_pwm, channel_pwm, MODE_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_HIGH, PUPD_NONE, ALT0); // MOTOR EN
    

    // Configure and initialize the timer for PWM
    timer_start_pwm(timer, timer_channel, 1000, 4000, 0);

   // Call encoder initialization function
    encoder_init();
}

/** @brief Set the motor direction and control the duty cycle.
 *  @param duty_cycle: Duty cycle percentage (0 to 100).
 *  @param direction: Motor direction mode (FREE, FORWARD, BACKWARD, STOP).
 */
void motor_set_dir(uint32_t duty_cycle, uint32_t direction) { 
    // duty cycle should be between 0 and 100
    if (duty_cycle > 100) {
        duty_cycle = 100;  
    }

    (void) direction; // for testing purposes

    // Set the direction based on the specified mode
    switch (direction) {
        case FREE:
            // Leave all H-Bridge/motor pins floating with a PWM duty cycle of 0
            timer_set_duty_cycle(TIMER_NUMBER, TIMER_CHANNEL, 0);
            break;
        case FORWARD:
            gpio_set(MOTOR_IN1, MOTOR_IN1_CHANNEL); // high
            gpio_clr(MOTOR_IN2, MOTOR_IN2_CHANNEL); // low
            timer_set_duty_cycle(TIMER_NUMBER, TIMER_CHANNEL, duty_cycle);
            break;
        case BACKWARD:
            gpio_clr(MOTOR_IN1, MOTOR_IN1_CHANNEL); // low
            gpio_set(MOTOR_IN2, MOTOR_IN2_CHANNE); // high
            timer_set_duty_cycle(TIMER_NUMBER, TIMER_CHANNEL, duty_cycle);
            break;
        case STOP:
            // Set both MOTOR IN1 and MOTOR IN2 to HIGH to stop the motor
            gpio_set(MOTOR_IN1, MOTOR_IN1_CHANNEL);
            gpio_set(MOTOR_IN2, MOTOR_IN2_CHANNEL);
            timer_set_duty_cycle(TIMER_NUMBER, TIMER_CHANNEL, 0);
            break;
        default:
            // Invalid direction, do nothing
            break;
    }
}

/** @brief Read the current position of the motor using an encoder.
 *  @return Current position of the motor.
 */
uint8_t motor_position() {
    return encoder_read();
}

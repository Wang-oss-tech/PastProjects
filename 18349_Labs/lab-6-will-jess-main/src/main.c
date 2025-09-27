/**
 * @file main.c
 *
 * @brief Main file that does putting it together
 *
 * @date 12/05/2023
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

/** @brief Maximum Motor Speed */
#define MAX_MOTOR_SPEED 90

/** @brief Minimum Motor Speed */
#define MIN_MOTOR_SPEED 10

/** @brief STDIN Constant */
#define STDIN 0

/** @brief STDOUT Constant */
#define STDOUT 1

/** @brief Channel Number 1 */
#define CHANNEL1 1

/** @brief Timer Value */
#define TIMER2 2

/** @brief Enable channel */
#define CHANNEL_ENABLE 1

/** @brief Disable channel */
#define CHANNEL_DISABLE 0

/** @brief Period of Servo Timer */
#define PERIOD 200

/** @brief command mode off macro */
#define COMMAND_MODE_OFF 0

/** @brief command mode on macro */
#define COMMAND_MODE_ON 1

/** @brief Config minimal stack size */
#define CONFIG_MIN_STACK_SIZE 256

/** @brief keypad locked macro */
#define KEYPAD_LOCKED 1

/** @brief keypad unlocked macro */
#define KEYPAD_UNLOCKED 0

/** @brief Attribute for indicating that a variable is intentionally unused */
#define UNUSED __attribute__((unused))

/** @brief NVIC IRQ Number */
#define TIMER2_NVIC_IRQ 28

/** @brief Bit possibilities for 10 bit */
#define TEN_BIT_RESOLUTION 1023

/** @brief LED ON status */
#define LED_ON 1

/** @brief LED OFF status */
#define LED_OFF 0

/** @brief Pulse status high */
#define PULSE_HIGH 1

/** @brief Pulse status low */
#define PULSE_LOW 0 


/** @brief Global angle */
volatile int angle_int;

/**
 * @brief PID controller parameters structure.
 */
struct {
    float proportional;
    float integral;
    float derivative;
} pid;

/** @brief counter variable*/
volatile int count = 1;

/** @brief Global angle */
volatile int angle_int;

/** @brief Variable to hold the state of channel 1 (0 for disable, 1 for enable) */
volatile int channel1 = 1;

/**
 * @brief This function handles the control of servos based on timer interrupts.
 * It disables timers 2 and 4, checks the servo channels, and updates servo states.
 *
 */
void servo_handler(){
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_DISABLE); // disable timer 2
    UBaseType_t x;
    x = taskENTER_CRITICAL_FROM_ISR();

    if (channel1 == CHANNEL_ENABLE)
    {
        if ((0 <= count) && (count < ((angle_int / 10) + 6)))
        {
            servo_enable(CHANNEL1, CHANNEL_ENABLE);
        }
        if ((((angle_int / 10) + 6) <= count) && (count < PERIOD))
        {
            servo_enable(CHANNEL1, CHANNEL_DISABLE);
        }
    }
    else
    {
        servo_enable(CHANNEL1, CHANNEL_DISABLE);
    }

    count++;
    count %= 200;

    taskEXIT_CRITICAL_FROM_ISR(x);
    timer_clear_interrupt_bit(TIMER2);     // clear interrupt bit
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_ENABLE); // enable timer 2
}

/**
 * @brief Task for controlling a servo motor connected to TIMER 2 on GPIO_B, Pin 0.
 *
 * This task initializes TIMER 2 for servo control and toggles the servo's position
 * between three predefined angles (0, 90, and 180 degrees) at regular intervals.
 * The servo state is tracked to ensure sequential angle changes.
 *
 * @note Ensure that the appropriate GPIO pin and TIMER are configured before starting this task.
 */
void servo_task() {
    timer_init(2, 0, 1600);                                                                         /* Enable TIMER 2 for servo */
    gpio_init(GPIO_B, 0, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // A3-> channel 1
    int servo_state = 0;
    while (1) {
        vTaskDelay(1000);
        if (servo_state == 0){
            angle_int = 0;
            servo_state = 1;
        } else if (servo_state == 1){
            angle_int = 90;
            servo_state = 2;
        } else if (servo_state == 2){
            angle_int = 180;
            servo_state = 0;
        }
    }
}

/**
 * @brief Task for configuring PID parameters using a keypad and displaying prompts on an LCD.
 *
 * This task initializes the keypad and LCD driver. It prompts the user to enter proportional (P),
 * integral (I), and derivative (D) parameters sequentially. The entered values are displayed on the LCD
 * and used to configure a PID controller. The process continues until all three parameters are entered.
 *
 * @note Ensure that the keypad, LCD driver, and PID controller (assuming 'pid' is globally defined)
 *       are properly configured before starting this task.
 */
void servo_LCD_Keypad_task() {
    keypad_init();
    lcd_driver_init();

    while (1) {
        if (count == 1) lcd_print("Enter P:");
        else if (count == 2) lcd_print("Enter I:");
        else if (count == 3) lcd_print("Enter D:");
        int i = 0;
        // Wait for '#' (enter key) or command mode to be disabled

        // if (commandMode == COMMAND_MODE_OFF) {
        lcd_set_cursor(1, 0);

        // temporary inputs
        char keypad_input[2];
        keypad_input[1] = '\0';

        char attempted_passcode[12];
        for (int k = 0; k < 12; k++)
        attempted_passcode[k] = '\0';

        while (keypad_read() != '#') { 
            keypad_input[0] = keypad_read();

            // If a valid key is pressed, update attempted passcode and display on LCD
            if (keypad_input[0] != '\0') {
                if (keypad_input[0] == '*') attempted_passcode[i] = '.';
                else attempted_passcode[i] = keypad_input[0];

                lcd_print(keypad_input);
                i++;
            }
        }
        if (count == 1 && (strcmp(attempted_passcode, "\n") != 0)) {
            pid.proportional = atof(attempted_passcode);
            printf("P: %f\n", pid.proportional);
        } else if (count == 2 && (strcmp(attempted_passcode, "\n") != 0)) {
            pid.integral = atof(attempted_passcode);
            printf("I: %f\n", pid.integral);
        } else if (count == 3 && (strcmp(attempted_passcode, "\n") != 0)) {
            pid.derivative = atof(attempted_passcode);
            printf("D: %f\n", pid.derivative);
            count = 0;
        }
        lcd_print("#");
        count++;
        lcd_clear();
        asm("bkpt");
    }
}


/**
 * @brief Task for controlling an LED using TIMER 2 to adjust the duty cycle.
 *
 * This task continuously toggles the duty cycle of TIMER 2 Channel 3 to control the brightness
 * of an LED. The duty cycle is varied between 0% and 100% in a repeating pattern with a delay
 * of 500 milliseconds between transitions.
 *
 * @note Ensure that TIMER 2 is configured for PWM, and the corresponding GPIO pin is set up
 *       for the LED before starting this task.
 */
void led_task () {
    int i = 0;
    while(1) {
        timer_set_duty_cycle(2, 3, i);
        vTaskDelay(pdMS_TO_TICKS(500));
        if (i == 0) i = 500000;
        else if (i == 500000) i = 0;
    }
}

/**
 * @brief The main function initializes UART communication, hardware timers, encoder, and tasks.
 *
 * The main function sets up the UART communication at a baud rate of 1152000. It initializes
 * hardware timers for PWM control, sets up the encoder interface, and creates tasks for keypad and LCD control,
 * LED brightness control, and servo motor control. The FreeRTOS scheduler is then started.
 *
 * @note Ensure that all necessary peripherals are properly configured before running this program.
 */
int main() {
    uart_init(1152000);

    // Hardware Timer Init
    timer_start_pwm(2, 3, 16, 500000, 500000); // timer, channel, prescaler value, period, duty cycle

    encoder_init();

    xTaskCreate(servo_LCD_Keypad_task, // handle keypad
                "Keypadtask",
                256,
                NULL,
                tskIDLE_PRIORITY + 1,
                NULL);
    xTaskCreate(led_task, 
                "ledTask",
                256,
                NULL, 
                tskIDLE_PRIORITY + 1,
                NULL);
    xTaskCreate(servo_task,
                "servo_task",
                256,
                NULL,
                tskIDLE_PRIORITY + 1,
                NULL);

    
    vTaskStartScheduler();
    
    return 0;
}
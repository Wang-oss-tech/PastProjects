/**
 * @file main.c
 *
 * @brief  creates a system where tasks are managed concurrently 
            using FreeRTOS, and it interacts with various peripherals 
            like LEDs, UART, LCD, keypad, and servo motors. The primary 
            functionality involves handling commands through UART and controlling 
            the servo motor based on user input passcodes. The program also includes 
            a simple LED toggle task and UART input/output tasks.
 *
 * @date 11/9/2023
 *
 * @author Jessica Chan (jchan4), William Wang (www2)
 */

#include <FreeRTOS.h>
#include <task.h>
#include <uart.h>
#include <stdio.h>
#include <unistd.h>
#include <gpio.h>
#include <keypad_driver.h>
#include <lcd_driver.h>
#include <servo.h>
#include <timer.h>
#include <nvic.h>
#include <stdlib.h>
#include <string.h>
#include <atcmd.h>

/** @brief STDIN Constant */
#define STDIN 0

/** @brief STDOUT Constant */
#define STDOUT 1

/** @brief File __reads put its characters into */
char channel[100];

/** @brief Variable to hold the state of channel 1 (0 for disable, 1 for enable) */
volatile int channel1 = 1;

/** @brief Global angle */
volatile int angle_int;

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

/** @brief Global variable for commandMode */
volatile int commandMode;

/** @brief  Global variable for our set passcode */
char correct_passcode[50];

/** @brief address for uart_get_byte c variable*/
char plus[1];




/** @brief Attribute for indicating that a variable is intentionally unused */
#define UNUSED __attribute__((unused))

/**
 * @brief NVIC IRQ Number
 */
#define TIMER2_NVIC_IRQ 28

/** @brief Variable to keep count (used for some specific purpose in your code) */
volatile int count = 0;

/** 
 * @brief AT+RESUME Task, turns command mode off
 *
 * @param args: Unused parameter (can be NULL).
 * @param cmdargs: Unused parameter (can be NULL).
 * @return 0 on successful execution.
 */
uint8_t exit_command(UNUSED void *args, UNUSED const char *cmdargs) {
    commandMode = COMMAND_MODE_OFF;
    return 0;
}

/** 
 * @brief AT+HELLO Task
 *
 * @param args: A pointer to a null-terminated string containing a name.
 * @param cmdargs: Unused parameter (can be NULL).
 * @return 0 on successful execution.
 */
uint8_t print_hello(void *args, UNUSED const char *cmdargs) {
    printf("Hello, %s!\n", (char*)args);
    return 0;
}

/** 
 * @brief AT+PASSCODE= Task
 *
 * @param args: A pointer to a null-terminated string containing a passcode.
 * @param cmdargs: Unused parameter (can be NULL).
 * @return 0 on successful execution.
 */
uint8_t set_passcode(void *args, UNUSED const char *cmdargs) {
    strncpy(correct_passcode, (char*)args, 50);
    return 0;
}

/** 
 * @brief AT+PASSCODE= Task
 *
 * @param args: Unused parameter (can be NULL).
 * @param cmdargs: Unused parameter (can be NULL).
 * @return 0 on successful execution.
 */
uint8_t print_passcode(UNUSED void *args, UNUSED const char *cmdargs) {
    printf("Passcode : %s\n", (char*)correct_passcode);
    return 0;
}

/**
 * @brief This function handles the control of servos based on timer interrupts.
 * It disables timers 2 and 4, checks the servo channels, and updates servo states.
 * 
 */
void servo_handler(){
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_DISABLE); // disable timer 2
    UBaseType_t x;
    x = taskENTER_CRITICAL_FROM_ISR(); 
    
    if (channel1 == 1){
        if ((0 <= count) && (count < ((angle_int/10) + 6))){
            servo_enable(CHANNEL1, CHANNEL_ENABLE);
        } if ((((angle_int/10) + 6) <= count) && (count < PERIOD)) {
            servo_enable(CHANNEL1, CHANNEL_DISABLE);
        }
    } else {
        servo_enable(CHANNEL1, CHANNEL_DISABLE);
    }

    count++;
    count %= 200;
    
    taskEXIT_CRITICAL_FROM_ISR(x);
    timer_clear_interrupt_bit(TIMER2); // clear interrupt bit 
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_ENABLE); // enable timer 2
}


/** @brief global led status */
int LED_status = 0;

/** 
 * @brief Blinky Task
 *
 * @details Controls the blinking of a green LED on GPIO_A Pin 1.
 *          Uses a delay of 500 milliseconds to toggle the LED state.
 */
void Blinky_task() {
    gpio_init(GPIO_A, 1, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // GREEN LED
    while(1) {
        if (LED_status == 0) {
            gpio_set(GPIO_A, 1);
            LED_status = 1;
        } else {
            gpio_clr(GPIO_A, 1);
            LED_status = 0;
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/** 
 * @brief UART Task
 *
 * @details Continuously reads input from the standard input and prints it to the console.
 */
void UART_task() {
    while(1) {
        read(STDIN, channel, 100);
        printf(" > You typed: %s \n", channel);
    }
}

/** 
 * @brief Another UART Task
 *
 * @details Prints "hello" to the console every second when not in command mode.
 */
void another_UART_task(){
    while(1) {
        if (commandMode == COMMAND_MODE_OFF){
            printf("hello\n");
            vTaskDelay(pdMS_TO_TICKS(1000));
        }
    }
}

/** @brief keypad locked macro */
#define KEYPAD_LOCKED 1

/** @brief keypad unlocked macro */
#define KEYPAD_UNLOCKED 0

/** @brief global locked variable  */
int LOCKED = KEYPAD_LOCKED;

/** 
 * @brief Servo, LCD, and Keypad Task
 *
 * @details Manages servo motor, LCD display, and keypad for entering a passcode.
 *
 */
void servo_LCD_Keypad_task(){
    timer_init(2, 0, 1600); /* Enable TIMER 2 for servo */
    gpio_init(GPIO_B, 0, MODE_GP_OUTPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_PULL_DOWN, ALT0); // A3-> channel 1
    keypad_init();
    lcd_driver_init();

    while(1) {
        lcd_print("Enter Passcode: ");
        lcd_set_cursor(1,0);

        // temporary inputs
        char keypad_input[2];
        keypad_input[1] = '\0';

        char attempted_passcode[12];
        for (int k = 0; k < 12; k++) attempted_passcode[k] = '\0';
        
        int i = 0;
        // Wait for '#' (enter key) or command mode to be disabled
        while ((commandMode == COMMAND_MODE_OFF) && (keypad_read() != '#')) { // treat '#' as enter case
            keypad_input[0] = keypad_read();

            // If a valid key is pressed, update attempted passcode and display on LCD
            if (keypad_input[0] != '\0') {
                attempted_passcode[i] = keypad_input[0];
                lcd_print(keypad_input);
                i++;
            } 
        }
        lcd_print("#");

        /* Check password */
        if(atoi(attempted_passcode) == atoi(correct_passcode)){
            // Unlock if locked, lock if unlocked
            if (LOCKED) {
                angle_int = 180;
                printf("UNLOCKING!\n");
                LOCKED = KEYPAD_UNLOCKED;
            } else if (!LOCKED) {
                angle_int = 0;
                printf("LOCKING!\n");
                LOCKED = KEYPAD_LOCKED;
            }
        } else {
            printf("INCORRECT PASSWORD!\n");
            angle_int = 0;
        }

        lcd_clear();
    }
}

/** @brief global parser variable */
atcmd_parser_t parser;
/** @brief init list of commands */
atcmd_t cmds[4];

/** 
 * @brief Command Task
 *
 * @details Handles commands received through UART, parses and executes corresponding functions.
 */
void command_task(){
    // init resume task
    cmds[0].cmdstr = "RESUME";
    cmds[0].fn = exit_command;
    cmds[0].args = NULL;

    // init hello task
    cmds[1].cmdstr = "HELLO";
    cmds[1].fn = print_hello;
    cmds[1].args = NULL;

    // init print passcode task
    cmds[2].cmdstr = "PASSCODE_PRINT";
    cmds[2].fn = print_passcode;
    cmds[2].args = NULL;

    // init passcode set task
    cmds[3].cmdstr = "PASSCODE_SET";
    cmds[3].fn = set_passcode;
    cmds[3].args = NULL;

    atcmd_parser_init(&parser, cmds, 4);

    while(1) { // check for ++ seq
        while (commandMode == COMMAND_MODE_OFF) {
            if (uart_get_byte(plus) == -1) continue;
            if (atcmd_detect_escape(&parser, plus[0])) 
                commandMode = COMMAND_MODE_ON;
        }
        read(STDIN, channel, 100);
        atcmd_parse(&parser, channel);
    }
}

/** 
 * @brief Main Function
 *
 * @details Initializes the system tasks and starts the FreeRTOS scheduler.
 * @return 0 (implicit) - The function does not return as the scheduler takes control.
 */
int main( void ) {
    commandMode = COMMAND_MODE_OFF;

    uart_init(1152000);
    strncpy(correct_passcode, (char*)"349", 50);

    xTaskCreate(Blinky_task, // blink led
                "BlinkyTask",
                CONFIG_MIN_STACK_SIZE,
                NULL,
                tskIDLE_PRIORITY+1,
                NULL);
    xTaskCreate(another_UART_task, // print hello
                "AnotherUART",
                CONFIG_MIN_STACK_SIZE,
                NULL,
                tskIDLE_PRIORITY+1,
                NULL);
    xTaskCreate(command_task, // handle at commands
                "command_task",
                CONFIG_MIN_STACK_SIZE,
                NULL,
                tskIDLE_PRIORITY+1,
                NULL);
    xTaskCreate(servo_LCD_Keypad_task, // handle keypad
                "Keypadtask",
                CONFIG_MIN_STACK_SIZE,
                NULL,
                tskIDLE_PRIORITY+1,
                NULL);

    vTaskStartScheduler();

    return 0;
}
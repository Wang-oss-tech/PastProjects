/**
 * @file systick.c
 * 
 * @brief SysTick Timer Configuration and Handling
 * 
 * @date 10/29/2023
 * 
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */

#include <unistd.h>
#include <systick.h>


/** @brief The Systic register map. */
struct stk_reg_map {
    volatile uint32_t STK_CTRL;   /**< SysTick control and status register */
    volatile uint32_t STK_LOAD;   /**< SysTick reload value register */
    volatile uint32_t STK_VAL;    /**< SysTick current value register */
    volatile uint32_t STK_CALIB;  /**< SysTick calibration value register */
};


/** @brief Base address for the SysTick register map */
#define STK_BASE (struct stk_reg_map *)0xE000E010


/** @brief SysTick exception request enable */
#define TICKINT 1 << 1

/** @brief Systick Counter enable*/
#define ENABLE 1

/** @brief Bitmask for extracting reload value in SysTick Control and Status Register */
#define RELOAD_MASK 0x0FFF

/** @brief Bit position for clock source selection in SysTick Control and Status Register */
#define CLKSOURCE 1 << 2

/** @brief Bit position for count flag in SysTick Control and Status Register */
#define COUNTFLAG 1 << 16

/** @brief Default reload value for SysTick timer (16000 cycles for 1ms interval at 16MHz) */
#define SYSTICK_RELOAD 16000


/** @brief Global Variable Timer Counter*/
volatile uint32_t t;

/**
 * @brief Initialize SysTick Timer
 *
 * This function configures the SysTick Timer with the specified settings.
 *
 */
void systick_init() {
    struct stk_reg_map *STK = STK_BASE;

    // enable systick control
    STK->STK_CTRL |= TICKINT;
    STK->STK_CTRL |= ENABLE;
    STK->STK_CTRL |= CLKSOURCE;
    // add enable

    // load tick/reload value
    STK->STK_LOAD |= SYSTICK_RELOAD;

    /* Set timer to zero */
    t = 0;
}


/**
 * @brief Delay Execution Using SysTick Timer
 *
 * This function introduces a delay in program execution using the SysTick Timer.
 *
 * @param ticks Number of SysTick timer ticks to delay
 */
void systick_delay(uint32_t ticks) {
    /* check for while loop condition */
    uint32_t temp = t;
    while (t <= (temp + ticks));
}


/**
 * @brief Get Current SysTick Timer Value
 *
 * This function retrieves the current value of the SysTick timer, which represents
 * the number of ticks elapsed since initialization.
 *
 * @return Current value of the SysTick timer
 */
uint32_t systick_get_ticks() {
    /* returns global variable */
    return t;
}

/**
 * @brief SysTick Interrupt Service Routine
 *
 * This function serves as the SysTick interrupt service routine (ISR).
 * It is called when the SysTick timer overflows, and it increments the
 * global counter `t`.
 */
void systick_c_handler() {
    /* increment global counter */
    struct stk_reg_map *STK = STK_BASE;
    while (!(STK->STK_CTRL | COUNTFLAG));
    t++;
}


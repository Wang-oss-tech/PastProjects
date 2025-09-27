/**
 * @file timer.c
 *
 * @brief Timer Control Functions
 * 
 * This file contains functions for initializing, disabling, and handling
 * timers. It also includes specific handlers for Timer 2, Timer 4, Timer 3, and Timer 5
 *
 * @date 10/29/2023
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <unistd.h>
#include <timer.h>
#include <rcc.h>
#include <nvic.h>
#include <gpio.h>

/**
 * @brief Macro definition for enabling the counter in the TIMx Control Register 1 (CR1).
 */
#define TIMx_CR1_CEN (1 << 0)

/**
 * @brief Macro definition for enabling the update request source in the TIMx Control Register 1 (CR1).
 */
#define TIMx_CR1_URS (1 << 4)

/**
 * @brief Macro definition for the update interrupt flag in the TIMx Status Register (SR).
 */
#define TIMx_SR_UIF (1 << 0)

/**
 * @brief Macro definition for enabling the update interrupt in the TIMx DMA/Interrupt Enable Register (DIER).
 */
#define TIMx_DIER_UIE (1 << 0)


/**
 * @brief Macro definition for the NVIC IRQ number associated with Timer 2.
 */
#define TIMER2_NVIC_IRQ 28

/**
 * @brief Macro definition for the NVIC IRQ number associated with Timer 4.
 */
#define TIMER4_NVIC_IRQ 30

/**
 * @brief Timer Value
 * 
 */
#define TIMER4 4

/** @brief Attribute for indicating that a variable is intentionally unused */
#define UNUSED __attribute__((unused))

/** @brief tim2_5 */
struct tim2_5 {
  volatile uint32_t cr1; /**< 00 Control Register 1 */
  volatile uint32_t cr2; /**< 04 Control Register 2 */
  volatile uint32_t smcr; /**< 08 Slave Mode Control */
  volatile uint32_t dier; /**< 0C DMA/Interrupt Enable */
  volatile uint32_t sr; /**< 10 Status Register */
  volatile uint32_t egr; /**< 14 Event Generation */
  volatile uint32_t ccmr[2]; /**< 18-1C Capture/Compare Mode */
  volatile uint32_t ccer; /**< 20 Capture/Compare Enable */
  volatile uint32_t cnt; /**< 24 Counter Register */
  volatile uint32_t psc; /**< 28 Prescaler Register */
  volatile uint32_t arr; /**< 2C Auto-Reload Register */
  volatile uint32_t reserved_1; /**< 30 */
  volatile uint32_t ccr[4]; /**< 34-40 Capture/Compare */
  volatile uint32_t reserved_2; /**< 44 */
  volatile uint32_t dcr; /**< 48 DMA Control Register */
  volatile uint32_t dmar; /**< 4C DMA address for full transfer Register */
  volatile uint32_t or; /**< 50 Option Register */
};

/** @brief  Timer-base array */
struct tim2_5* const timer_base[] = {(void *)0x0,           // N/A - Don't fill out
                                     (void *)0x0,           // N/A - Don't fill out
                                     (void *)0x40000000,    // Address for TIMER 2
                                     (void *)0x40000400,    // Address for TIMER 3
                                     (void *)0x40000800,    // Address for TIMER 4
                                     (void *)0x40000C00};   // Address for TIMER 5

/**
* Starts the timer
*
* @param timer - The timer
* @param prescaler - Prescalar for clock
* @param period - Period of the timer interrupt
*/
void timer_init(int timer, uint32_t prescaler, uint32_t period) {

    // enable the RCC
    struct rcc_reg_map *rcc = RCC_BASE;
    rcc->apb1_enr |= 1 << (timer - 2);
    struct tim2_5* tim = timer_base[timer];
    int IRQ_NUM;

    // Determine IRQ Number based on timer number 
    if (timer == 2){
        IRQ_NUM = 28;
    } else if (timer == 3){
        IRQ_NUM = 29;
    } else if (timer == 4){
        IRQ_NUM = 30;
    } else if (timer == 5){
        IRQ_NUM = 50;
    }
    nvic_irq(IRQ_NUM, IRQ_ENABLE); // enable NVIC for specific timer

    // Configure the timer by writing to its registers
    tim->psc = prescaler;
    tim->arr = period;

    tim->cr1 |=  TIMx_CR1_URS;

    // Enable the update interrupt
    tim->dier |= TIMx_DIER_UIE; 

    // Enable the timer, set CEN and URS
    tim->cr1 |=  TIMx_CR1_CEN;
}

/**
* Stops the timer
*
* @param timer - The timer
*/
void timer_disable(int timer) {
    // struct tim2_5* tim = timer_base[timer];
    struct rcc_reg_map *rcc = RCC_BASE;

    // disable timer
    rcc->apb1_enr &= ~(1 << (timer - 2)); // disable RCCC and URS
}

/**
* Clears the timer interrupt bit
*
* @param timer - The timer
*/
void timer_clear_interrupt_bit(int timer) {
    struct tim2_5* tim = timer_base[timer];
    tim->sr &= ~TIMx_SR_UIF; // Clear the interrupt bit (UIF) in the Status Register (SR)
}


/** @brief Global Variable for LED Toggle State*/
int led_on = 0;

/** 
 * @brief Timer Handler When Interrupt for Timer is Triggered
*/
void timer_4_handler() {
    nvic_irq(TIMER4_NVIC_IRQ, IRQ_DISABLE); // disable timer 4
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_DISABLE); // diable timer 2


    if (led_on == 0){ 
        /* LED is off, toggle on */
        gpio_set(GPIO_A, 1);
        led_on = 1;
    } else{ 
        /* LED is on, toggle off */
        gpio_clr(GPIO_A, 1);
        led_on = 0;
    }

    timer_clear_interrupt_bit(TIMER4);
    nvic_irq(TIMER4_NVIC_IRQ, IRQ_ENABLE); // enable timer 4
    nvic_irq(TIMER2_NVIC_IRQ, IRQ_ENABLE); // enable timer 2
}


/** 
 * @brief Calls Timer handler based off of timer specification
*/
void timer_3_handler(){
    // return nothing since we do not use this timer
    return; 
}

/** 
 * @brief Calls Timer handler based off of timer specification
*/
void timer_5_handler(){
    // return nothing since we do not use this timer
    return; 
}



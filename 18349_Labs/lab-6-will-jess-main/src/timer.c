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
#define TIMx_CR1_URS (1 << 2)

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

/**
 * @brief PWM Mode 1
 * 
 */
#define MODE_1 6

/**
 * @brief Enable
 * 
 */
#define ENABLE 1

/**
 * @brief Disable
 * 
 */
#define DISABLE 0

/**
 * @brief OC1M: Output compare 1 mode
 * 
 */
#define OC1M (MODE_1 << 4)

/**
 * @brief OC3M: Output compare 1 mode
 * 
 */
#define OC3M (MODE_1 << 4)

/**
 * @brief OC1PE: Output compare 1 preload enable
 * 
 */
#define OC1PE (1 << 3)

/**
 * @brief OC3PE: Output compare 1 preload enable
 * 
 */
#define OC3PE (1 << 3)

/**
 * @brief CC1E: Capture/Compare 1 output enable.
 * 
 */
#define CC1E (1 << 0)

/**
 * @brief OC2M: Output compare 2 mode
 * 
 */
#define OC2M (MODE_1 << 12)

/**
 * @brief OC4M: Output compare 2 mode
 * 
 */
#define OC4M (MODE_1 << 12)

/**
 * @brief OC2PE: Output compare 2 preload enable
 * 
 */
#define OC2PE (1 << 11)

/**
 * @brief OC4PE: Output compare 2 preload enable
 * 
 */
#define OC4PE (1 << 11)

/**
 * @brief CC2E: Capture/Compare 2 output enable.
 * 
 */
#define CC2E (1 << 4)

/**
 * @brief CC3E: Capture/Compare 3 output enable.
 * 
 */
#define CC3E (1 << 8)

/**
 * @brief CC4E: Capture/Compare 4 output enable.
 * 
 */
#define CC4E (1 << 12)

/**
 * @brief ARPE: Capture/Compare 4 output enable.
 * 
 */
#define ARPE (1 << 7)

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
* @brief Starts the timer
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

    // Enable the timer, set CEN
    tim->cr1 |=  TIMx_CR1_CEN;
}

/**
 * @brief Initialize and start PWM mode on a specified timer channel.
 *
 * This function enables the specified timer, configures it for PWM mode on the given channel,
 * and sets the prescaler, period, and initial duty cycle. It also configures the associated GPIO pin.
 *
 * @param timer The timer number to be initialized.
 * @param channel The timer channel (1 to 4) to be configured for PWM.
 * @param prescaler The prescaler value for the timer.
 * @param period The period value for the timer.
 * @param duty_cycle The initial duty cycle value (0 to period).
 */
void timer_start_pwm(int timer, uint32_t channel, uint32_t prescaler, uint32_t period, uint32_t duty_cycle) {
    // Enable clock
    struct rcc_reg_map *rcc = RCC_BASE;
    rcc->apb1_enr |= 1 << (timer - 2);

    struct tim2_5* tim = timer_base[timer];

    gpio_init(GPIO_B, 10, MODE_ALT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT1); //D6
    tim->psc = prescaler;
    tim->arr = period; 
    
    // uint32_t duty_cycle_value = (duty_cycle / period) * 100;
    
    // Configure timer for PWM mode
    if (channel == 1) {
        // CCMR1
        tim->ccr[0] = duty_cycle; 
        tim->ccmr[0] |= OC1M; 
        tim->ccmr[0] |= OC1PE; 
        tim->ccer |= CC1E;
    } else if (channel == 2) {
        // CCMR1
        tim->ccr[1] = duty_cycle;
        tim->ccmr[0] |= OC2M; 
        tim->ccmr[0] |= OC2PE; 
        tim->ccer |= CC2E;
    } else if (channel == 3) {
        // CCMR2
        tim->ccr[2] = duty_cycle;
        tim->ccmr[1] |= OC3M; 
        tim->ccmr[1] |= OC3PE; 
        tim->ccer |= CC3E;
        // tim->ccr[2] = duty_cycle;
    } else if (channel == 4) {
        // CCMR2
        tim->ccr[3] = duty_cycle;
        tim->ccmr[1] |= OC4M; 
        tim->ccmr[1] |= OC4PE; 
        tim->ccer |= CC4E;
    }
 
    // tim->egr |= 1;
    tim->cr1 |= ARPE;  // ARPE bit in the TIMx_CR1 (autorelaod preload reg)
    tim->egr |= 1;

    // Enable the timer, set CEN
    tim->cr1 |= (TIMx_CR1_CEN);

}

/**
 * @brief Set the duty cycle of a specified timer channel.
 *
 * This function updates the duty cycle of the specified timer channel without reconfiguring other settings.
 *
 * @param timer The timer number where the duty cycle will be updated.
 * @param channel The timer channel (1 to 4) whose duty cycle will be modified.
 * @param duty_cycle The new duty cycle value (0 to period).
 */
void timer_set_duty_cycle(int timer, uint32_t channel, uint32_t duty_cycle) {
    struct tim2_5* tim = timer_base[timer];

    // Calculate the duty cycle value
    uint32_t period = tim->arr;
    if (duty_cycle > period) return; // error case

    if (channel == 1) tim->ccr[0] = duty_cycle; 
    else if (channel == 2) tim->ccr[1] = duty_cycle;
    else if (channel == 3) tim->ccr[2] = duty_cycle;
    else tim->ccr[3] = duty_cycle;
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

/**
* Stops the timer
*
* @param timer - The timer
*/
void timer_disable(int timer) {
    struct rcc_reg_map *rcc = RCC_BASE;

    // disable timer
    rcc->apb1_enr &= ~(1 << (timer - 2)); // disable RCCC and URS
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
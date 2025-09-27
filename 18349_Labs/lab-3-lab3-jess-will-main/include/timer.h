/**
 * @file timer.h
 *
 * @brief Timer Control Function Prototypes and Definitions
 *
 * This header file declares function prototypes and defines constants
 * for controlling timers. It includes initialization, disabling, and interrupt handling
 * functions for various timers.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */

#ifndef _TIMER_H_
#define _TIMER_H_

/**
 * @brief TIMx Register Bit Constants
 * 
 */

#define TIMx_CR1_CEN (1 << 0)
#define TIMx_CR1_URS (1 << 4)
#define TIMx_SR_UIF (1 << 0) 
#define TIMx_DIER_UIE (1 << 0)

/**
 * @brief NVIC IRQ Number
 * 
 */
#define TIMER2_NVIC_IRQ 28
#define TIMER4_NVIC_IRQ 30

/**
 * @brief Timer Value
 * 
 */
#define TIMER4 4

void timer_init(int timer, uint32_t prescalar, uint32_t period);

void timer_disable(int timer);

void timer_clear_interrupt_bit(int timer);

void timer_handler(int timer);

void timer_2_handler();

void timer_3_handler();

void timer_4_hander();

void timer_5_hander();

#endif /* _TIMER_H_ */

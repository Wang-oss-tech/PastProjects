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

void timer_init(int timer, uint32_t prescalar, uint32_t period);

void timer_disable(int timer);

void timer_clear_interrupt_bit(int timer);

#endif /* _TIMER_H_ */

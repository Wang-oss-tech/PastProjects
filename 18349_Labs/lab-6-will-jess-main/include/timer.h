#ifndef _TIMER_H_
#define _TIMER_H_

#include <unistd.h>
#include <gpio.h>

#define TIM2_INT_NUM    28
#define TIM3_INT_NUM    29
#define TIM4_INT_NUM    30
#define TIM5_INT_NUM    50

void timer_start_pwm(int timer, uint32_t channel, uint32_t prescalar, uint32_t period, uint32_t duty_cycle);

void timer_set_duty_cycle(int timer, uint32_t channel, uint32_t duty_cycle);

void timer_init(int timer, uint32_t prescalar, uint32_t period);

void timer_disable(int timer);

void timer_clear_interrupt_bit(int timer);

#endif /* _TIMER_H_ */

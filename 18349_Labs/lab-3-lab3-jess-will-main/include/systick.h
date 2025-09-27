/**
 * @file systick.h
 *
 * @brief SysTick Timer Function Prototypes
 *
 * This header file declares function prototypes for initializing, utilizing,
 * and handling the SysTick timer. It provides functions for delay, time tracking,
 * and a SysTick interrupt handler.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */


#ifndef _SYSTICK_H_
#define _SYSTICK_H_

void systick_init();

void systick_delay();

uint32_t systick_get_ticks();

void systick_c_handler();

#endif /* _SYSTICK_H_ */

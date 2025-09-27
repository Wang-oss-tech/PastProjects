/**
 * @file servo.h
 *
 * @brief Servo Control Function Prototypes
 *
 * This header file declares function prototypes for initializing, enabling,
 * and setting angles for servos. It provides functions to control servo motors.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */

#ifndef _SERVO_H_
#define _SERVO_H_

int servo_enable(uint8_t channel, uint8_t enabled);

int servo_set(uint8_t channel, uint8_t angle);

#endif /* _SERVO_H_ */

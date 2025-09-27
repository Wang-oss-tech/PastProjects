/**
 * @file i2c.h
 *
 * @brief I2C Communication Function Prototypes
 *
 * This header file declares function prototypes for initializing and
 * performing I2C communication as a master device. It provides functions
 * for starting, stopping, writing to, and reading from I2C devices.
 *
 * @date 10/29/2023
 * @authors William Wang (www2), Jessica Chan (jchan4)
 */


#ifndef _I2C_H_
#define _I2C_H_

#include <stdint.h>

void i2c_master_init(uint16_t clk);

void i2c_master_start();

void i2c_master_stop();

int i2c_master_write(uint8_t *buf, uint16_t len, uint8_t slave_addr);

int i2c_master_read(uint8_t *buf, uint16_t len, uint8_t addr);

#endif /* _I2C_H_ */

/**
 * @file i2c.h
 *
 * @brief Header file for I2C communication.
 *
 * @date 2023-11-09
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
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

// James Zhang
#ifndef _ADC_H_
#define _ADC_H_

#include <unistd.h>

void adc_init();
uint16_t adc_read_chan(uint8_t chan);

#endif /* _ADC_H_ */

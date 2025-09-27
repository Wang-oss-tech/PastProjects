/**
 * @file adc.c
 *
 * @brief ADC file that initializes the necessary bits for ADC initialization and
 * 		  converts analog signal to digial signal with channel specification
 *
 * @date 11/21/2023
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <gpio.h>
#include <stdint.h>
#include <rcc.h>
#include <unistd.h>
#include <adc.h>
#include <FreeRTOS.h>
#include <task.h>

/** @brief ADC map base address */
#define ADC_BASE (struct adc_reg_map *) 0x40012000

/**
 * @struct adc_reg_map
 * @brief ADC register map structure
 */
struct adc_reg_map {
    volatile uint32_t ADC_SR;  		/**< ADC Status Register */
    volatile uint32_t ADC_CR1;  	/**< ADC Control Register 1*/
    volatile uint32_t ADC_CR2; 		/**< ADC Control Register 2*/
    volatile uint32_t ADC_SMPR1; 	/**< ADC Sample Time Register 1*/
    volatile uint32_t ADC_SMPR2;  	/**< ADC Sample Time Register 2*/
    volatile uint32_t ADC_JORF1;  	/**< ADC Injected Channel Data Offset Register 1 */
    volatile uint32_t ADC_JORF2;  	/**< ADC Injected Channel Data Offset Register 2 */
    volatile uint32_t ADC_JORF3;  	/**< ADC Injected Channel Data Offset Register 3 */
    volatile uint32_t ADC_JORF4;	/**< ADC Injected Channel Data Offset Register 4 */
    volatile uint32_t ADC_HTR; 		/**< ADC Higher Threshold Register */
	volatile uint32_t ADC_LTR;		/**< ADC Lower Threshold Register */
	volatile uint32_t ADC_SQR1;		/**< ADC Regular Sequence Register 1 */
	volatile uint32_t ADC_SQR2;		/**< ADC Regular Sequence Register 2 */
	volatile uint32_t ADC_SQR3;		/**< ADC Regular Sequence Register 3 */
	volatile uint32_t ADC_JSQR;		/**< ADC Injected Sequence Register */
	volatile uint32_t ADC_JDR1;		/**< ADC Injected Data Register 1 */
	volatile uint32_t ADC_JDR2;		/**< ADC Injected Data Register 2 */
	volatile uint32_t ADC_JDR3;		/**< ADC Injected Data Register 3 */
	volatile uint32_t ADC_JDR4;		/**< ADC Injected Data Register 4 */
	volatile uint32_t ADC_DR;		/**< ADC Data Register*/
	volatile uint32_t ADC_CCR;		/**< ADC Common Control Register */
};

/** @brief 10-bit resolution for ADC Control Register 1 */
#define ADC_CR1_RES_10 (1 << 24)

/** @brief Turns on ADC */
#define ADC_CR2_ADON (1 << 0)

/** @brief Start conversion of regular channels 
* This bit is set by software to start conversion
* and cleared by hardware as soon as the conversion starts.
* 0: Reset state
* 1: Starts conversion of regular channels
* Note: This bit can be set only when ADON = 1 otherwise no conversion is launched
*/
#define ADC_CR2_SWSTART (1 << 30)

/** @brief Peripheral clock enable bit for ADC1*/
#define ADC1EN (1 << 8)

/** @brief End of conversion */
#define EOC (1 << 1)


/** @brief MMIO initialization of the ADC Converter */
void adc_init() {
	/* Initialize GPIO Pins */
	gpio_init(GPIO_A, 4, MODE_ANALOG_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // A2, PA_4 (Channel = 4) (Temperature)
	gpio_init(GPIO_A, 0, MODE_ANALOG_INPUT, OUTPUT_PUSH_PULL, OUTPUT_SPEED_LOW, PUPD_NONE, ALT0); // A0, PA_0 (Channel = 0)

	/* Define base address for ADC */
	struct adc_reg_map *ADC = ADC_BASE;

	/* Enable clock of ADC */
	struct rcc_reg_map *adc_clock = RCC_BASE;
    adc_clock->apb2_enr |= ADC1EN;

	/* Set ADC to 10-bit resolution */
	ADC->ADC_CR1 |= ADC_CR1_RES_10;

	/* Enable ADC */
	ADC->ADC_CR2 |= ADC_CR2_ADON;
	return;
}

/** @brief Function that reads converts analog value to digital 
 * 	@param chan Channel Number 
*/
uint16_t adc_read_chan(uint8_t chan) { 
	taskENTER_CRITICAL(); 

	/* Define base address for ADC */
	struct adc_reg_map *ADC = ADC_BASE;

	/* Bit 25 reads into the Channel Number */
	ADC->ADC_SQR3 = chan;

	/* Start ADC conversion */
	ADC->ADC_CR2 |= ADC_CR2_SWSTART;

	// while (!(ADC->ADC_SR |= EOC)); // while not fin converting
	while (!(ADC->ADC_SR & EOC));

	/* Read result from regular DR */
	uint16_t result = ADC->ADC_DR;

	taskEXIT_CRITICAL();
	// An interrupt is generated if the EOCIE bit is set, something to get back to
	return result;
}
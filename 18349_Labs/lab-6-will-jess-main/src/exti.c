/**
 * @file exti.c
 *
 * @brief EXTI file that implements the interrupts that is triggered by button/motor
 *
 * @date 12/4/2023
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <exti.h>
#include <gpio.h>
#include <rcc.h>
#include <nvic.h>
#include <stdio.h>

/** @brief Definition of unused parameter */
#define UNUSED __attribute__((unused))

/** @brief EXTI Register Map */
struct exti_reg_map {
    volatile uint32_t EXTI_IMR;     /**< Interrupt Mask Register */
    volatile uint32_t EXTI_EMR;     /**<  Event mask register */
    volatile uint32_t EXTI_RTSR;    /**<  Rising trigger selection register*/
    volatile uint32_t EXTI_FTSR;    /**<  Falling trigger selection register */
    volatile uint32_t EXTI_SWIER;   /**<  Software interrupt event register */
    volatile uint32_t EXTI_PR;      /**<  Pending register */
};

/** @brief Syscfg Register Map */
struct syscfg_reg_map {
    volatile uint32_t SYSCFG_MEMRMP;    /**<  SYSCFG Memory Remap Register */
    volatile uint32_t SYSCFG_PMC;       /**<  SYSCFG Peripheral Mode Configuration Register */
    volatile uint32_t SYSCFG_EXTICR1;   /**<  SYSCFG External Interrupt Configuration Register 1 */
    volatile uint32_t SYSCFG_EXTICR2;   /**<  SYSCFG External Interrupt Configuration Register 2 */
    volatile uint32_t SYSCFG_EXTICR3;   /**<  SYSCFG External Interrupt Configuration Register 3 */
    volatile uint32_t SYSCFG_EXTICR4;   /**<  SYSCFG External Interrupt Configuration Register 4 */
    volatile uint32_t SYSCFG_EXTICMPCR; /**<  SYSCFG External Interrupt CMPCR */
};

// need to define values of enum??

/** @brief Base address for EXTI */
#define EXTI_BASE  (struct exti_reg_map *) 0x40013C00

/** @brief Base address for SYSCFG */
#define SYSCFG_BASE (struct syscfg_reg_map *) 0x40013800 

/** @brief System configuration controller clock enable */
#define SYSCFG_EN (1 << 14)

/** @brief Counter vairable*/
int count_1 = 0;

/**
 * @brief Enable external interrupts on a given channel.
 */
void enable_exti(gpio_port port, uint32_t channel, exti_edge edge) {
    struct rcc_reg_map *rcc = RCC_BASE;
    struct syscfg_reg_map *syscfg = SYSCFG_BASE;
    struct exti_reg_map *exti = EXTI_BASE;

    uint32_t mask = 0;

    // enable configuration controller clock
    rcc->apb2_enr |= SYSCFG_EN; // enables SYSCFG configuration controller clock, page 122 of m4 reference manual

    // Disable EXTI Mask
    exti->EXTI_IMR |= 1 << channel; // enabling bit will unmask the channel specific interrupt request

    // Configure Rising/Falling Edge Trigger
    if (edge == EXTI_RISING_EDGE) {
        exti->EXTI_RTSR |= (1 << channel);
        exti->EXTI_FTSR &= ~(1 << channel);
    } else if (edge == EXTI_FALLING_EDGE) {
        exti->EXTI_RTSR &= ~(1 << channel);
        exti->EXTI_FTSR |= (1 << channel);
    } else if (edge == EXTI_RISING_FALLING_EDGE) {
        exti->EXTI_RTSR |= (1 << channel);
        exti->EXTI_FTSR |= (1 << channel);
    }

    if (port == GPIO_A) mask = 0x0;
    else if (port == GPIO_B) mask = 0x1;
    else if (port == GPIO_C) mask = 0x2;

    if (channel <= 3){
        if (channel == 0){
            syscfg->SYSCFG_EXTICR1 |= (mask << channel);
            nvic_irq(6, IRQ_ENABLE);
        } else if (channel == 1){
            syscfg->SYSCFG_EXTICR1 |= (mask << (channel*4));
            nvic_irq(7, IRQ_ENABLE);
        } else if (channel == 2){
            syscfg->SYSCFG_EXTICR1 |= (mask << (channel*4));
            nvic_irq(8, IRQ_ENABLE);
        } else if (channel == 3){
            syscfg->SYSCFG_EXTICR1 |= (mask << (channel*4));
            nvic_irq(9, IRQ_ENABLE);
        }
    } else if ((channel >= 4 && channel <= 7)){
        if (channel == 4){
            syscfg->SYSCFG_EXTICR2 |= (mask << (channel % 4));
            nvic_irq(10, IRQ_ENABLE);
        } else if (channel == 5){
            syscfg->SYSCFG_EXTICR2 |= (mask << ((channel % 4)*4));
            nvic_irq(23, IRQ_ENABLE);
        } else if (channel == 6){
            syscfg->SYSCFG_EXTICR2 |= (mask << ((channel % 4)*4));
            nvic_irq(23, IRQ_ENABLE);
        } else if (channel == 7){
            syscfg->SYSCFG_EXTICR2 |= (mask << ((channel % 4)*4));
            nvic_irq(23, IRQ_ENABLE);
        }
    } else if ((channel >= 8 && channel <= 11)){
        if (channel == 8){
            syscfg->SYSCFG_EXTICR3 |= (mask << (channel % 4));
            nvic_irq(23, IRQ_ENABLE);
        } else if (channel == 9){
            syscfg->SYSCFG_EXTICR3 |= (mask << ((channel % 4)*4));
            nvic_irq(23, IRQ_ENABLE);
        } else if (channel == 10){
            syscfg->SYSCFG_EXTICR3 |= (mask << ((channel % 4)*4));
            nvic_irq(40, IRQ_ENABLE);
        } else if (channel == 11){
            syscfg->SYSCFG_EXTICR3 |= (mask << ((channel % 4)*4));
            nvic_irq(40, IRQ_ENABLE);
        }
    } else if ((channel >= 12 && channel <= 15)){
        if (channel == 12){
            syscfg->SYSCFG_EXTICR4 |= (mask << (channel % 4));
            nvic_irq(40, IRQ_ENABLE);
        } else if (channel == 13){
            syscfg->SYSCFG_EXTICR4 |= (mask << ((channel % 4)*4));
            nvic_irq(40, IRQ_ENABLE);
        } else if (channel == 14){
            syscfg->SYSCFG_EXTICR4 |= (mask << ((channel % 4)*4));
            nvic_irq(40, IRQ_ENABLE);
        } else if (channel == 15){
            syscfg->SYSCFG_EXTICR4 |= (mask << ((channel % 4)*4));
            nvic_irq(40, IRQ_ENABLE);
        }
    }
}

/**
 * @brief Disable External Interrupt (EXTI) for a specific channel.
 * 
 * This function disables the EXTI for the specified channel, preventing the corresponding
 * external interrupt from triggering further interrupts. It clears the EXTI Interrupt Mask
 * Register (EXTI_IMR) for the specified channel.
 * 
 * @param channel The EXTI channel to be disabled.
 */
void disable_exti(uint32_t channel) {
    struct exti_reg_map *exti = EXTI_BASE;
    // Disable EXTI Mask
    exti->EXTI_IMR &= ~(1 << channel); // enabling bit will unmask the channel specific interrupt request
}

/**
 * @brief When entering an external interrupt handler, immediately clear the corresponding pending bit of
          channel in the pending register
 */
void exti_clear_pending_bit(uint32_t channel) {
    struct exti_reg_map *exti = EXTI_BASE;
    exti->EXTI_PR |= (1 << channel);
}

/** @brief EXTI Line 0 interrupt handler.
 * This handler is triggered when EXTI Line 0 is activated.
 */
void exti0_handler() {
    asm("bkpt");
}

/** @brief EXTI Line 1 interrupt handler.
 * This handler is triggered when EXTI Line 1 is activated.
 */
void exti1_handler() {
    asm("bkpt");
}

/** @brief EXTI Line 2 interrupt handler.
 * This handler is triggered when EXTI Line 2 is activated.
 */
void exti2_handler() {
    asm("bkpt");
}

/** @brief EXTI Line 3 interrupt handler.
 * This handler is triggered when EXTI Line 3 is activated.
 */
void exti3_handler() {
    asm("bkpt");
}

/** @brief EXTI Line 4 interrupt handler.
 * This handler is triggered when EXTI Line 4 is activated.
 */
void exti4_handler() {
    asm("bkpt");
}

/** @brief EXTI Lines 9 to 5 interrupt handler.
 * This handler is triggered when EXTI Lines 9 to 5 are activated.
 * Clears the pending bit for Line 5 and increments a counter.
 */
void exti9_5_handler() {
    exti_clear_pending_bit(5);
    count_1++;
}

/** @brief EXTI Lines 15 to 10 interrupt handler.
 * This handler is triggered when EXTI Lines 15 to 10 are activated.
 */
void exti15_10_handler() {
    asm("bkpt");
}

.syntax unified
.cpu cortex-m4
.fpu softvfp
.thumb

.global optimize_me
optimize_me:
    ldr r1, =0x20000814
    ldr r2, =0x2000042c
    movw r3, #250

loop:
    ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	   ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

	ldr     r4, [r1]
    str     r4, [r2]
    adds    r1, r1, #4
    adds    r2, r2, #4

    subs    r3, r3, #25
    bne     loop

    bx      lr

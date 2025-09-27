/** @file arm.h
 *
 *  @brief  Assembly wrappers for arm instructions.
 *
 *  @date   March 27, 2019
 *
 *  @author Ronit Banerjee <ronitb@andrew.cmu.edu>
 */
#ifndef _ARM_H_
#define _ARM_H_

#define intrinsic __attribute__( ( always_inline ) ) static inline

/**
 * @brief      Sets a breakpoint.
 */
intrinsic void breakpoint( void ) {
  __asm volatile( "bkpt" );
}

#undef intrinsic

#endif /* _ARM_H_ */

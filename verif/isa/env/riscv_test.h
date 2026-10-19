#ifndef _ENV_PHYSICAL_SINGLE_CORE_H
#define _ENV_PHYSICAL_SINGLE_CORE_H

#include "../../riscv-tests/isa/macros/scalar/test_macros.h"

#define TESTNUM gp

#define RVTEST_RV32U
#define RVTEST_RV64U

#define RVTEST_CODE_BEGIN           \
    .section .text.init;            \
    .align 4;                       \
    .globl _start;                  \
_start:                             \
    li TESTNUM, 0;

#define RVTEST_CODE_END

#define RVTEST_DATA_BEGIN           \
    .section .data;                 \
    .align 4;

#define RVTEST_DATA_END

#define RVTEST_PASS                 \
pass:                               \
    li a0, 0;                       \
    ecall;                          \
1:  j 1b;

#define RVTEST_FAIL                 \
fail:                               \
    li a0, 1;                       \
    ecall;                          \
1:  j 1b;

#endif


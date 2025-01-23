#include <stdio.h>
#include <stdlib.h>
#include "rvconfig.h"

void user_trap_handler(void) {
    int mcause = CSRR_MCAUSE();
    int mepc = CSRR_MEPC();
    int mtval = CSRR_MTVAL();

    printf("exception %d: ", mcause & 0x7fffffff);

    if (!(mcause & 0x80000000)) {
        // 0: Instruction address misaligned
        if ((mcause & 0x7fffffff) == 0) {
            printf("instruction address misaligned, EPC: %08x, MTVAL: %08x\n", mepc, mtval);
        }
        // 4: Load address misaligned
        if ((mcause & 0x7fffffff) == 4) {
            printf("load address misaligned, EPC: %08x, MTVAL: %08x\n", mepc, mtval);
        }
        // 5: Load access fault
        if ((mcause & 0x7fffffff) == 5) {
            printf("load access fault, EPC: %08x, MTVAL: %08x\n", mepc, mtval);
        }
        // 6: Store/AMO address misaligned
        if ((mcause & 0x7fffffff) == 6) {
            printf("store address misaligned, EPC: %08x, MTVAL: %08x\n", mepc, mtval);
        }
        // 7: Store access fault
        if ((mcause & 0x7fffffff) == 7) {
            printf("store access fault, EPC: %08x, MTVAL: %08x\n", mepc, mtval);
        }

        CSRW_MEPC(CSRR_MEPC()+4);
    }
}

__attribute__((noinline))
void foo(volatile int *ptr) {
    volatile short *ptr2 = (volatile short*)ptr;
    (*ptr)++;
    (*ptr2)++;
    printf("foo()\n");
}

int main(void) {
    static int test;
    void (*func_ptr1)(void*) = (void(*)(void*))((int)foo | 1);
    void (*func_ptr2)(void*) = (void(*)(void*))((int)foo | 2);

    // load/store address misalignment
    foo((int*)((int)(&test) | 1));

    // instruction address misalignment
    func_ptr1(&test);
    func_ptr2((void*)NULL);

    // foo((volatile int*)0);

    return 0;
}


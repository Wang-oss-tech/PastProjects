#include <stdint.h>

int main() {
    volatile int a = 10, b = 20, c = -10, d = -20;
    int test_status = 1;  // Assume tests pass

    // **BEQ: Branch if Equal**
    if (a == 10) {
        // Expected behavior
    } else {
        test_status = 0;
    }

    // **BNE: Branch if Not Equal**
    if (a != b) {
        // Expected behavior
    } else {
        test_status = 0;
    }

    // **BLT: Branch if Less Than (Signed)**
    if (c < a) {
        // Expected behavior
    } else {
        test_status = 0;
    }

    // **BGE: Branch if Greater or Equal (Signed)**
    if (a >= c) {
        // Expected behavior
    } else {
        test_status = 0;
    }

    // **BLTU: Branch if Less Than (Unsigned)**
    if ((uint32_t)c < (uint32_t)a) {  
        test_status = 0; // -10 (converted to unsigned) is large, should NOT branch
    }

    // **BGEU: Branch if Greater or Equal (Unsigned)**
    if ((uint32_t)a >= (uint32_t)c) {
        // Expected behavior
    } else {
        test_status = 0;
    }

    // **Return 0 if all tests pass, else return 1**
    return test_status ? 0 : 1;
}

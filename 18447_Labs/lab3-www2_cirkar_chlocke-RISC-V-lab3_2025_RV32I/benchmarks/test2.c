#include <stdint.h>

int main() {
    volatile int x = 5, y = 10;
    int result = 0;

    // BEQ: Should NOT branch
    if (x == y) {
        result = 1;
    }

    // BNE: Should branch
    if (x != y) {
        result += 2;
    }

    // BLT: Should branch
    if (x < y) {
        result += 4;
    }

    // BGE: Should NOT branch
    if (x >= y) {
        result = 99;
    }

    // Return final result (Expected: 6 if all branches work correctly)
    return result;
}

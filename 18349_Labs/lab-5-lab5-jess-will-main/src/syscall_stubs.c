/**
 * @file syscall_stubs.c
 *
 * @brief Implementation of system calls for custom memory allocation, input/output, and program exit.
 *
 * @date 2023-11-09
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <uart.h>

/** @brief Built-in file descriptors */
//@{
#define FD_STDIN    0
#define FD_STDOUT   1
//@}

extern char __heap_low;
extern char __heap_top;

char* program_break = &__heap_low;


/** @brief _sbrk allocates more area in the heap which can be used
 *  by the user caller */
void *_sbrk(int incr) {
    if (incr == 0) return (void*) program_break;
    char* old = program_break;
    char* tmp = program_break + incr;
    if (tmp <= &__heap_top && tmp >= &__heap_low) {
        program_break = tmp;
        return (void*)old;
    }
    return (void*)-1; // error
}

/** @brief _write allows the user to write things to STDOUT */
int _write(int file, char *ptr, int len) {
    return uart_write(file, ptr, len);
}

/** @brief _read allows the user to read from STDIN */
int _read(int file, char *ptr, int len) {
    return uart_read(file, ptr, len);
}

/** @brief _exit exits from the current user program by printing the
 *  status, then going into sleep mode. */
void _exit(int status) {
    (void)status;
    printf("%d",status);
    fflush(stdout);
    while (1);
}

/**
 * @brief Placeholder function for closing a file descriptor.
 *
 * This function is a placeholder and always returns an error code (-1) as it does not perform any actual file closure.
 *
 * @param file File descriptor (unused)
 * @return Always returns -1
 */
int _close(int file) {
    (void)file;
    return -1;
}


/**
 * @brief Get file status information for a file descriptor.
 *
 * This function populates the provided `struct stat` pointer `st` with information about the file descriptor `file`.
 * In this implementation, it sets the file type to character device.
 *
 * @param file File descriptor (unused)
 * @param st   Pointer to a struct stat to be populated
 * @return Always returns 0 (success)
 */
int _fstat(int file, struct stat *st) {
    (void)file;
    st->st_mode = S_IFCHR;
    return 0;
}


/**
 * @brief Check if a file descriptor refers to a terminal device.
 *
 * This function checks if the provided file descriptor `file` corresponds to either standard input (FD_STDIN) or standard output (FD_STDOUT).
 * If so, it returns 1 to indicate that it is a terminal device; otherwise, it returns 0.
 *
 * @param file File descriptor to check
 * @return 1 if file descriptor is associated with a terminal device, 0 otherwise
 */
int _isatty(int file) {
    if (file == FD_STDIN || file == FD_STDOUT) return 1;
    else return 0;
}


/**
 * @brief Set the file position for a file descriptor.
 *
 * This function sets the file position for the specified file descriptor `file` based on the `ptr` offset and `dir` direction.
 * In this implementation, the function does nothing and always returns 0.
 *
 * @param file File descriptor (unused)
 * @param ptr  Offset for the file position (unused)
 * @param dir  Direction for seeking (unused)
 * @return Always returns 0 (success)
 */
int _lseek(int file, int ptr, int dir) {
    (void)file;
    (void)ptr;
    (void)dir;
    return 0;
}

/**
 * @file atcmd.c
 *
 * @brief This file contains the implementation of an AT command parser.
 *
 * @date 2023-11-09
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#include <atcmd.h>
#include <string.h>

/**
 * @brief This macro marks a variable or function as intentionally unused, 
 *        suppressing compiler warnings about unused entities.
 */
#define UNUSED __attribute__((unused))


/** @brief Global counter variable for +++*/
int counter;


/**
 * @brief Initializes the AT command parser
 *
 * @param parser Pointer to the AT command parser structure
 * @param atcmds Array of supported AT commands
 * @param num_atcmds Number of supported AT commands
 */
void atcmd_parser_init(atcmd_parser_t *parser, const atcmd_t *atcmds, uint32_t num_atcmds) {
    memset(parser, 0x00, sizeof(atcmd_parser_t));
    parser->atcmds = atcmds;
    parser->num_atcmds = num_atcmds;
}


/**
 * @brief Detects escape sequence
 *
 * @param parser Pointer to the AT command parser structure (UNUSED)
 * @param c Character to check for escape sequence
 * @return 1 if escape sequence detected, otherwise 0
 */
uint8_t atcmd_detect_escape(UNUSED atcmd_parser_t *parser, char c) {
    if (c == '+') counter++;
    else counter = 0; // reset counter if not consecutive

    /* Turn command mode on when +++ is detected three consecutive times*/
    if (counter == 3) {
        counter = 0;
        return 1;
    }
    
    return 0; // no +++ detected
}


/**
 * @brief Parses AT command
 *
 * @param parser Pointer to the AT command parser structure (UNUSED)
 * @param cmd Input AT command string
 * @return Always returns 0 (assuming successful parsing for this example)
 */
uint8_t atcmd_parse(UNUSED atcmd_parser_t *parser, char *cmd) {
    atcmd_t command;
    char arg[100];
    
    // Check for specific AT commands and execute corresponding functions
    if (strncmp(cmd, "AT+RESUME\r", 10) == 0) {
        // Retrieve the appropriate command structure
        command = parser->atcmds[0];
        // Call the associated function with arguments from the command
        (*command.fn)(command.args, cmd);
    } else if (strncmp(cmd, "AT+HELLO=", 9) == 0) {
        // Retrieve the appropriate command structure
        command = parser->atcmds[1];

        int i = 9;
        // Extract arguments from the command
        while ((cmd[i] != '\r')){
            arg[i-9] = cmd[i];
            i++;
        }
        // Call the associated function with extracted arguments
        (*command.fn)(arg, cmd);
    } else if (strncmp(cmd, "AT+PASSCODE=", 12) == 0){ // set passcode
        // Retrieve the appropriate command structure
        command = parser->atcmds[3];

        int j = 12;
        // Extract arguments from the command
        while((cmd[j] != '\r')){
            arg[j-12] = cmd[j];
            j++;
        }
        // Call the associated function with extracted arguments
        (*command.fn)(arg, cmd);
    } else if (strncmp(cmd, "AT+PASSCODE?", 12) == 0){ // print passcode
        // Retrieve the appropriate command structure
        command = parser->atcmds[2];
        // Call the associated function with its arguments
        (*command.fn)(command.args, cmd);
    }

    // Assuming successful parsing, return 0
    return 0;
}
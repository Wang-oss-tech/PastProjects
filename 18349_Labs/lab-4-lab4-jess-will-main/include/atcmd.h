/**
 * @file atcmd.h
 *
 * @brief Defines structures and functions for an AT command parser.
 *
 * @date 2023-11-09
 *
 * @author William Wang (www2) and Jessica Chan (jchan4)
 */

#ifndef _ATCMD_H_
#define _ATCMD_H_

#include <stdint.h>

typedef uint8_t (*atcmd_fn_t)(void *args, const char *cmdargs);

typedef struct {
    const char *cmdstr;
    atcmd_fn_t fn;
    void *args;
} atcmd_t;

typedef struct atcmd_parser {
    const atcmd_t *atcmds;
    uint32_t num_atcmds;
} atcmd_parser_t;

void atcmd_parser_init(atcmd_parser_t *parser, const atcmd_t *atcmds, uint32_t num_atcmds);
uint8_t atcmd_detect_escape(atcmd_parser_t *parser, char c);
uint8_t atcmd_parse(atcmd_parser_t *parser, char *cmd);

#endif /* _ATCMD_H_ */
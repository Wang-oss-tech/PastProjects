#ifndef _ATCMD_H_
#define _ATCMD_H_

#include <stdint.h>

#define ATCMD_ESCAPE_STR      "+++"
#define ATCMD_ESCAPE_STRLEN   (3)

typedef uint8_t (*atcmd_fn_t)(void *args, const char *cmdargs);

typedef struct {
    const char *cmdstr;
    atcmd_fn_t fn;
    void *args;
} atcmd_t;

typedef struct atcmd_parser {
    const atcmd_t *atcmds;
    uint32_t num_atcmds;
    char last_chars[ATCMD_ESCAPE_STRLEN];
} atcmd_parser_t;

void atcmd_parser_init(atcmd_parser_t *parser, const atcmd_t *atcmds, uint32_t num_atcmds);
uint8_t atcmd_detect_escape(atcmd_parser_t *parser, char c);
uint8_t atcmd_parse(atcmd_parser_t *parser, char *cmd);

#endif /* _ATCMD_H_ */

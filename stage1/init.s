.attribute arch, "rv64im"

.include "parser.h.s"

.bss

.set PARSER_ARRAY_LEN, 32
PARSER_ARRAY: .skip (2 * 8 + PARSER_ARRAY_LEN * PARSER_STATE_ELEN)

LINE_BUF: .skip 1024
.set LINE_BUF_LENGTH, 1024

.text

.global start
start:
        mv s1, ra
        la a0, INIT_MSG
        ld a1, (INIT_MSG_LENGTH)
        call put_buf
.Lstart_init_parser:
        # init the parser array
        la s2, PARSER_ARRAY
        li t0, PARSER_ARRAY_LEN
        sw t0, PARSER_STATE_LENGTH(s2)
        sw zero, PARSER_STATE_INDEX(s2)
        sd zero, PARSER_STATE_FIRST + PARSER_STATE_E_FLAG(s2)
        sd zero, PARSER_STATE_FIRST + PARSER_STATE_E_BEGIN_NODE(s2)
        sd zero, PARSER_STATE_FIRST + PARSER_STATE_E_CURRENT_NODE(s2)
.Lstart_repl:
        la a0, PROMPT
        ld a1, (PROMPT_LENGTH)
        call put_buf
        la a0, LINE_BUF
        li a1, LINE_BUF_LENGTH
        call get_line
        beqz a0, .Lstart_end
        mv a1, a0
        la a0, LINE_BUF
.Lstart_token_loop:
        # line buffer empty, end loop
        beqz a1, .Lstart_parse_done
        # loop through tokens and print them
        call get_token
        # make sure token is valid
        beqz a0, .Lstart_parse_done
        beqz a2, .Lstart_parse_done
        # preserve the output of get_token in s3-s7
        mv s3, a0
        mv s4, a1
        mv s5, a2
        mv s6, a3
        mv s7, a4
        mv a0, s5
        # print two digits token type
        li a1, 2
        call put_hex
        # print the token buffer in brackets
        li a0, '['
        call putc
        mv a0, s6
        mv a1, s7
        call put_buf
        li a0, ']'
        call putc
        li a0, '\n'
        call putc
        # parse the token and print the object if object produced
        la a0, PARSER_ARRAY
        mv a2, s5
        mv a3, s6
        mv a4, s7
        call parse_token
        bgtz a0, 1f # value produced
        beqz a0, 2f # ok but nothing produced
        # some kind of error
        li t0, PARSER_STATUS_OVERFLOW
        beq a0, t0, .Lstart_token_overflow
        la a0, ERR_MSG
        ld a1, (ERR_MSG_LENGTH)
        call put_buf
        j .Lstart_init_parser
1:
        # save a1 (object produced) into s5
        mv s5, a1
        # print PRODUCE_MSG
        la a0, PRODUCE_MSG
        ld a1, (PRODUCE_MSG_LENGTH)
        call put_buf
        # print the object
        mv a0, s5
        call print_obj
        # print newline
        li a0, '\n'
        call putc
2:
        # restore the remaining line buffer to a0-a1 and loop
        mv a0, s3
        mv a1, s4
        j .Lstart_token_loop
.Lstart_parse_done:
        la a0, OK_MSG
        ld a1, (OK_MSG_LENGTH)
        call put_buf
        j .Lstart_repl
.Lstart_token_overflow:
        la a0, OVERFLOW_MSG
        ld a1, (OVERFLOW_MSG_LENGTH)
        call put_buf
        j .Lstart_init_parser
.Lstart_end:
        mv ra, s1
        ret

.section .rodata

INIT_MSG: .ascii "\nstage1 initializing.\n"
INIT_MSG_LENGTH: .quad . - INIT_MSG

PROMPT: .ascii "> "
PROMPT_LENGTH: .quad . - PROMPT

OK_MSG: .ascii "ok\n"
OK_MSG_LENGTH: .quad . - OK_MSG

ERR_MSG: .ascii "err\n"
ERR_MSG_LENGTH: .quad . - ERR_MSG

OVERFLOW_MSG: .ascii "overflow\n"
OVERFLOW_MSG_LENGTH: .quad . - OVERFLOW_MSG

PRODUCE_MSG: .ascii "==> "
PRODUCE_MSG_LENGTH: .quad . - PRODUCE_MSG

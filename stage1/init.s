.attribute arch, "rv64im"

.include "parser.h.s"
.include "eval.h.s"

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
        # other initialization
        call symbol_init
        call words_init
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
        lw a0, PARSER_STATE_INDEX(s2)
        li a1, 2
        call put_hex
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
        # save the remaining buffer
        mv s3, a0
        mv s4, a1
        # parse the token and print the object if object produced
        la a0, PARSER_ARRAY
        call parse_token
        bgtz a0, .Lstart_eval # value produced
        beqz a0, .Lstart_token_loop_next # ok but nothing produced
        # some kind of error
        li t0, PARSER_STATUS_OVERFLOW
        beq a0, t0, .Lstart_token_overflow
        la a0, ERR_MSG
        ld a1, (ERR_MSG_LENGTH)
        call put_buf
        j .Lstart_init_parser
.Lstart_eval:
        # evaluate object produced
        mv a0, a1
        mv a1, zero # no local symbols
        call eval
        # save result to (s5, s6)
        mv s5, a0
        mv s6, a1
        # print PRODUCE_MSG
        la a0, PRODUCE_MSG
        ld a1, (PRODUCE_MSG_LENGTH)
        call put_buf
        # if a0 = err, print error
        bnez s5, .Lstart_eval_err
.Lstart_eval_ok:
        # print result of eval
        mv a0, s6
        call print_obj
        j .Lstart_eval_done
.Lstart_eval_err:
        # print the error
        la a0, ERR_MSG
        ld a1, (ERR_MSG_LENGTH)
        call put_buf
        # print nicer error messages for builtin error numbers
        li t1, EVAL_ERROR_EXCEPTION
        bne s5, t1, 1f
        la a0, EXCEPTION_MSG
        ld a1, (EXCEPTION_MSG_LENGTH)
        j .Lstart_eval_error_msg
1:
        li t1, EVAL_ERROR_UNDEFINED
        bne s5, t1, 1f
        la a0, UNDEFINED_MSG
        ld a1, (UNDEFINED_MSG_LENGTH)
        j .Lstart_eval_error_msg
1:
        li t1, EVAL_ERROR_NOT_CALLABLE
        bne s5, t1, 1f
        la a0, NOT_CALLABLE_MSG
        ld a1, (NOT_CALLABLE_MSG_LENGTH)
        j .Lstart_eval_error_msg
1:
        mv a0, s5
        li a1, 16
        call put_hex
        j .Lstart_eval_done
.Lstart_eval_error_msg:
        call put_buf
.Lstart_eval_done:
        # print two newlines
        li a0, '\n'
        call putc
        li a0, '\n'
        call putc
.Lstart_token_loop_next:
        # restore the remaining line buffer to a0-a1 and loop
        mv a0, s3
        mv a1, s4
        j .Lstart_token_loop
.Lstart_parse_done:
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

ERR_MSG: .ascii "err\n"
ERR_MSG_LENGTH: .quad . - ERR_MSG

OVERFLOW_MSG: .ascii "overflow\n"
OVERFLOW_MSG_LENGTH: .quad . - OVERFLOW_MSG

EXCEPTION_MSG: .ascii "exception"
EXCEPTION_MSG_LENGTH: .quad . - EXCEPTION_MSG

UNDEFINED_MSG: .ascii "undefined"
UNDEFINED_MSG_LENGTH: .quad . - UNDEFINED_MSG

NOT_CALLABLE_MSG: .ascii "not-callable"
NOT_CALLABLE_MSG_LENGTH: .quad . - NOT_CALLABLE_MSG

PRODUCE_MSG: .ascii "==> "
PRODUCE_MSG_LENGTH: .quad . - PRODUCE_MSG

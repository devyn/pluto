.attribute arch, "rv64im"

.include "object.h.s"

.bss

.section .rodata

# The initial words list is a packed efficient format consisting of variable-length records of:
#
# 1. first field (address or int), 8 bytes
# 2. symbol length, unsigned byte (load with `lbu`)
# 3. type, unsigned byte
# 3. symbol text, variable length
#
# the beginning of each should be aligned to 8 bytes
.align 3
.global INITIAL_WORDS
INITIAL_WORDS:
        .quad proc_hello
        .byte 5
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "hello"
        .balign 8

        .quad proc_quote
        .byte 5
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "quote"
        .balign 8

        .quad proc_ref
        .byte 3
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "ref"
        .balign 8

        .quad proc_deref
        .byte 5
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "deref"
        .balign 8

        .quad proc_call_native
        .byte 11
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "call-native"
        .balign 8

        .quad proc_peek_b
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.b"
        .balign 8

        .quad proc_peek_h
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.h"
        .balign 8

        .quad proc_peek_w
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.w"
        .balign 8

        .quad proc_peek_d
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.d"
        .balign 8

        .quad proc_poke_b
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.b"
        .balign 8

        .quad proc_poke_h
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.h"
        .balign 8

        .quad proc_poke_w
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.w"
        .balign 8

        .quad proc_poke_d
        .byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.d"
        .balign 8

        .quad proc_car
        .byte 3
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "car"
        .balign 8

        .quad car
        .byte 4
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "car$"
        .balign 8

        .quad proc_cdr
        .byte 3
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "cdr"
        .balign 8

        .quad cdr
        .byte 4
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "cdr$"
        .balign 8

        .quad proc_cons
        .byte 4
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "cons"
        .balign 8

        .quad cons
        .byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "cons$"
        .balign 8

        .quad uncons
        .byte 7
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "uncons$"
        .balign 8

        .quad proc_proc
        .byte 4
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "proc"
        .balign 8

        .quad proc_eval
        .byte 4
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "eval"
        .balign 8

        .quad eval
        .byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "eval$"
        .balign 8

        .quad eval_head
        .byte 10
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "eval-head$"
        .balign 8

        .quad allocate
        .byte 9
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "allocate$"
        .balign 8

        .quad deallocate
        .byte 11
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "deallocate$"
        .balign 8

        .quad acquire_object
        .byte 15
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "acquire-object$"
        .balign 8

        .quad release_object
        .byte 15
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "release-object$"
        .balign 8

        .quad define
        .byte 7
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "define$"
        .balign 8

        .quad symbol_intern
        .byte 14
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "symbol-intern$"
        .balign 8

        .quad eval
        .byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "eval$"
        .balign 8

        .quad lookup
        .byte 7
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "lookup$"
        .balign 8

        .quad putc
        .byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "putc$"
        .balign 8

        .quad put_buf
        .byte 8
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "put-buf$"
        .balign 8

        .quad put_hex
        .byte 8
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "put-hex$"
        .balign 8

        .quad put_dec
        .byte 8
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "put-dec$"
        .balign 8

        .quad getc
        .byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "getc$"
        .balign 8

        .quad get_line
        .byte 9
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "get-line$"
        .balign 8

        .quad print_obj
        .byte 10
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "print-obj$"
        .balign 8

        .quad box_integer
        .byte 12
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "box-integer$"
        .balign 8

        .quad unbox_integer
        .byte 14
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "unbox-integer$"
        .balign 8

        .quad shutdown
        .byte 9
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "shutdown$"
        .balign 8

        # end
        .quad 0
        .quad 0

.text

# set up the initial words
.global words_init
words_init:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        sd s2, 0x10(sp)
        # unpack the initial words table
        la s1, INITIAL_WORDS
1:
        # load the symbol into (a0, a1) and intern
        # a zero length symbol ends the initial words list
        lbu a1, 0x08(s1) # len
        beqz a1, .Lwords_init_ret # zero-length, end
        addi a0, s1, 0x0a # buf
        call symbol_intern
        beqz a0, .Lwords_init_ret # error
        mv s2, a0 # save the symbol
        # create the object
        lbu a0, 0x09(s1) # type from INITIAL_WORDS
        ld a1, 0x00(s1) # field0 from INITIAL_WORDS
        mv a2, zero
        mv a3, zero
        call make_obj
        beqz a0, .Lwords_init_ret # error
        # call define with (symbol, object)
        mv a1, a0
        mv a0, s2
        call define
        bnez a0, .Lwords_init_ret # error
        # increment pointer to INITIAL_WORDS entry
        lbu t1, 0x08(s1) # get length of string into t1
        addi s1, s1, 10 # length of (object, len, type) = 10 bytes
        add s1, s1, t1 # add length of string
        # align pointer to 8 bytes
        andi t1, s1, (1 << 3) - 1 # mask remainder
        andi s1, s1, -1 << 3 # mask address
        snez t1, t1 # if remainder not zero, set to 1
        slli t1, t1, 3 # set to 8 if set
        add s1, s1, t1 # add extra 8 bytes if remainder was > 0
        j 1b
.Lwords_init_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        addi sp, sp, 0x18
        ret


# Find the associated value of a symbol key
#
# Follows refcount rules (args released, return value owned)
#
# arguments:
# a0 = list ptr
# a1 = symbol address
#
# return:
# a0 = 1 if found
# a1 = found value
.global lookup
lookup:
        addi sp, sp, -0x20
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # list ptr
        sd s2, 0x10(sp) # symbol address
        sd s3, 0x18(sp) # scratch
        mv s1, a0
        mv s2, a1
.Llookup_loop:
        # destructure the list to (a1 . a2), a1 = pair, a2 = rest of list
        mv a0, s1
        call uncons
        beqz a0, .Llookup_not_found # nil or not a list
        mv s1, a2 # list = list->tail
        # destructure the pair in a1
        mv a0, a1
        call uncons
        beqz a0, .Llookup_loop # not a pair, skip
        # check if head = symbol
        beq a1, s2, .Llookup_found
        # else, release a1 and a2 and go to next
        mv s3, a2
        mv a0, a1
        call release_object
        mv a0, s3
        call release_object
        j .Llookup_loop
.Llookup_found:
        # head (a1) = symbol (s2), return a2
        mv s3, a2
        # release head
        mv a0, a1
        call release_object
        # return tail (assoc value)
        li a0, 1
        mv a1, s3
        j .Llookup_ret
.Llookup_not_found:
        mv a0, zero
        mv a1, zero
.Llookup_ret:
        # preserve return value while we clean up
        addi sp, sp, -0x10
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        # release s1 (remainder of list) and s2 (symbol)
        mv a0, s1
        call release_object
        mv a0, s2
        call release_object
        # restore saved values and return
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        ld s1, 0x18(sp)
        ld s2, 0x20(sp)
        addi sp, sp, 0x30
        ret

# Find the associated value of a symbol key in either the local words list, or global value
#
# arguments:
# a0 = symbol address
# a1 = local words list
#
# return:
# a0 = 1 if found
# a1 = found value
.global lookup_var
lookup_var:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        mv s1, a0
        # first check local words list
        call acquire_object # get another reference to the symbol
        mv a0, a1
        mv a1, s1
        call lookup
        bnez a0, .Llookup_var_end
        # if not found, return global value of the symbol
        ld a0, LISP_SYMBOL_GLOBAL_VALUE(s1)
        li t0, -1
        beq a0, t0, .Llookup_var_undef # undefined
        call acquire_object
        mv a1, a0
.Llookup_var_end:
        # clean up the extra symbol ref
        mv t0, a1
        mv a0, s1 # symbol
        mv s1, t0 # s1 now = found return a1
        call release_object
        li a0, 1
        mv a1, s1
.Llookup_var_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        addi sp, sp, 0x10
        ret
.Llookup_var_undef:
        mv a0, s1
        call release_object
        li a0, 0
        j .Llookup_var_ret

# Define a new word
#
# a0 = symbol address
# a1 = value address
#
# return:
#
# a0 = 0 (ok), -1 (error)
.global define
define:
        # check early for unacceptable arguments
        beqz a0, .Ldefine_err # can't define nil
        lwu t0, LISP_OBJECT_TYPE(a0)
        li t1, LISP_OBJECT_TYPE_SYMBOL
        bne t0, t1, .Ldefine_err # can't define other than a symbol as key
        # setup stack so we can call stuff
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a0, 0x08(sp) # symbol
        # swap the current global value of the symbol
        ld t0, LISP_SYMBOL_GLOBAL_VALUE(a0)
        sd a1, LISP_SYMBOL_GLOBAL_VALUE(a0)
        # release the old value unless it was undefined
        li t1, -1
        beq t0, t1, 1f
        mv a0, t0
        call release_object
1:
        # release the symbol
        ld a0, 0x08(sp)
        call release_object
        # return
        li a0, 0
        ld ra, 0x00(sp)
        addi sp, sp, 0x10
        ret
.Ldefine_err:
        li a0, -1
        ret

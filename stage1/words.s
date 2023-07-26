.attribute arch, "rv64im"

.include "object.h.s"

.bss

.set WORDS_HASH_BITS, 6
.set WORDS_LEN, (1 << WORDS_HASH_BITS)

# global definitions hashtable
#
# see symbol.s, this table is organized in the same way, but the list entries are different
#
# each list is a list of associated pairs to their values
#
# for example:
#
# ((add . <0x10000>) (sub . <0x10100>))
.global WORDS
WORDS: .skip WORDS_LEN * 8

.section .rodata

# The initial words list is a packed efficient format consisting of variable-length records of:
#
# 1. first field (address or int), 8 bytes
# 2. symbol length, 2 bytes unsigned (load with `lhu`)
# 3. type, byte
# 3. symbol text, variable length
#
# the beginning of each should be aligned to 8 bytes
.align 8
.global INITIAL_WORDS
INITIAL_WORDS:
        .quad proc_hello
        .2byte 5
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "hello"
        .balign 8

        .quad proc_quote
        .2byte 5
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "quote"
        .balign 8

        .quad proc_ref
        .2byte 3
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "ref"
        .balign 8

        .quad proc_deref
        .2byte 5
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "deref"
        .balign 8

        .quad proc_call_native
        .2byte 11
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "call-native"
        .balign 8

        .quad proc_peek_b
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.b"
        .balign 8

        .quad proc_peek_h
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.h"
        .balign 8

        .quad proc_peek_w
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.w"
        .balign 8

        .quad proc_peek_d
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "peek.d"
        .balign 8

        .quad proc_poke_b
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.b"
        .balign 8

        .quad proc_poke_h
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.h"
        .balign 8

        .quad proc_poke_w
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.w"
        .balign 8

        .quad proc_poke_d
        .2byte 6
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "poke.d"
        .balign 8

        .quad proc_car
        .2byte 3
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "car"
        .balign 8

        .quad proc_cdr
        .2byte 3
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "cdr"
        .balign 8

        .quad proc_proc
        .2byte 4
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "proc"
        .balign 8

        .quad proc_eval
        .2byte 4
        .byte LISP_OBJECT_TYPE_PROCEDURE
        .ascii "eval"
        .balign 8

        .quad ALLOCATE
        .2byte 10
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "allocate$$"
        .balign 8

        .quad DEALLOCATE
        .2byte 12
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "deallocate$$"
        .balign 8

        .quad define
        .2byte 7
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "define$"
        .balign 8

        .quad symbol_intern
        .2byte 14
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "symbol-intern$"
        .balign 8

        .quad eval
        .2byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "eval$"
        .balign 8

        .quad lookup
        .2byte 7
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "lookup$"
        .balign 8

        .quad putc
        .2byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "putc$"
        .balign 8

        .quad put_buf
        .2byte 8
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "put-buf$"
        .balign 8

        .quad put_hex
        .2byte 8
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "put-hex$"
        .balign 8

        .quad getc
        .2byte 5
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "getc$"
        .balign 8

        .quad get_line
        .2byte 9
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "get-line$"
        .balign 8

        .quad print_obj
        .2byte 10
        .byte LISP_OBJECT_TYPE_INTEGER
        .ascii "print-obj$"
        .balign 8

.set INITIAL_WORDS_LEN, 29

.text

# set up the initial words
.global words_init
words_init:
        addi sp, sp, -0x20
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        sd s2, 0x10(sp)
        sd s3, 0x18(sp)
        # zero the words table
        la a0, WORDS
        li a1, WORDS_LEN
        call mem_set_d
        # unpack the initial words table
        la s1, INITIAL_WORDS
        li s2, INITIAL_WORDS_LEN
1:
        beqz s2, .Lwords_init_ret
        # load the symbol into (a0, a1) and intern
        lhu a1, 0x08(s1) # len
        addi a0, s1, 0x0b # buf
        call symbol_intern
        beqz a0, .Lwords_init_ret # error
        mv s3, a0 # save the symbol
        # create the object
        lbu a0, 0x0a(s1) # type from INITIAL_WORDS
        ld a1, 0x00(s1) # field0 from INITIAL_WORDS
        mv a2, zero
        mv a3, zero
        call make_obj
        beqz a0, .Lwords_init_ret # error
        # call define with (symbol, object)
        mv a1, a0
        mv a0, s3
        call define
        bnez a0, .Lwords_init_ret # error
        # done: the word has been added
        addi s2, s2, -1
        # increment pointer to INITIAL_WORDS entry
        lhu t1, 0x08(s1) # get length of string into t1
        addi s1, s1, 11 # length of (object, len, type) = 11 bytes
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
        ld s3, 0x18(sp)
        addi sp, sp, 0x20


# Find the associated value of a symbol key
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
        beqz a0, .Llookup_ret # a0 = zero, return not found
        # t1 = current->head
        ld t1, LISP_CONS_HEAD(a0)
        # t2 = current->head->head
        ld t2, LISP_CONS_HEAD(t1)
        # if head = symbol, found
        beq a1, t2, .Llookup_found
        # not found, so loop again with a0 = current->tail
        ld a0, LISP_CONS_TAIL(a0)
        j lookup
.Llookup_found:
        # found, node in t1, return (1, tail)
        li a0, 1
        ld a1, LISP_CONS_TAIL(t1)
.Llookup_ret:
        ret

# Find the associated value of a symbol key in either the local words list, or global WORDS
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
        mv a0, a1
        mv a1, s1
        call lookup
        bnez a0, .Llookup_var_ret
        # if not found, check global WORDS
        mv a0, s1
        call get_words_ptr
        ld a0, (a0) # deref value of WORDS ptr to get head of list
        mv a1, s1
        call lookup
.Llookup_var_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        addi sp, sp, 0x10
        ret

# Find the pointer in the WORDS table for the given symbol address in a0
.global get_words_ptr
get_words_ptr:
        addi sp, sp, -0x08
        sd ra, 0x00(sp)
        beqz a0, .Lget_words_ptr_error # nil => error
        mv t1, a0
        lwu t2, LISP_OBJECT_TYPE(t1)
        li t3, LISP_OBJECT_TYPE_SYMBOL
        bne t2, t3, .Lget_words_ptr_error # not symbol => error
        ld a0, LISP_SYMBOL_BUF(t1)
        ld a1, LISP_SYMBOL_LEN(t1)
        call symbol_hash
        # mask the hash to number of bits
        andi a0, a0, (1 << WORDS_HASH_BITS) - 1
        # times 8 (double word)
        slli a0, a0, 3
        j .Lget_words_ptr_ret
.Lget_words_ptr_error:
        # on error just return &WORDS[0]
        mv a0, zero
.Lget_words_ptr_ret:
        # add WORDS offset
        la t1, WORDS
        add a0, a0, t1
        ld ra, 0x00(sp)
        addi sp, sp, 0x08
        ret

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
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        sd s2, 0x10(sp)
        mv s1, a0
        mv s2, a1
        # create a new pair for (symbol . value)
        call new_obj
        beqz a0, .Ldefine_error # error
        li t1, LISP_OBJECT_TYPE_CONS
        sw t1, LISP_OBJECT_TYPE(a0)
        sd s1, LISP_CONS_HEAD(a0) # head = symbol
        sd s2, LISP_CONS_TAIL(a0) # tail = value
        mv s2, a0 # save the new pair to s2
        # find the ptr into WORDS and then prepend to that list
        mv a0, s1 # the symbol
        call get_words_ptr
        mv s1, a0 # save it to s1
        # create a new cons for the prepend
        call new_obj
        li t1, LISP_OBJECT_TYPE_CONS
        sw t1, LISP_OBJECT_TYPE(a0)
        sd s2, LISP_CONS_HEAD(a0) # new.head = pair
        ld t2, (s1) # WORDS[N]
        sd t2, LISP_CONS_TAIL(a0) # new.tail = WORDS[N]
        sd a0, (s1) # WORDS[N] = new
        mv a0, zero # return ok
        j .Ldefine_ret
.Ldefine_error:
        li a0, -1
.Ldefine_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        addi sp, sp, 0x18
        ret

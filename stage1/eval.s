.attribute arch, "rv64im"

.include "object.h.s"
.include "eval.h.s"


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
# 1. procedure address, 8 bytes
# 2. symbol length, 2 bytes unsigned (load with `lhu`)
# 3. symbol text, variable length
#
# the beginning of each should be aligned to 8 bytes
.align 8
.global INITIAL_WORDS
INITIAL_WORDS:
        .quad proc_hello
        .2byte 5
        .ascii "hello\0"

        .quad proc_quote
        .2byte 5
        .ascii "quote\0"

        .quad proc_ref
        .2byte 3
        .ascii "ref\0\0\0"

        .quad proc_deref
        .2byte 5
        .ascii "deref\0"

        .quad proc_call_native
        .2byte 11
        .ascii "call-native\0\0\0"

.set INITIAL_WORDS_LEN, 5

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
        addi a0, s1, 0x0a # buf
        call symbol_intern
        beqz a0, .Lwords_init_ret # error
        mv s3, a0 # save the symbol
        # create the procedure
        ld a0, 0x00(s1) # procedure address from INITIAL_WORDS
        mv a1, zero # len=0 (unowned)
        call box_procedure
        beqz a0, .Lwords_init_ret # error
        # call define with (symbol, procedure)
        mv a1, a0
        mv a0, s3
        call define
        bnez a0, .Lwords_init_ret # error
        # done: the word has been added
        addi s2, s2, -1
        # increment pointer to INITIAL_WORDS entry
        lhu t1, 0x08(s1) # get length of string into t1
        addi s1, s1, 10 # length of (procedure, len) = 10 bytes
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

# Evaluates the given lisp object
#
# A local words list may be passed for locally defined variables.
#
# arguments:
# a0 = expression to evaluate (ptr to lisp object)
# a1 = local words list
#
# return:
# a0 = error if < 0 (EVAL_ERROR_*)
# a1 = return value
.global eval
eval:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # s1 = expression to evaluate
        sd s2, 0x10(sp) # s2 = local words list
        mv s1, a0
        mv s2, a1
        # check type of expression
        beqz s1, .Leval_literal # return literal nil
        lwu t1, LISP_OBJECT_TYPE(s1)
        li t2, LISP_OBJECT_TYPE_SYMBOL
        beq t1, t2, .Leval_symbol # eval symbol just looks it up
        li t2, LISP_OBJECT_TYPE_CONS
        bne t1, t2, .Leval_literal # anything other than a cons or sym is just returned literally
        # if it's a cons, we look up the value in head
        ld a0, LISP_CONS_HEAD(s1)
        mv a1, s2
        call lookup_var
        beqz a0, .Leval_error_undefined # matching symbol not found
        # call the (assumed) procedure with the tail of the cons as argument list
        mv a0, a1
        ld a1, LISP_CONS_TAIL(s1)
        mv a2, s2
        call call_procedure
        j .Leval_ret
.Leval_symbol:
        # if it's a symbol we just look it up
        mv a0, s1
        mv a1, s2
        call lookup_var
        beqz a0, .Leval_error_undefined
        mv a0, zero
        j .Leval_ret
.Leval_error_undefined:
        li a0, EVAL_ERROR_UNDEFINED
        j .Leval_ret
.Leval_literal:
        mv a0, zero
        mv a1, s1
.Leval_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        addi sp, sp, 0x18
        ret

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

# arguments:
#
# a0 = procedure object address (not the procedure itself)
# a1 = argument list
# a2 = local words
#
# returns same format as eval (a0 = error, a1 = result)
.global call_procedure
call_procedure:
        # check if the value is a procedure
        beqz a0, .Lcall_procedure_not_callable
        lwu t1, LISP_OBJECT_TYPE(a0)
        li t2, LISP_OBJECT_TYPE_PROCEDURE
        bne t1, t2, .Lcall_procedure_not_callable
        # shift args to a0, a1 and jump to the procedure
        ld t0, LISP_PROCEDURE_PTR(a0)
        mv a0, a1
        mv a1, a2
        jalr zero, (t0)
.Lcall_procedure_not_callable:
        li a0, EVAL_ERROR_NOT_CALLABLE
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

# just a demo
.section .rodata

HELLO_MSG: .ascii "Hello, world!\n"
HELLO_MSG_LENGTH: .quad . - HELLO_MSG

.text

.global proc_hello
proc_hello:
        addi sp, sp, -8
        sd ra, 0(sp)
        la a0, HELLO_MSG
        ld a1, (HELLO_MSG_LENGTH)
        call put_buf
        mv a0, zero
        mv a1, zero
        ld ra, 0(sp)
        addi sp, sp, 8
        ret

# Quote argument (return without evaluating)
.global proc_quote
proc_quote:
        addi sp, sp, -8
        sd ra, 0(sp)
        call car
        # a0 = first argument
        mv a1, a0
        mv a0, zero
        ld ra, 0(sp)
        addi sp, sp, 8
        ret

# Get address of argument (does not drop refcount)
.global proc_ref
proc_ref:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        call car
        # a0 = first argument
        ld a1, 0x08(sp) # local words list
        call eval
        bnez a0, .Lproc_ref_ret # on error
        mv a0, a1
        call box_integer
        beqz a0, .Lproc_ref_error
        mv a1, a0
        mv a0, zero
        j .Lproc_ref_ret
.Lproc_ref_error:
        li a0, EVAL_ERROR_EXCEPTION
.Lproc_ref_ret:
        ld ra, 0x00(sp)
        addi sp, sp, 0x10
        ret

# Read address to Lisp object and return (does not add refcount)
.global proc_deref
proc_deref:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        call car
        # a0 = first argument
        ld a1, 0x08(sp) # local words list
        call eval
        bnez a0, .Lproc_deref_ret # on error
        mv a0, a1
        beqz a0, .Lproc_deref_error # can't resolve to nil
        # check if integer
        li t1, LISP_OBJECT_TYPE_INTEGER
        lwu t2, LISP_OBJECT_TYPE(a0)
        bne t1, t2, .Lproc_deref_error
        # get value and return it as the return value ptr
        ld a1, LISP_INTEGER_VALUE(a0)
        mv a0, zero
        j .Lproc_deref_ret
.Lproc_deref_error:
        li a0, EVAL_ERROR_EXCEPTION
.Lproc_deref_ret:
        ld ra, 0(sp)
        addi sp, sp, 0x10
        ret

# Lisp procedure for calling native routines.
#
# > (call-native address a0 a1 a2 a3 a4 a5 a6 a7)
# ==> (a0 a1)
.global proc_call_native
proc_call_native:
        addi sp, sp, -0x68
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # pointer to args on stack
        sd s2, 0x10(sp) # arg list to process
        sd a1, 0x18(sp) # local words table
        mv s2, a0
        # address 0x20, a0-a7 from 0x28 .. 0x68
        addi s1, sp, 0x20
1:
        beqz s2, .Lproc_call_native_invoke # no more arguments
        # ensure arg list is cons
        lwu t1, LISP_OBJECT_TYPE(s2)
        li t2, LISP_OBJECT_TYPE_CONS
        bne t1, t2, .Lproc_call_native_error
        # get head
        ld a0, LISP_CONS_HEAD(s2)
        # evaluate expression
        ld a1, 0x18(sp)
        call eval
        bnez a0, .Lproc_call_native_ret # eval error
        # check result type integer
        beqz a1, .Lproc_call_native_error # result nil
        lwu t2, LISP_OBJECT_TYPE(a1)
        li t3, LISP_OBJECT_TYPE_INTEGER
        bne t2, t3, .Lproc_call_native_error
        # put value to s1
        ld t2, LISP_INTEGER_VALUE(a1)
        sd t2, (s1)
        # get tail
        ld s2, LISP_CONS_TAIL(s2)
        # advance
        addi s1, s1, 8
        j 1b
.Lproc_call_native_invoke:
        # load address to t0
        ld t0, 0x20(sp)
        # load arguments from stack
        ld a0, 0x28(sp)
        ld a1, 0x30(sp)
        ld a2, 0x38(sp)
        ld a3, 0x40(sp)
        ld a4, 0x48(sp)
        ld a5, 0x50(sp)
        ld a6, 0x58(sp)
        ld a7, 0x60(sp)
        # do the call
        jalr ra, (t0)
        # store a0
        sd a0, 0x28(sp)
        # make list (a0 a1)
        mv a0, a1
        call box_integer
        beqz a0, .Lproc_call_native_error
        mv a1, zero
        call cons
        beqz a0, .Lproc_call_native_error
        # ==> (a1)
        mv s1, a0
        ld a0, 0x28(sp)
        call box_integer
        beqz a0, .Lproc_call_native_error
        mv a1, s1
        call cons
        beqz a0, .Lproc_call_native_error
        # ==> (a0 . (a1))
        mv a1, a0
        mv a0, zero # ok
        j .Lproc_call_native_ret 
.Lproc_call_native_error:
        li a0, EVAL_ERROR_EXCEPTION
.Lproc_call_native_ret:
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        addi sp, sp, 0x68
        ret



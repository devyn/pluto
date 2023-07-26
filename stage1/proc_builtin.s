.attribute arch, "rv64im"

.include "object.h.s"
.include "eval.h.s"

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

# Peek

.local proc_peek_start
proc_peek_start:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        sd t0, 0x10(sp) # subvariant return address
        call car
        # a0 = first argument (address)
        ld a1, 0x08(sp) # local words list
        call eval
        bnez a0, .Lproc_peek_ret # on error
        # get value of integer
        beqz a1, .Lproc_peek_error
        li t1, LISP_OBJECT_TYPE_INTEGER
        lwu t2, LISP_OBJECT_TYPE(a1)
        bne t1, t2, .Lproc_peek_error
        ld a0, LISP_INTEGER_VALUE(a1)
        ld t0, 0x10(sp)
        jalr zero, (t0) # subvariant
.Lproc_peek_error:
        li a0, EVAL_ERROR_EXCEPTION
        j .Lproc_peek_ret

.local proc_peek_end
proc_peek_end:
        # box integer in a0 and return
        call box_integer
        beqz a0, .Lproc_peek_error
        mv a1, a0
        mv a0, zero
.Lproc_peek_ret:
        ld ra, 0x00(sp)
        addi sp, sp, 0x18
        ret

.global proc_peek_b
proc_peek_b:
        jal t0, proc_peek_start
        lb a0, (a0)
        j proc_peek_end

.global proc_peek_h
proc_peek_h:
        jal t0, proc_peek_start
        lh a0, (a0)
        j proc_peek_end

.global proc_peek_w
proc_peek_w:
        jal t0, proc_peek_start
        lw a0, (a0)
        j proc_peek_end

.global proc_peek_d
proc_peek_d:
        jal t0, proc_peek_start
        ld a0, (a0)
        j proc_peek_end

# Poke

# variant write in a3, addr s2, value s3, return to t0
.local proc_poke
proc_poke:
        addi sp, sp, -0x30
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        sd s1, 0x10(sp) # current argument list pointer
        sd s2, 0x18(sp) # address
        sd s3, 0x20(sp) # value
        sd s4, 0x28(sp) # subvariant code
        mv s1, a0
        mv s4, a3
        # Get address
        call car
        ld a1, 0x08(sp)
        call eval
        bnez a0, .Lproc_poke_end
        # Check if a1 is integer
        beqz a1, .Lproc_poke_error
        li t2, LISP_OBJECT_TYPE_INTEGER
        lwu t3, LISP_OBJECT_TYPE(a1)
        bne t2, t3, .Lproc_poke_error
        # Get integer value as s2 (address)
        ld s2, LISP_INTEGER_VALUE(a1)
1:
        # Get next argument list
        mv a0, s1
        call cdr
        mv s1, a0
        # End if list is empty
        mv a1, zero
        beqz a0, .Lproc_poke_end
        # Get next argument
        call car
        # Evaluate argument
        ld a1, 0x08(sp)
        call eval
        bnez a0, .Lproc_poke_end
        # Check if a1 is integer
        beqz a1, .Lproc_poke_error
        li t2, LISP_OBJECT_TYPE_INTEGER
        lwu t3, LISP_OBJECT_TYPE(a1)
        bne t2, t3, .Lproc_poke_error
        # Get integer value as s3 (value)
        ld s3, LISP_INTEGER_VALUE(a1)
        # Call subvariant code to store the value and increment address
        jalr t0, (s4)
        # Loop
        j 1b
.Lproc_poke_error:
        li a0, EVAL_ERROR_EXCEPTION
.Lproc_poke_end:
        ld ra, 0x00(sp)
        ld s1, 0x10(sp)
        ld s2, 0x18(sp)
        ld s3, 0x20(sp)
        ld s4, 0x28(sp)
        addi sp, sp, 0x30
        ret

.global proc_poke_b
proc_poke_b:
        la a3, 1f
        j proc_poke
1:
        sb s3, (s2)
        addi s2, s2, 1
        jalr zero, (t0)


.global proc_poke_h
proc_poke_h:
        la a3, 1f
        j proc_poke
1:
        sh s3, (s2)
        addi s2, s2, 2
        jalr zero, (t0)

.global proc_poke_w
proc_poke_w:
        la a3, 1f
        j proc_poke
1:
        sw s3, (s2)
        addi s2, s2, 4
        jalr zero, (t0)

.global proc_poke_d
proc_poke_d:
        la a3, 1f
        j proc_poke
1:
        sd s3, (s2)
        addi s2, s2, 8
        jalr zero, (t0)

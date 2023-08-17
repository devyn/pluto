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
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        # release args and locals
        call release_object
        ld a0, 0x08(sp)
        call release_object
        # write msg
        la a0, HELLO_MSG
        ld a1, (HELLO_MSG_LENGTH)
        call put_buf
        mv a0, zero
        mv a1, zero
        ld ra, 0(sp)
        addi sp, sp, 0x10
        ret

# Quote argument (return without evaluating)
.global proc_quote
proc_quote:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a0, 0x08(sp)
        # release locals (unused)
        mv a0, a1
        call release_object
        ld a0, 0x08(sp)
        call car
        # a0 = first argument
        mv a1, a0
        mv a0, zero
        ld ra, 0(sp)
        addi sp, sp, 0x10
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
        li a0, EVAL_ERROR_NO_FREE_MEM
        mv a1, zero
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
        # get value
        call unbox_integer
        beqz a0, .Lproc_deref_error
        # return value int in a1, treat as address to obj, set a0 = zero (no error)
        mv a0, zero
        j .Lproc_deref_ret
.Lproc_deref_error:
        li a0, EVAL_ERROR_EXCEPTION
        mv a1, zero
.Lproc_deref_ret:
        ld ra, 0x00(sp)
        addi sp, sp, 0x10
        ret

# Lisp procedure for calling native routines.
#
# > (call-native address return-n a0 a1 a2 a3 a4 a5 a6 a7)
# ==> (a0 a1 .. a<return-n>)
.global proc_call_native
proc_call_native:
        addi sp, sp, -0x70
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # pointer to args on stack
        sd s2, 0x10(sp) # arg list to process
        sd a1, 0x18(sp) # local words table
        mv s2, a0
        # address 0x20, return-n 0x28, a0-a7 from 0x30 .. 0x70
        addi s1, sp, 0x20
        # just in case, zero that memory to avoid unwanted side effects
        mv t1, s1
        addi t2, sp, 0x70
2:
        sd zero, (t1)
        addi t1, t1, 8
        bltu t1, t2, 2b
1:
        beqz s2, .Lproc_call_native_invoke # no more arguments
        # destructure (a1 . a2)
        mv a0, s2
        mv s2, zero
        call uncons
        beqz a0, .Lproc_call_native_exc # not cons
        mv s2, a2 # put tail as next arg list
        # eval head
        mv a0, a1
        ld a1, 0x18(sp)
        call acquire_locals
        call eval
        bnez a0, .Lproc_call_native_ret # eval error
        # unbox the integer value
        mv a0, a1
        call unbox_integer
        beqz a0, .Lproc_call_native_exc # not an integer
        # store integer on stack
        sd a1, (s1)
        # advance
        addi s1, s1, 8
        j 1b
.Lproc_call_native_invoke:
        # load address to t0
        ld t0, 0x20(sp)
        beqz t0, .Lproc_call_native_exc # assert address != 0
        # check that return-n is not > 8
        ld t1, 0x28(sp)
        li t2, 8
        bgtu t1, t2, .Lproc_call_native_exc
        # load arguments from stack
        ld a0, 0x30(sp)
        ld a1, 0x38(sp)
        ld a2, 0x40(sp)
        ld a3, 0x48(sp)
        ld a4, 0x50(sp)
        ld a5, 0x58(sp)
        ld a6, 0x60(sp)
        ld a7, 0x68(sp)
        # do the call
        jalr ra, (t0)
        # store return args
        sd a0, 0x30(sp)
        sd a1, 0x38(sp)
        sd a2, 0x40(sp)
        sd a3, 0x48(sp)
        sd a4, 0x50(sp)
        sd a5, 0x58(sp)
        sd a6, 0x60(sp)
        sd a7, 0x68(sp)
        # make return list in s2. first free it up
        mv a0, s2
        call release_object
        mv s2, zero # nil
        # calculate end of stack for return-n
        addi s1, sp, 0x30 # beginning of args
        ld t1, 0x28(sp) # return-n
        slli t1, t1, 3 # x 8
        add s1, s1, t1 # end of args to return
.Lproc_call_native_ret_list_loop:
        # check stack limit
        addi t1, sp, 0x30
        bleu s1, t1, .Lproc_call_native_ret_list
        # decrement
        addi s1, s1, -8
        # load from stack, box
        ld a0, (s1)
        call box_integer
        beqz a0, .Lproc_call_native_nomem
        # form list
        mv a1, s2
        call cons
        beqz a0, .Lproc_call_native_nomem
        mv s2, a0
        j .Lproc_call_native_ret_list_loop
.Lproc_call_native_ret_list:
        # take a1 (return value) from s2
        mv a1, s2
        mv a0, zero # ok
        mv s2, zero # used
        j .Lproc_call_native_ret
.Lproc_call_native_exc:
        li a0, EVAL_ERROR_EXCEPTION
        mv a1, zero
        j .Lproc_call_native_ret
.Lproc_call_native_nomem:
        li a0, EVAL_ERROR_NO_FREE_MEM
        mv a1, zero
.Lproc_call_native_ret:
        # stash a0, a1 and release remaining owned data
        sd a0, 0x20(sp)
        sd a1, 0x28(sp)
        ld a0, 0x18(sp)
        call release_object # local words table
        mv a0, s2 # arg list (if remaining)
        call release_object
        # restore, clean up stack
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        ld a0, 0x20(sp)
        ld a1, 0x28(sp)
        addi sp, sp, 0x70
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
        mv a0, a1
        call unbox_integer
        beqz a0, .Lproc_peek_error
        mv a0, a1
        ld t0, 0x10(sp)
        jalr zero, (t0) # subvariant
.Lproc_peek_error:
        li a0, EVAL_ERROR_EXCEPTION
        mv a1, zero
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
        addi sp, sp, -0x40
        sd ra, 0x00(sp)
        sd a1, 0x08(sp) # locals
        sd s1, 0x10(sp) # current argument list pointer
        sd s2, 0x18(sp) # address
        sd s3, 0x20(sp) # value
        sd s4, 0x28(sp) # subvariant code
        sd zero, 0x30(sp) # return value a0
        sd zero, 0x38(sp) # return value a1
        mv s4, a3
        # Get address
        call uncons
        mv s1, a2 # save rest of list
        mv a0, a1
        ld a1, 0x08(sp)
        call acquire_locals
        call eval
        bnez a0, .Lproc_poke_eval_error
        # Get integer value as s2 (address)
        mv a0, a1
        call acquire_object
        sd a0, 0x38(sp) # save the integer obj for return later
        call unbox_integer
        beqz a0, .Lproc_poke_error
        mv s2, a1
1:
        # Get next argument list
        mv a0, s1
        call uncons
        mv s1, a2 # save rest of list
        # End if list is empty
        beqz a0, .Lproc_poke_end
        # Evaluate argument
        mv a0, a1
        ld a1, 0x08(sp)
        call acquire_locals
        call eval
        bnez a0, .Lproc_poke_eval_error
        # Get integer value as s3 (value)
        mv a0, a1
        call unbox_integer
        beqz a0, .Lproc_poke_error
        mv s3, a1
        # Call subvariant code to store the value and increment address
        jalr t0, (s4)
        # Loop
        j 1b
.Lproc_poke_eval_error:
        # Store error code into 0x30(sp) = a0
        sd a0, 0x30(sp)
        # Shuffle a1 into 0x38(sp), where we will restore a1 later
        ld t1, 0x38(sp)
        sd a1, 0x38(sp)
        # Release previous value of a1 (could be address)
        mv a0, t1
        call release_object
        j .Lproc_poke_end
.Lproc_poke_error:
        li a0, EVAL_ERROR_EXCEPTION
        sd a0, 0x30(sp) # ret a0
.Lproc_poke_end:
        # release arg list
        mv a0, s1
        call release_object
        # release locals
        ld a0, 0x08(sp)
        call release_object
        # restore saved & outputs, then return
        ld ra, 0x00(sp)
        ld s1, 0x10(sp)
        ld s2, 0x18(sp)
        ld s3, 0x20(sp)
        ld s4, 0x28(sp)
        ld a0, 0x30(sp)
        ld a1, 0x38(sp)
        addi sp, sp, 0x40
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

.global proc_car
proc_car:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        # first arg
        call car
        # evaluate
        ld a1, 0x08(sp)
        call eval
        bnez a0, .Lproc_car_ret
        # perform car
        mv a0, a1
        call car
        mv a1, a0
        mv a0, zero
.Lproc_car_ret:
        ld ra, 0x00(sp)
        addi sp, sp, 0x10
        ret

.global proc_cdr
proc_cdr:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a1, 0x08(sp)
        # first arg
        call car
        # evaluate
        ld a1, 0x08(sp)
        call eval
        bnez a0, .Lproc_car_ret
        # perform cdr
        mv a0, a1
        call cdr
        mv a1, a0
        mv a0, zero
        j .Lproc_car_ret

.global proc_cons
proc_cons:
        # reserve stack, preserve return addr
        addi sp, sp, -0x20
        sd ra, 0x00(sp)
        sd a1, 0x08(sp) # locals
        sd zero, 0x10(sp) # cons head
        sd a0, 0x18(sp) # remaining args
        # evaluate first two args
        # arg 0 (head)
        addi a0, sp, 0x18
        call acquire_locals
        call eval_head
        bnez a0, .Lproc_cons_ret
        sd a1, 0x10(sp)
        # arg 1 (tail)
        addi a0, sp, 0x18
        ld a1, 0x08(sp) # locals
        sd zero, 0x08(sp) # used
        call eval_head
        bnez a0, .Lproc_cons_ret
        # cons head, tail
        ld a0, 0x10(sp)
        # a1 = tail, from eval
        sd zero, 0x10(sp) # used
        call cons
        beqz a0, .Lproc_cons_no_mem
        mv a1, a0 # result
        mv a0, zero # ok
.Lproc_cons_ret:
        # stash return value
        addi sp, sp, -0x10
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        # release from 0x18 .. 0x30 (sp)
        ld a0, 0x18(sp)
        call release_object
        ld a0, 0x20(sp)
        call release_object
        ld a0, 0x28(sp)
        call release_object
        # load stashed data and return
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        addi sp, sp, 0x30
        ret
.Lproc_cons_no_mem:
        li a0, EVAL_ERROR_NO_FREE_MEM
        li a1, 0
        j .Lproc_cons_ret
.Lproc_cons_exc:
        li a0, EVAL_ERROR_EXCEPTION
        li a1, 0
        j .Lproc_cons_ret

# Create procedure
# e.g. (proc args locals (car args)) ; equivalent to quote

# Proc data structure
.set PROC_DATA_TYPE,       -2
.set PROC_DATA_SIZE,       0x20 # same as object so we can be nice to the allocator
.set PROC_DATA_ALIGN,      8
.set PROC_DATA_LOCALS,     0x00
.set PROC_DATA_ARGS_SYM,   0x08
.set PROC_DATA_LOCALS_SYM, 0x10
.set PROC_DATA_EXPRESSION, 0x18

.global proc_proc
proc_proc:
        addi sp, sp, -0x20
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        sd a0, 0x10(sp)
        sd a1, 0x18(sp)
        mv s1, zero # pointer to proc data, PROC_DATA_SIZE
        # create custom data structure, for proc_stub to read
        # use a four-dw structure
        li a0, PROC_DATA_SIZE
        li a1, PROC_DATA_ALIGN
        call allocate
        beqz a0, .Lproc_proc_nomem # alloc error
        mv s1, a0
        # store locals
        ld t0, 0x18(sp)
        sd zero, 0x18(sp) # used
        sd t0, PROC_DATA_LOCALS(s1)
        # initialize other fields just in case of error
        sd zero, PROC_DATA_ARGS_SYM(s1)
        sd zero, PROC_DATA_LOCALS_SYM(s1)
        sd zero, PROC_DATA_EXPRESSION(s1)
        # get args sym
        ld a0, 0x10(sp)
        sd zero, 0x10(sp)
        call uncons
        beqz a0, .Lproc_proc_exc # not enough args
        sd a1, PROC_DATA_ARGS_SYM(s1)
        mv a0, a2
        # get locals sym
        call uncons
        beqz a0, .Lproc_proc_exc # not enough args
        sd a1, PROC_DATA_LOCALS_SYM(s1)
        mv a0, a2
        # get expression
        call car
        sd a0, PROC_DATA_EXPRESSION(s1)
        # make custom data
        mv a3, zero
        mv a2, s1
        la a1, proc_proc_data_destroy
        li a0, PROC_DATA_TYPE
        call make_obj
        beqz a0, .Lproc_proc_nomem # alloc error
        mv s1, zero # used
        sd a0, 0x10(sp) # in case there's an error so it gets freed
        # make procedure
        mv a3, zero
        mv a2, a0
        la a1, proc_stub
        li a0, LISP_OBJECT_TYPE_PROCEDURE
        call make_obj
        beqz a0, .Lproc_proc_nomem # alloc error
        # return
        mv a1, a0
        mv a0, zero # ok
        # restore and return
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        addi sp, sp, 0x20
        ret
.Lproc_proc_nomem:
        li a0, EVAL_ERROR_NO_FREE_MEM
        mv a1, zero
        j .Lproc_proc_err_ret
.Lproc_proc_exc:
        li a0, EVAL_ERROR_EXCEPTION
        mv a1, zero
.Lproc_proc_err_ret:
        # cleanup is required
        # stash a0, a1
        addi sp, sp, 0x10
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        # release anything unused
        beqz s1, 1f
        mv a0, s1
        call proc_proc_data_drop
1:
        ld a0, 0x20(sp)
        call release_object
        ld a0, 0x28(sp)
        call release_object
        # unstash
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        ld s1, 0x18(sp)
        addi sp, sp, 0x30
        ret

# Destructor for custom proc data object
.global proc_proc_data_destroy
proc_proc_data_destroy:
        beqz a0, 1f
        lw t0, (a0)
        li t1, PROC_DATA_TYPE
        bne t0, t1, 1f
        # get pointer to the actual custom data
        ld a0, LISP_USER_OBJ_DATA1(a0)
        j proc_proc_data_drop
1:
        ret

# Destructor for custom proc data
.global proc_proc_data_drop
proc_proc_data_drop:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        mv s1, a0
        # release each field
        ld a0, PROC_DATA_LOCALS(s1)
        call release_object
        ld a0, PROC_DATA_ARGS_SYM(s1)
        call release_object
        ld a0, PROC_DATA_LOCALS_SYM(s1)
        call release_object
        ld a0, PROC_DATA_EXPRESSION(s1)
        call release_object
        # deallocate data itself
        mv a0, s1
        li a1, PROC_DATA_SIZE
        call deallocate
        # return
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        addi sp, sp, 0x10
        ret

# Evaluates data from procedure created by proc_proc
.global proc_stub
proc_stub:
        addi sp, sp, -0x30
        sd ra, 0x00(sp)
        sd s1, 0x08(sp)
        sd a0, 0x10(sp) # args
        sd a1, 0x18(sp) # locals
        sd a2, 0x20(sp) # data
        sd s2, 0x28(sp)
        # goal: set up eval call a0/a1 then jump
        # first goal: create ((locals . <a1>) (args . <a0>) . <data.locals>)
        ld s2, LISP_USER_OBJ_DATA1(a2)
        ld a0, PROC_DATA_LOCALS(s2)
        call acquire_object
        mv s1, a0
        # Get args symbol
        ld a0, PROC_DATA_ARGS_SYM(s2)
        beqz a0, 1f # skip if nil
        call acquire_object
        ld a1, 0x10(sp)
        sd zero, 0x10(sp) # used
        call cons
        beqz a0, .Lproc_stub_error
        # a0 = args pair, cons with s1
        mv a1, s1
        mv s1, zero
        call cons
        beqz a0, .Lproc_stub_error
        mv s1, a0
1:
        # Get locals symbol
        ld a0, PROC_DATA_LOCALS_SYM(s2)
        beqz a0, 1f # skip if nil
        call acquire_object
        ld a1, 0x18(sp)
        sd zero, 0x18(sp) # used
        call cons
        beqz a0, .Lproc_stub_error
        # a0 = locals pair, cons with s1
        mv a1, s1
        mv s1, zero
        call cons
        beqz a0, .Lproc_stub_error
        mv s1, a0
1:
        # Swap expression for data on stack
        ld a0, PROC_DATA_EXPRESSION(s2)
        call acquire_object
        ld t0, 0x20(sp)
        sd a0, 0x20(sp)
        # Release data
        mv a0, t0
        call release_object
        # Release args/locals remaining if not used
        ld a0, 0x10(sp)
        call release_object
        ld a0, 0x18(sp)
        call release_object
        # Set up eval expression x locals
        ld a0, 0x20(sp)
        mv a1, s1
        # Restore then tail-call eval
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x28(sp)
        addi sp, sp, 0x30
        j eval
.Lproc_stub_error:
        # release args/locals/data
        ld a0, 0x10(sp)
        call release_object
        ld a0, 0x18(sp)
        call release_object
        ld a0, 0x20(sp)
        call release_object
        mv a0, s1
        call release_object
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x28(sp)
        addi sp, sp, 0x30
        li a0, EVAL_ERROR_NO_FREE_MEM
        mv a1, zero
        ret

# (eval <locals> <expression>)
.global proc_eval
proc_eval:
        addi sp, sp, -0x28
        sd ra, 0x00(sp)
        sd a1, 0x08(sp) # locals (in)
        sd zero, 0x10(sp) # arg 0 = provided locals
        sd zero, 0x18(sp) # arg 1 = expression
        sd a0, 0x20(sp) # remaining args
        # arg 0
        addi a0, sp, 0x20
        call acquire_locals
        call eval_head
        bnez a0, .Lproc_eval_error
        sd a1, 0x10(sp)
        # arg 1
        addi a0, sp, 0x20
        ld a1, 0x08(sp) # locals
        sd zero, 0x08(sp) # used
        call eval_head
        bnez a0, .Lproc_eval_error
        sd a1, 0x18(sp)
        # release rest of args
        ld a0, 0x20(sp)
        call release_object
        # tail-call eval (args are actually in reverse of what they are for eval)
        ld ra, 0x00(sp)
        ld a1, 0x10(sp)
        ld a0, 0x18(sp)
        addi sp, sp, 0x28
        j eval
.Lproc_eval_error:
        # on error, release everything remaining in the stack
        # stash a0, a1 first
        addi sp, sp, -0x10
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        # release 0x18 .. 0x38 (sp)
        ld a0, 0x18(sp)
        call release_object
        ld a0, 0x20(sp)
        call release_object
        ld a0, 0x28(sp)
        call release_object
        ld a0, 0x30(sp)
        call release_object
        # restore and return
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        addi sp, sp, 0x38
        ret

.attribute arch, "rv64im"

.include "object.h.s"
.include "eval.h.s"

.text

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
# a1 = return value / error details object
.global eval
eval:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd a0, 0x08(sp) # a0 = expression to evaluate
        sd a1, 0x10(sp) # a1 = local words list
        # check type of expression
        beqz a0, .Leval_literal # return literal nil
        lwu t1, LISP_OBJECT_TYPE(a0)
        li t2, LISP_OBJECT_TYPE_SYMBOL
        beq t1, t2, .Leval_symbol # eval symbol just looks it up
        li t2, LISP_OBJECT_TYPE_CONS
        bne t1, t2, .Leval_literal # anything other than a cons or sym is just returned literally
        # evaluate the head from the cons, it should be a procedure
        addi a0, sp, 0x08
        call acquire_locals
        call eval_head
        bnez a0, .Leval_ret # error
        # call the (assumed) procedure with the tail of the cons as argument list
        mv a0, a1
        ld a1, 0x08(sp) # args
        ld a2, 0x10(sp) # locals
        # restore stack and tail call
        ld ra, 0x00(sp)
        addi sp, sp, 0x18
        j call_procedure
.Leval_symbol:
        call acquire_object # keep symbol, in case error
        # look the symbol up in locals
        ld a1, 0x10(sp)
        sd zero, 0x10(sp) # used
        call lookup_var
        beqz a0, .Leval_error_undefined
        # return
        li a0, 0 # success
        # a1 = found value
.Leval_ret:
        # release the two values on the stack if they're still set,
        # since they aren't part of the return value
        addi sp, sp, -0x10
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        ld a0, 0x18(sp)
        call release_object
        ld a0, 0x20(sp)
        call release_object
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        addi sp, sp, 0x28
        ret
.Leval_error_undefined:
        li a0, EVAL_ERROR_UNDEFINED
        ld a1, 0x08(sp) # saved symbol as error details
        sd zero, 0x08(sp) # used
        j .Leval_ret
.Leval_literal:
        # do quick return, just release locals
        ld a0, 0x10(sp)
        call release_object
        ld ra, 0x00(sp)
        mv a0, zero # ok
        ld a1, 0x08(sp)
        addi sp, sp, 0x18
        ret

# Call before eval to increment refcount on locals (a1)
# Preserves a0, a1 (eval args)
.global acquire_locals
acquire_locals:
        addi sp, sp, -0x10
        sd ra, 0x00(sp)
        sd a0, 0x08(sp)
        mv a0, a1
        call acquire_object
        mv a1, a0
        ld ra, 0x00(sp)
        ld a0, 0x08(sp)
        addi sp, sp, 0x10
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
        # add ref to data and release procedure object
        addi sp, sp, -0x30
        ld t0, LISP_PROCEDURE_PTR(a0)
        ld t1, LISP_PROCEDURE_DATA(a0)
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        sd a2, 0x10(sp)
        sd t0, 0x18(sp)
        sd t1, 0x20(sp)
        sd ra, 0x28(sp)
        mv a0, t1
        call acquire_object
        ld a0, 0x00(sp)
        call release_object
        # load args and jump to the procedure
        ld t0, 0x18(sp) # procedure addr
        ld a0, 0x08(sp) # args
        ld a1, 0x10(sp) # local words
        ld a2, 0x20(sp) # data
        ld ra, 0x28(sp) # return addr
        addi sp, sp, 0x30
        jalr zero, (t0)
.Lcall_procedure_not_callable:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd a0, 0x08(sp)
        sd a2, 0x10(sp)
        # release arguments
        mv a0, a1
        call release_object
        ld a0, 0x10(sp)
        call release_object
        # clean up stack and return error
        ld ra, 0x00(sp)
        ld a1, 0x08(sp)
        li a0, EVAL_ERROR_NOT_CALLABLE
        addi sp, sp, 0x18
        ret

# Takes the first element of a list and evaluates it
#
# a0 = pointer to pointer to tail - will be overwritten with next tail
# a1 = local words
#
# Return:
#
# a0 = eval error
# a1 = evaluated head or eval error
#
# On error, nil will be written to the tail pointer and the remainder will be released.
.global eval_head
eval_head:
        addi sp, sp, -0x18
        sd ra, 0x00(sp)
        sd a0, 0x08(sp) # pointer to pointer to tail
        sd a1, 0x10(sp) # locals
        # uncons the list
        ld t0, (a0)
        sd zero, (a0) # taken
        mv a0, t0
        call uncons
        beqz a0, .Leval_head_exc # not a cons
        # store the tail
        ld t0, 0x08(sp)
        sd a2, (t0)
        # eval head x locals
        mv a0, a1
        ld a1, 0x10(sp)
        sd zero, 0x10(sp) # used
        call eval
.Leval_head_ret:
        addi sp, sp, -0x10
        # store result
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        # release locals if not used
        ld a0, 0x20(sp)
        call release_object
        # release tail if error
        ld t0, 0x00(sp)
        beqz t0, 1f
        ld a0, 0x18(sp)
        ld a0, (a0)
        call release_object
        ld a0, 0x18(sp)
        sd zero, (a0)
1:
        # restore and return
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        addi sp, sp, 0x28
        ret
.Leval_head_exc:
        # set exception
        li a0, EVAL_ERROR_EXCEPTION
        mv a1, zero
        j .Leval_head_ret

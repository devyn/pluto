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
        addi sp, sp, -0x20
        sd ra, 0x00(sp)
        sd s1, 0x08(sp) # s1 = expression to evaluate
        sd s2, 0x10(sp) # s2 = local words list
        sd s3, 0x18(sp) # cons tail (procedure arglist)
        mv s1, a0
        mv s2, a1
        # check type of expression
        beqz s1, .Leval_literal # return literal nil
        lwu t1, LISP_OBJECT_TYPE(s1)
        li t2, LISP_OBJECT_TYPE_SYMBOL
        beq t1, t2, .Leval_symbol # eval symbol just looks it up
        li t2, LISP_OBJECT_TYPE_CONS
        bne t1, t2, .Leval_literal # anything other than a cons or sym is just returned literally
        # destructure the cons to (s1 . s3)
        call uncons
        mv s1, a1
        mv s3, a2
        # if it's a cons, we evaluate head first, it should be a procedure
        mv a0, s1
        mv a1, s2
        call acquire_locals
        call eval
        mv s1, zero # used the head, so set to nil
        bnez a0, .Leval_ret # error
        # call the (assumed) procedure with the tail of the cons as argument list
        mv a0, a1
        mv a1, s3
        mv a2, s2
        # tail call: call_procedure
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        ld s3, 0x18(sp)
        addi sp, sp, 0x20
        j call_procedure
.Leval_symbol:
        # if it's a symbol we just look it up
        mv a0, s1
        call acquire_object # keep symbol, in case error
        mv a1, s2
        call lookup_var
        mv s2, zero # used
        beqz a0, .Leval_error_undefined
        # release the symbol
        mv s2, a1 # save found value
        mv a0, s1
        call release_object
        mv a0, zero # success
        mv a1, s2   # found value
        mv s1, zero # used
        mv s2, zero # used
        j .Leval_ret
.Leval_error_undefined:
        li a0, EVAL_ERROR_UNDEFINED
        mv a1, s1 # saved symbol as error details
        mv s1, zero # used
        j .Leval_ret
.Leval_literal:
        mv a0, zero
        mv a1, s1
        mv s1, zero # used
.Leval_ret:
        # release s1 and s2 if they're still set, since they aren't part of the return value
        addi sp, sp, -0x10
        sd a0, 0x00(sp)
        sd a1, 0x08(sp)
        mv a0, s1
        call release_object
        mv a1, s2
        call release_object
        ld a0, 0x00(sp)
        ld a1, 0x08(sp)
        ld ra, 0x10(sp)
        ld s1, 0x18(sp)
        ld s2, 0x20(sp)
        ld s3, 0x28(sp)
        addi sp, sp, 0x30
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
        sd a1, 0x08(sp)
        sd a2, 0x10(sp)
        # release arguments
        call release_object
        ld a0, 0x08(sp)
        call release_object
        ld a0, 0x10(sp)
        call release_object
        # clean up stack and return error
        ld ra, 0x00(sp)
        addi sp, sp, 0x18
        li a0, EVAL_ERROR_NOT_CALLABLE
        mv a1, zero
        ret

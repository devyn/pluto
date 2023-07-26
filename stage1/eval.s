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
        # if it's a cons, we evaluate head first, it should be a procedure
        ld a0, LISP_CONS_HEAD(s1)
        mv a1, s2
        call eval
        bnez a0, .Leval_ret # error
        # call the (assumed) procedure with the tail of the cons as argument list
        mv a0, a1
        ld a1, LISP_CONS_TAIL(s1)
        mv a2, s2
        # tail call: call_procedure
        ld ra, 0x00(sp)
        ld s1, 0x08(sp)
        ld s2, 0x10(sp)
        addi sp, sp, 0x18
        j call_procedure
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
        # shift args to a0-a2 and jump to the procedure
        ld t0, LISP_PROCEDURE_PTR(a0)
        ld t1, LISP_PROCEDURE_DATA(a0)
        mv a0, a1 # args
        mv a1, a2 # local words
        mv a2, t1 # data
        jalr zero, (t0)
.Lcall_procedure_not_callable:
        li a0, EVAL_ERROR_NOT_CALLABLE
        ret

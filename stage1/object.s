.attribute arch, "rv64im"

.include "object.h.s"

# Lisp object in a0. Returns value of head in a0. Returns nil if not cons
.global car
car:
        jal t0, check_cons
        ld a0, LISP_CONS_HEAD(a0)
        ret

# Lisp object in a0. Returns value of tail in a0. Returns nil if not cons
.global cdr
cdr:
        jal t0, check_cons
        ld a0, LISP_CONS_TAIL(a0)
        ret

# microprocedure, uses t0 return address, modifies t1, t2
.local check_cons
check_cons:
        li t1, LISP_OBJECT_TYPE_CONS
        lw t2, LISP_OBJECT_TYPE(a0)
        bne t1, t2, return_nil
        jalr zero, 0(t0)

.local return_nil
return_nil:
        mv a0, zero
        ret

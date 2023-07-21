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
        jalr zero, (t0)

.local return_nil
return_nil:
        mv a0, zero
        ret

# sets up a new object and initializes refcount ONLY.
# returns a0=zero on allocation error, otherwise a0=object.
.global new_obj
new_obj:
        li a0, LISP_OBJECT_SIZE
        li a1, LISP_OBJECT_ALIGN
        call allocate
        bnez a0, 1f
        ret # allocation error
1:
        # initialize to all zero
        sd zero, 0x00(a0)
        sd zero, 0x08(a0)
        sd zero, 0x10(a0)
        sd zero, 0x18(a0)
        # set refcount = 1
        li t1, 1
        sw t1, LISP_OBJECT_REFCOUNT(a0)
        jalr zero, (t0)

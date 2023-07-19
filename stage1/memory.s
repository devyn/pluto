.attribute arch, "rv64im"

.include "object.h.s"

# The stage1 memory management is very basic and just dedicates some space for heap with no way to
# deallocate. It does provide a way to swap out these functions though, by jumping indirectly
# through ALLOCATE and DEALLOCATE.

.data

.global ALLOCATE
ALLOCATE: .quad builtin_allocate

.global DEALLOCATE
DEALLOCATE: .quad builtin_deallocate

.global BUILTIN_HEAP_PTR
BUILTIN_HEAP_PTR: .quad _heap_start

.section .bss

.align 8
.global _heap_start
_heap_start: .skip 0x20000
.equ _heap_end, .

.text

# args: a0 = bytes to allocate, a1 = alignment
# ret: a0 = pointer on success, zero on failure
.global allocate
allocate:
        ld t0, (ALLOCATE)
        jalr zero, (t0)

# args: a0 = pointer, a1 = number of bytes
# ret: a0 = 0
.global deallocate
deallocate:
        ld t0, (DEALLOCATE)
        jalr zero, (t0)

.global builtin_allocate
builtin_allocate:
        ld t0, (BUILTIN_HEAP_PTR)
        # align the pointer
        remu t1, t0, a1 # t1 = pointer % alignment
        beqz t1, .Lbuiltin_allocate_aligned # remainder zero, aligned already
        sub t1, a1, t0 # t1 = alignment - (pointer % alignment)
        add t0, t0, t1 # t0 = pointer + alignment - (pointer % alignment)
.Lbuiltin_allocate_aligned:
        # calculate the new value of BUILTIN_HEAP_PTR after allocation
        add t1, t0, a0
        # make sure that it won't be beyond the end of the heap
        la t2, _heap_end
        bgt t1, t2, .Lbuiltin_allocate_error
        # store the new BUILTIN_HEAP_PTR
        la t2, BUILTIN_HEAP_PTR
        sd t1, (t2)
        # return the allocated, aligned pointer
        mv a0, t0
        ret
.Lbuiltin_allocate_error:
        mv a0, zero
        ret

.global builtin_deallocate
builtin_deallocate:
        # do nothing
        mv a0, zero
        ret

# increment refcount
.global acquire_object
acquire_object:
        lw t0, LISP_OBJECT_REFCOUNT(a0)
        addi t0, t0, 1
        sw t0, LISP_OBJECT_REFCOUNT(a0)
        ret

# decrement refcount and deallocate if <= 0
.global release_object
release_object:
        lw t0, LISP_OBJECT_REFCOUNT(a0)
        addi t0, t0, -1
        sw t0, LISP_OBJECT_REFCOUNT(a0)
        bgtz t0, 1f
        call deallocate_object
        1:
        ret

# calls deallocate for an object as well as any of the memory it owns
.global deallocate_object
deallocate_object:
        addi sp, sp, -24
        sd ra, 0(sp)
        sd s1, 8(sp) # s1 = saved object address
        sd s2, 16(sp) # s2 = object type
        mv s1, a0
        lw s2, LISP_OBJECT_TYPE(sp)
.Ldeallocate_object_cons:
        # check for CONS
        li t0, LISP_OBJECT_TYPE_CONS
        beq s2, t0, .Ldeallocate_object_string
        # release head if not nil
        ld a0, LISP_CONS_HEAD(s1)
        beqz a0, 1f
        call release_object
        1:
        # release tail if not nil
        ld a0, LISP_CONS_TAIL(s1)
        beqz a0, 1f
        call release_object
        1:
        j .Ldeallocate_object_end
.Ldeallocate_object_string:
        # check for STRING
        li t0, LISP_OBJECT_TYPE_STRING
        beq s2, t0, .Ldeallocate_object_procedure
        # release the buffer x capacity
        ld a0, LISP_STRING_BUF(s1)
        ld a1, LISP_STRING_CAP(s1)
        call deallocate
        j .Ldeallocate_object_end
.Ldeallocate_object_procedure:
        # check for PROCEDURE
        li t0, LISP_OBJECT_TYPE_PROCEDURE
        beq s2, t0, .Ldeallocate_object_end
        # release the pointer x length but only if length > 0
        ld a1, LISP_PROCEDURE_LEN(s1)
        beqz a1, .Ldeallocate_object_end
        ld a0, LISP_PROCEDURE_PTR(s1)
        call deallocate
.Ldeallocate_object_end:
        mv a0, s1
        li a1, LISP_OBJECT_SIZE
        call deallocate
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        addi sp, sp, 24

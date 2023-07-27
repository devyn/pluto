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
_heap_start: .skip 0x100000
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
        sub t1, a1, t1 # t1 = alignment - (pointer % alignment)
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
        beqz a0, 1f
        lw t0, LISP_OBJECT_REFCOUNT(a0)
        addi t0, t0, 1
        sw t0, LISP_OBJECT_REFCOUNT(a0)
1:
        ret

# decrement refcount and deallocate if <= 0
.global release_object
release_object:
        beqz a0, 1f
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
        lwu s2, LISP_OBJECT_TYPE(sp)
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
        # release data if not nil
        ld a0, LISP_PROCEDURE_DATA(s1)
        beqz a0, .Ldeallocate_object_end
        call release_object
.Ldeallocate_object_end:
        mv a0, s1
        li a1, LISP_OBJECT_SIZE
        call deallocate
        ld ra, 0(sp)
        ld s1, 8(sp)
        ld s2, 16(sp)
        addi sp, sp, 24

# a0 = length
# a1 = src pointer
# a2 = dest pointer
.global mem_copy
mem_copy:
        # round a0 to doublewords and put the remainder bytes in t1
        andi t1, a0, (1 << 3) - 1
        andi a0, a0, (-1 << 3)
.Lmem_copy_dw:
        beqz a0, .Lmem_copy_bytes
        ld t0, (a1)
        sd t0, (a2)
        addi a0, a0, -8
        addi a1, a1, 8
        addi a2, a2, 8
        j .Lmem_copy_dw
.Lmem_copy_bytes:
        beqz t1, .Lmem_copy_ret
        lb t0, (a1)
        sb t0, (a2)
        addi t1, t1, -1
        addi a1, a1, 1
        addi a2, a2, 1
        j .Lmem_copy_bytes
.Lmem_copy_ret:
        ret

# compare memory
# a0, a1 = buf, len of A
# a2, a3 = buf, len of B
# ret: a0 = -1 (A < B), 0 (A = B), 1 (A > B)
.global mem_compare
mem_compare:
        # determine minimum length for counter
        bgt a1, a3, 1f
        mv t1, a1
        j 2f
1:
        mv t1, a3
2:
.Lmem_compare_loop:
        beqz t1, .Lmem_compare_end
        # read the two bytes
        lb t2, (a0)
        lb t3, (a2)
        # compare
        sltu t4, t2, t3 # t4 = 1 if A < B
        sltu t5, t3, t2 # t5 = 1 if A > B
        sub t4, zero, t4 # t4 = -t4
        add t4, t4, t5 # t4 = -(A < B) + (A > B)
        bnez t4, .Lmem_compare_different # if t4 != 0, there's a difference
        # increment ptrs, decrement counter
        # note: don't decrement lengths because we may need to compare them before returning
        # and we don't use them anyway
        addi a0, a0, 1
        addi a2, a2, 1
        addi t1, t1, -1
        j .Lmem_compare_loop
.Lmem_compare_different:
        # there's a byte difference, so return t4 as our return value
        mv a0, t4
        ret
.Lmem_compare_end:
        # reached end of one or both strings, so the return value basically now is whichever length
        # is gt/lt
        sltu t1, a1, a3 # t1 = 1 if A < B
        sltu t2, a3, a1 # t2 = 1 if A > B
        sub t1, zero, t1 # t1 = -t1
        add a0, t1, t2 # return -(A < B) + (A > B)
        ret


# a0 = start address
# a1 = length in double-words
# a2 = value (double-word) to set
.global mem_set_d
mem_set_d:
        # determine max address
        add t1, a0, a1 # add length to addr
1:
        bge a0, t1, 2f
        sd zero, (a0)
        addi a0, a0, 8
        j 1b
2:
        ret


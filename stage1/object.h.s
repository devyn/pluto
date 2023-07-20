# Offsets within struct lisp_object
.set LISP_OBJECT_TYPE,     0
.set LISP_OBJECT_REFCOUNT, 4

.set LISP_CONS_HEAD, 8
.set LISP_CONS_TAIL, 16

.set LISP_STRING_BUF, 8
.set LISP_STRING_LEN, 16
.set LISP_STRING_CAP, 24

.set LISP_PROCEDURE_PTR, 8
.set LISP_PROCEDURE_LEN, 16

# Size of a lisp_object in bytes
.set LISP_OBJECT_SIZE, 32

# lisp object type values
.set LISP_OBJECT_TYPE_INTEGER,    0
.set LISP_OBJECT_TYPE_SYMBOL,     1
.set LISP_OBJECT_TYPE_CONS,       2
.set LISP_OBJECT_TYPE_STRING,     3
.set LISP_OBJECT_TYPE_PROCEDURE,  4
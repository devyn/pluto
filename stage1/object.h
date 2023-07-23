#define LISP_OBJECT_TYPE_INTEGER    0
#define LISP_OBJECT_TYPE_SYMBOL     1
#define LISP_OBJECT_TYPE_CONS       2
#define LISP_OBJECT_TYPE_STRING     3
#define LISP_OBJECT_TYPE_PROCEDURE  4

// This is just pseudocode to describe the structure of the lisp objects in memory
struct lisp_cons {
  struct lisp_object *head; // NULL = nil
  struct lisp_object *tail; // NULL = nil
};

struct lisp_symbol {
  char *buf;
  unsigned long len; // cap = len for symbols (they must be allocated with exact size)
};

struct lisp_string {
  char *buf;
  unsigned long len; // the length of the string
  unsigned long cap; // the actual size of the allocated buffer
};

struct lisp_procedure {
  void (*ptr)(struct lisp_object* args);
  unsigned long len; // if > 0, procedure is owned by the object and should be destroyed with it
};

struct lisp_object {
  unsigned int type;
  int refcount; // should be >= 1, or else destroy
  union {
    long as_integer;
    struct lisp_symbol as_symbol;
    struct lisp_cons as_cons;
    struct lisp_string as_string;
    struct lisp_procedure as_procedure;
  } value;
};

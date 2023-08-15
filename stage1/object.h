#define LISP_OBJECT_TYPE_INTEGER    1
#define LISP_OBJECT_TYPE_SYMBOL     2
#define LISP_OBJECT_TYPE_CONS       3
#define LISP_OBJECT_TYPE_STRING     4
#define LISP_OBJECT_TYPE_PROCEDURE  5

// This is just pseudocode to describe the structure of the lisp objects in memory
struct lisp_cons {
  struct lisp_object *head; // NULL = nil
  struct lisp_object *tail; // NULL = nil
};

struct lisp_symbol {
  char *buf;
  unsigned long len; // cap = len for symbols (they must be allocated with exact size)
  char hash; // for hashtables
};

struct lisp_string {
  char *buf;
  unsigned long len; // the length of the string
  unsigned long cap; // the actual size of the allocated buffer
};

struct lisp_procedure {
  struct lisp_return (*ptr)(
    struct lisp_object *args,
    struct lisp_object *local_words,
    struct lisp_object *data
  );
  struct lisp_object *data; // passed on call, can be nil
};

struct lisp_return {
  long status;
  struct lisp_object *return_value;
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

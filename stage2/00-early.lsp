; (define <key> <value>)
(call-native define$
  (ref (quote define))
  (ref (proc args scope
    (call-native define$
      (ref (car args))
      (ref (eval scope (car (cdr args))))))))

; define nil just because
(define nil ())

; (cadr <arg>) = (car (cdr <arg>))
(define cadr (proc args scope
  (car (cdr (eval scope (car args))))))

; (allocate <size> <align>)
(define allocate (proc args scope
  (car
    (call-native allocate$
      (eval scope (car args))
      (eval scope (cadr args))))))

; (cons <head> <tail>)
(define cons (proc args scope
  (deref
    (poke.d (allocate 0x20 0x8)
      0x0000000100000003 ; type = 3, refcount = 1
      (ref (eval scope (car args)))
      (ref (eval scope (cadr args)))
      0x0))))

; (local) = get local scope
(define local (proc () scope scope))

; (unquote <expression>)
(define unquote (proc args scope
  (eval scope (eval scope (car args)))))

; (seq1 <discard> <ret>) = ret
(define seq1 (proc args scope
  (cdr (cons
    (eval scope (car args))
    (eval scope (cadr args))))))

; (print <object>) = <object>
(define print (proc args scope
  (deref (car
    (call-native print-obj$
      (ref (eval scope (car args))))))))

; (let1 <var> <value> <expression>)
; Sets <var> (lit) to <value> (eval) for the evaluation of <expression> (lit)
(define let1 (proc args scope
  (eval
    (cons (cons (car args) (eval scope (cadr args))) scope)
    (cadr (cdr args)))))

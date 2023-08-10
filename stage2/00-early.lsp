; (define <key> <value>) = ?
(call-native define$ 0
  (ref (quote define))
  (ref (proc args scope
    (call-native define$ 0
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
    (call-native allocate$ 1
      (eval scope (car args))
      (eval scope (cadr args))))))

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

; redefine define to return the original value
(define define (proc args scope
  (seq1
    (call-native define$ 0
      (ref (car args))
      (ref (eval scope (cadr args))))
    (eval scope (car args)))))

; (print <object>) = <object>
(define print (proc args scope
  (deref (car
    (call-native print-obj$ 1
      (ref (eval scope (car args))))))))

; (let1 <var> <value> <expression>)
; Sets <var> (lit) to <value> (eval) for the evaluation of <expression> (lit)
(define let1 (proc args scope
  (eval
    (cons (cons (car args) (eval scope (cadr args))) scope)
    (cadr (cdr args)))))

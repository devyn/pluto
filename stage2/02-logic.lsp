; (swap-if <bool> <a> <b>)
; Returns (<a> <b>) if bool = 0 (false), or (<b> <a>) otherwise
(define swap-if$ (allocate 28 4))
(poke.w swap-if$
  0x00050863 ; beqz a0, 1f
  0x00058313 ; mv t1, a1
  0x00060593 ; mv a1, a2
  0x00030613 ; mv a2, t1
  0x00058513 ; 1: mv a1, a2
  0x00060593 ; mv a0, a1
  0x00008067 ; ret
)

(define swap-if
  (proc args scope
    (let1 address-pair
      (call-native swap-if$ 2
        (eval scope (car args))
        (ref (eval scope (cadr args)))
        (ref (eval scope (cadr (cdr args)))))
      (cons (deref (car address-pair))
        (cons (deref (cadr address-pair)) ())))))

; (if <bool> <a> <b>)
; Evaluates <a> if bool, <b> if not bool
(define if (proc args scope
  (eval scope
    (cadr ; if bool, <a> will be second
      (swap-if (eval scope (car args))
        (cadr args) (cadr (cdr args)))))))

; (cleanup <address> <expression>)
; Dereferences <address> after evaluating the expression, returning the expression
; Can be used to clean up a ref passed to a call-native
(define cleanup (proc args scope
  (let1 address (eval scope (car args))
    (let1 ret-value (eval scope (cadr args))
      (seq1 (deref address) ret-value)))))

; Returns 1 if the argument is zero
(define zero?$ (allocate 8 4))
(poke.w zero?$
  0x00153513 ; seqz a0, a0
  0x00008067 ; ret
)
(define zero? (proc args scope
  (car (call-native zero?$ 1 (eval scope (car args))))))

; Returns 1 if the argument is nil
(define nil? (proc args scope
  (let1 value (ref (eval scope (car args)))
    (cleanup value (car (call-native zero?$ 1 value))))))

; Returns 1 if the two numbers are equal
(define number-eq? (proc args scope
  (zero? (car (call-native ^$ 1
    (eval scope (car args))
    (eval scope (cadr args)))))))

; Returns 1 if two objects have the same address
(define ref-eq? (proc args scope
  (let1 a (ref (eval scope (car args)))
    (let1 b (ref (eval scope (cadr args)))
      (cleanup a
        (cleanup b
          (number-eq? a b)))))))

; Symbol equality is same as ref equality
(define symbol-eq? ref-eq?)

; seq multiple
(define seq (proc args scope
  (if (nil? (cdr args))
    (eval scope (car args))
    (seq1
      (eval scope (car args))
      (eval scope (cons seq (cdr args)))))))
; (define <key> <value>)
(call-native define$
  (ref (quote define))
  (ref (proc args scope
    (call-native define$
      (ref (car args))
      (ref (eval scope (car (cdr args))))))))

; (cadr <arg>) = (car (cdr <arg>))
(define cadr (proc args scope
  (car (cdr (eval scope (car args))))))

; (allocate <size> <align>)
(define allocate (proc args scope
  (car
    (call-native (peek.d allocate$$)
      (eval scope (car args))
      (eval scope (cadr args))))))

; (cons <head> <tail>)
(define cons (proc args scope
  (deref
    (poke.d (allocate 0x20 0x8)
      0x0000000100000002 ; type = 2, refcount = 1
      (ref (eval scope (car args)))
      (ref (eval scope (cadr args)))
      0x0))))

; (seq <discard> <ret>) = ret
(define seq (proc args scope
  (cdr (cons
    (eval scope (car args))
    (eval scope (cadr args))))))

; (print <object>)
(define print (proc args scope
  (seq
    (call-native print-obj$
      (ref (eval scope (car args))))
    ())))

; Create procedure from native math routine
; (proc.native-math <address>)
(define proc.native-math
  (proc def-args def-scope
    (proc args scope
      (car ; a0
        (call-native (eval def-scope (car def-args))
          ; a0, a1
          (eval scope (car args))
          (eval scope (cadr args)))))))

; (+ <num1> <num2>)
(define +$ (allocate 0x8 0x4))
(poke.w +$
  0x00b50533 ; add a0, a0, a1
  0x00008067 ; ret
)
(define + (proc.native-math +$))

; (<< <num> <shift>)
(define <<$ (allocate 0x8 0x4))
(poke.w <<$
  0x00b51533 ; sll a0, a0, a1
  0x00008067 ; ret
)
(define << (proc.native-math <<$))

; (>> <num> <shift>)
(define >>$ (allocate 0x8 0x4))
(poke.w >>$
  0x40b55533 ; sra a0, a0, a1
  0x00008067 ; ret
)
(define >> (proc.native-math >>$))

; (& <num1> <num2>)
(define &$ (allocate 0x8 0x4))
(poke.w &$
  0x00b57533 ; and a0, a0, a1
  0x00008067 ; ret
)
(define & (proc.native-math &$))

; (| <num1> <num2>)
(define |$ (allocate 0x8 0x4))
(poke.w |$
  0x00b56533 ; or a0, a0, a1
  0x00008067 ; ret
)
(define | (proc.native-math |$))

; (^ <num1> <num2>)
(define ^$ (allocate 0x8 0x4))
(poke.w ^$
  0x00b54533 ; xor a0, a0, a1
  0x00008067 ; ret
)
(define ^ (proc.native-math ^$))

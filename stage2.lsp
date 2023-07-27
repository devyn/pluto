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

; (print <object>)
(define print (proc args scope
  (seq1
    (call-native print-obj$
      (ref (eval scope (car args))))
    ())))

; create native machine instructions for critical math operations
; these are not nice to use as they are but it allows us to at least do
; some math, until we define the proper operator procs later

; addition, a0 + a1
(define +$ (allocate 0x8 0x4))
(poke.w +$
  0x00b50533 ; add a0, a0, a1
  0x00008067 ; ret
)

; left shift, a0 << a1
(define <<$ (allocate 0x8 0x4))
(poke.w <<$
  0x00b51533 ; sll a0, a0, a1
  0x00008067 ; ret
)

; right arithmetic (sign extend) shift, a0 >> a1
(define >>$ (allocate 0x8 0x4))
(poke.w >>$
  0x40b55533 ; sra a0, a0, a1
  0x00008067 ; ret
)

; logical and, a0 & a1
(define &$ (allocate 0x8 0x4))
(poke.w &$
  0x00b57533 ; and a0, a0, a1
  0x00008067 ; ret
)

; logical or, a0 | a1
(define |$ (allocate 0x8 0x4))
(poke.w |$
  0x00b56533 ; or a0, a0, a1
  0x00008067 ; ret
)

; logical xor, a0 ^ a1
(define ^$ (allocate 0x8 0x4))
(poke.w ^$
  0x00b54533 ; xor a0, a0, a1
  0x00008067 ; ret
)

; (let1 <var> <value> <expression>)
; Sets <var> (lit) to <value> (eval) for the evaluation of <expression> (lit)
(define let1 (proc args scope
  (eval
    (cons (cons (car args) (eval scope (cadr args))) scope)
    (cadr (cdr args)))))

; (let-recursive <var> <value> <expression>)
; HACK: modifies the definition after the evaluation of value so that late
; self-references can be accommodated, allowing for example tail-recursive
; procs
(define let-recursive (proc args scope
  (let1 scope'
    (cons (cons (car args) ()) scope) ; prepend (<var> . ())
    (let1 value
      (eval scope' (cadr args))
      (seq1
        (let1 pair-ref (ref (car scope'))
          ; modify the tail of the cons in-place
          ; usually you should not do this
          (seq1
            (poke.d (car (call-native +$ pair-ref 0x10)) (ref value))
            (deref pair-ref)))
        (eval scope' (cadr (cdr args))))))))

; (swap-if <bool> <a> <b>)
; Returns (<a> <b>) if bool = 0 (false), or (<b> <a>) otherwise
(define swap-if$ (allocate 0x1c 0x4))
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
      (call-native swap-if$
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

; Returns 1 if the argument is nil
(define nil?$ (allocate 0x8 0x4))
(poke.w nil?$
  0x00153513 ; seqz a0, a0
  0x00008067 ; ret
)
(define nil? (proc args scope
  (let1 value (ref (eval scope (car args)))
    (cleanup value (car (call-native nil?$ value))))))

; Create procedure from native math routine
; (proc.native-math <address>)
; These can take any number of arguments and fold them. e.g. (+ a b c) = a + b + c
(define proc.native-math
  (proc def-args def-scope
    (let1 address (eval def-scope (car def-args))
      (let-recursive self
        (proc args scope
          (if (nil? (cdr args))
            (eval scope (car args)) ; no more args
            (let1 value
              (car ;a0
                (call-native address
                  (eval scope (car args))
                  (eval scope (cadr args))))
              ; tail recursive call with remainder of args
              (unquote (cons self (cons value (cdr (cdr args))))))))
        self))))

; define nicer versions of the core math ops we put into memory earlier
(define + (proc.native-math +$))
(define << (proc.native-math <<$))
(define >> (proc.native-math >>$))
(define & (proc.native-math &$))
(define | (proc.native-math |$))
(define ^ (proc.native-math ^$))

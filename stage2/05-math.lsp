; Create procedure from native math routine
; (proc.native-math <address>)
; These can take any number of arguments and fold them. e.g. (+ a b c) = a + b + c
(define fn.native-math
  (fn (address)
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
            (eval scope (cons self (cons value (cdr (cdr args))))))))
      self)))

; define nicer versions of the core math ops we put into memory earlier
(define + (fn.native-math +$))
(define - (fn.native-math -$))
(define << (fn.native-math <<$))
(define >> (fn.native-math >>$))
(define & (fn.native-math &$))
(define | (fn.native-math |$))
(define ^ (fn.native-math ^$))

; print hex number, plain
(define put-hex (fn (number digits)
  (seq1
    (call-native put-hex$ number
      (if (nil? digits) 16 digits))
    number)))

; Calculate bit mask = (1 << n) - 1
(define bit-mask
  (fn (bits) (+ (<< 0x1 bits) -1)))

; increment number by one
(define increment (fn (val) (+ 1 val)))

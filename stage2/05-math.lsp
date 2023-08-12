; Create procedure from native math routine
; (fn.native-math <address>)
; In the interest of speed, these can only take two arguments for now
(define fn.native-math
  (fn (address)
    (proc args scope
      (car (unquote (cons call-native (cons address (cons 1 (eval-list scope args)))))))))

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
    (call-native put-hex$ 0 number
      (if (nil? digits) 16 digits))
    number)))

; Calculate bit mask = (1 << n) - 1
(define bit-mask
  (fn (bits) (+ (<< 0x1 bits) -1)))

; increment number by one
(define increment (fn (val) (+ 1 val)))

; Get type number of object
(define type-number-of (fn (arg)
  (let1 address (ref arg)
    (cleanup address (peek.w address)))))

; Get refcount of object
(define refcount-of (fn (arg)
  (let1 address (ref arg)
    (cleanup address (peek.w (car (call-native +$ 1 address 0x4)))))))

; Get type of object as symbol
(define types$ (allocate 0x40 8))
(poke.d types$
  (ref (quote none))
  (ref (quote integer))
  (ref (quote symbol))
  (ref (quote cons))
  (ref (quote string))
  (ref (quote procedure))
  (ref (quote unknown))
  (ref (quote unknown))
)
(define type-of (fn (arg)
  (let1 symbol
    (deref
      (peek.d
        (+ types$
          (<< (& (type-number-of arg) 7) 3))))
    (seq1
      (ref symbol) ; don't let the reference drop
      symbol))))

; length of a list
(define length (fn (list)
  (left-fold increment 0 list)))

; create procedure from raw address, data object
(define box-procedure
  (fn (address data)
    (deref (poke.d
      (allocate 0x20 0x8)
      0x100000005 ; type = procedure, refcount = 1
      address
      (ref data)))))

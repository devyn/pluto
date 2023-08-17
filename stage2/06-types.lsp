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

; get address and data from procedure
(define unbox-procedure
  (fn (procedure)
    (if (symbol-eq? (type-of procedure) (quote procedure))
      (let
        (
          (proc-address (ref procedure))
          (address (peek.d (+ proc-address 8)))
          (data (deref (car (call-native acquire-object$ 1 (peek.d (+ proc-address 16))))))
        )
        (seq1 (deref proc-address) (list address data)))
      ())))

; get internal fields from proc
(define proc-stub (car (unbox-procedure (proc () ())))) ; address of any proc procedure
(define proc-fields
  (fn (procedure)
    (let1 addr-data (unbox-procedure procedure)
      (if (number-eq? proc-stub (car addr-data)) ; ensure this is a proc procedure
        (let
          (
            (proc-data-addr (ref (cadr addr-data)))
            (proc-fields-addr (peek.d (+ proc-data-addr 16)))
          )
          (seq
            (call-native release-object$ 0 proc-data-addr)
            (map
              ; get each field
              (fn (index)
                (let1 field-addr (peek.d (+ proc-fields-addr (<< index 3)))
                  (seq
                    (call-native acquire-object$ 0 field-addr)
                    (deref field-addr))))
              (range 0 4))))
        ()))))

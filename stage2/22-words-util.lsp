(define global-value-of (fn (symbol)
  (if (ref-eq? (type-of symbol) (quote symbol))
    (let
      (
        (symbol-addr (ref symbol))
        (global-value-addr (peek.d (+ symbol-addr 24)))
      )
      (seq
        (call-native acquire-object$ 0 global-value-addr)
        (call-native release-object$ 0 symbol-addr)
        (deref global-value-addr)))
    (error (quote not-a-symbol:) symbol))))

(define get-words (fn (index)
  (let1 addr (peek.d (+ words$ (<< index 3)))
    (seq
      (call-native acquire-object$ 0 addr)
      (deref addr))))))

;(map (fn (index) (length (get-words index))) (range 0 255))

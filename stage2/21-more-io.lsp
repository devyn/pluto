; print string
(define put-str (fn (string)
  (if (symbol-eq? (type-of string) (quote string))
    (let1 address (ref string)
      (seq1
        (call-native put-buf$ 0
          (peek.d (+ address 0x08))
          (peek.d (+ address 0x10)))
        (deref address)))
    (error (quote not-a-string:) string))))

; put char
(define putc (fn (char) (seq1 (call-native putc$ 0 char) char)))

; print hex nicely
(define print-hex
  (fn (number)
    (seq
      (put-str "0x")
      (put-hex number)
      (putc 10)
      number)))

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
            (poke.d (car (call-native +$ 1 pair-ref 0x10)) (ref value))
            (deref pair-ref)))
        (eval scope' (cadr (cdr args))))))))

; evaluate all elements of a list
(define eval-list
  (let-recursive map
    (proc args scope
      (if (nil? args) ()
        (cons (eval scope (car args)) (eval scope (cons map (cdr args))))))
    ; pass evaluated list to `map`, running it in the provided scope
    (proc args scope
      (eval (eval scope (car args)) (cons map (eval scope (cadr args)))))))

; make a list from args
(define list
  (proc args scope (eval-list scope args)))

; associate two lists into pairs
; if the second list is shorter than the first, remaining pairs will be associated to nil
(define assoc
  (let-recursive map
    (proc args ()
      (if (nil? (car args))
        ()
        (cons
          (cons
            (car (car args))
            (car (cadr args)))
          (unquote (list map
            (cdr (car args))
            (cdr (cadr args)))))))
    ; pass evaluated first and second arg to `map`
    (proc args scope
      (unquote (list map
        (eval scope (car args))
        (eval scope (cadr args)))))))

; concat two lists
(define concat
  (let-recursive rec
    (proc args scope
      (if (nil? (car args))
        (cadr args)
        (cons (car (car args))
          (unquote (list rec
            (cdr (car args))
            (cadr args))))))
    (proc args scope
      (unquote (list rec
        (eval scope (car args))
        (eval scope (cadr args)))))))

; (range 0 5) => (0 1 2 3 4)
(define range
  (proc args scope
    (let1 start (eval scope (car args))
      (let1 end (eval scope (cadr args))
        (if (zero? (car (call-native -$ 1 end start)))
          ()
          (cons start (range
            (car (call-native +$ 1 start 1))
            end)))))))
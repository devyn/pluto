; Linker

; size of a section after linking
(define link.section-size (fn (section)
  (<< (length section) 2))) ; 4 bytes per instruction (we don't support RV-C)

; size of a program after linking
(define link.program-size
  (let1
    accumulate (fn (acc named-section)
      (+ acc (link.section-size (cdr named-section))))
    (fn (program)
      (left-fold accumulate 0 program))))

; place sections relative to start offset
(define link.section-addrs
  (let1
    accumulate (fn (acc named-section)
      ; acc = (offset (s1 . addr) (s2 . addr) ... (sN . addr))
      (let1
        size (link.section-size (cdr named-section))
        (cons
          (+ (car acc) size) ; next offset
          ; define: (section-name . offset)
          (cons
            (cons (car named-section) (car acc))
            (cdr acc)))))
    (fn (start program)
      (cdr (left-fold accumulate (cons start ()) program)))))

; link a program
; expects multiple named sections with instructions following the name
; symbols defined in context: pc, rel, rel+, all sections
; returns the address, size, and sections of the program
(define link (proc program scope
  (let
    (
      (program-size (link.program-size program))
      (program-addr (allocate program-size 4))
      (section-addrs (link.section-addrs program-addr program))
      (rel (proc args scope
        ; [0] - pc
        (-
          (eval scope (car args))
          (eval scope (quote pc)))))
      ; offset by one instruction
      (rel+ (proc args scope
        (+ 4 (eval scope (cons rel args)))))
      (program-scope
        (concat
          ; define rel and rel+
          (list
            (cons (quote rel) rel)
            (cons (quote rel+) rel+)
          )
          (concat section-addrs scope)))
      (put-instruction
        (fn (pc instruction-expr)
          (+ 4 ; next pc
            (poke.w pc ; put instruction in memory
              (eval
                (cons (cons (quote pc) pc) program-scope) ; define pc in eval scope
                instruction-expr)))))
    )
    (seq
      (left-fold
        ; put the instructions inside each named section, skipping over the name,
        ; and keeping a program counter around to increment
        (fn (pc named-section)
          (left-fold put-instruction pc (cdr named-section)))
        program-addr ; start pc = base addr
        program)
      ; the output of the above should be the end address of the program,
      ; but we want to return (addr size section-addrs)
      (list program-addr program-size section-addrs)))))


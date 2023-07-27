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

; evaluate all elements of a list
(define eval-list
  (let-recursive map
    (proc args scope
      (if (nil? args) ()
        (cons (eval scope (car args)) (eval scope (cons map (cdr args))))))
    ; pass evaluated list to `map`, running it in the provided scope
    (proc args scope
      (eval (eval scope (car args)) (cons map (eval scope (cadr args)))))))

; associate two lists into pairs
(define assoc
  (let-recursive map
    (proc args ()
      (if (nil? (car args))
        ()
        (if (nil? (cadr args))
          ()
          (cons
            (cons
              (car (car args))
              (car (cadr args)))
            (unquote (cons map
              (cons (cdr (car args))
                (cons (cdr (cadr args))))))))))
    ; pass evaluated first and second arg to `map`
    (proc args scope
      (unquote (cons map
        (cons (eval scope (car args))
          (cons (eval scope (cadr args)))))))))

; concat two lists
(define concat
  (let-recursive rec
    (proc args scope
      (if (nil? (car args))
        (cadr args)
        (cons (car (car args))
          (unquote (cons rec
            (cons (cdr (car args)) (cons (cadr args))))))))
    (proc args scope
      (unquote (cons rec
        (cons (eval scope (car args))
          (cons (eval scope (cadr args)))))))))

; (fn (arg0 arg1) expression)
; allows you to much more nicely define a function - just provide arg list
; and destructuring will happen automatically
(define fn (proc def-args def-scope
  (proc args scope
    (eval
      (concat (assoc (car def-args) (eval-list scope args)) def-scope)
      (cadr def-args)))))

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
            (unquote (cons self (cons value (cdr (cdr args))))))))
      self)))

; define nicer versions of the core math ops we put into memory earlier
(define + (fn.native-math +$))
(define << (fn.native-math <<$))
(define >> (fn.native-math >>$))
(define & (fn.native-math &$))
(define | (fn.native-math |$))
(define ^ (fn.native-math ^$))

; Calculate bit mask = (1 << n) - 1
(define bit-mask
  (fn (bits) (+ (<< 0x1 bits) 0xffffffffffffffff)))

; RISC-V instruction formats
(define rv.opcode-mask (bit-mask 0x7))
(define rv.reg-mask (bit-mask 0x5))
(define rv.funct3-mask (bit-mask 0x3))
(define rv.funct7-mask (bit-mask 0x7))
(define rv.instr.r
  (fn (opcode funct3 funct7)
    (fn (rd rs1 rs2)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 0x7)
        (<< (& funct3 rv.funct3-mask) 0xc)
        (<< (& rs1 rv.reg-mask) 0xf)
        (<< (& rs2 rv.reg-mask) 0x14)
        (<< (& funct7 rv.funct7-mask) 0x19)))))
(define rv.instr.i
  (fn (opcode funct3)
    (fn (rd rs1 imm)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 0x7)
        (<< (& funct3 rv.funct3-mask) 0xc)
        (<< (& rs1 rv.reg-mask) 0xf)
        (<< (& imm (bit-mask 0xc)) 0x14)))))
(define rv.instr.s
  (fn (opcode funct3)
    (fn (opcode rs2 imm rs1)
      (| (& opcode rv.opcode-mask)
        (<< (& imm (bit-mask 0x5)) 0x7)
        (<< (& funct3 rv.funct3-mask) 0xc)
        (<< (& rs1 rv.reg-mask) 0xf)
        (<< (& rs2 rv.reg-mask) 0x14)
        (<< (& (>> imm 0x5) (bit-mask 0x7)) 0x19)))))
(define rv.instr.b
  (fn (opcode funct3)
    (fn (opcode rs1 rs2 imm)
      (| (& opcode rv.opcode-mask)
        (<< (& (>> imm 0xb) 0x1) 0x7)
        (<< (& (>> imm 0x1) (bit-mask 0x4)) 0x8)
        (<< (& funct3 rv.funct3-mask) 0xc)
        (<< (& rs1 rv.reg-mask) 0xf)
        (<< (& rs2 rv.reg-mask) 0x14)
        (<< (& (>> imm 0x5) (bit-mask 0x5)) 0x19)
        (<< (& (>> imm 0xc) 0x1) 0x1f)))))


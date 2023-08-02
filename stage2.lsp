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
      0x0000000100000003 ; type = 3, refcount = 1
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

; Returns 1 if the argument is zero
(define zero?$ (allocate 0x8 0x4))
(poke.w zero?$
  0x00153513 ; seqz a0, a0
  0x00008067 ; ret
)
(define zero? (proc args scope
  (car (call-native zero?$ (eval scope (car args))))))

; Returns 1 if the argument is nil
(define nil? (proc args scope
  (let1 value (ref (eval scope (car args)))
    (cleanup value (car (call-native zero?$ value))))))

; Returns 1 if the two numbers are equal
(define number-eq? (proc args scope
  (zero? (car (call-native ^$
    (eval scope (car args))
    (eval scope (cadr args)))))))

; Returns 1 if two objects have the same address
(define ref-eq? (proc args scope
  (let1 a (ref (eval scope (car args)))
    (let1 b (ref (eval scope (car args)))
      (cleanup a
        (cleanup b
          (number-eq? a b)))))))

; Symbol equality is same as ref equality
(define symbol-eq? ref-eq?)

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

; Get type number of object
(define type-number-of (fn (arg)
  (let1 address (ref arg)
    (cleanup address (peek.w address)))))

; Get refcount of object
(define refcount-of (fn (arg)
  (let1 address (ref arg)
    (cleanup address (peek.w (car (call-native +$ address 0x4)))))))

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
(define << (fn.native-math <<$))
(define >> (fn.native-math >>$))
(define & (fn.native-math &$))
(define | (fn.native-math |$))
(define ^ (fn.native-math ^$))

; Get type of object as symbol
(define types$ (allocate 0x40 0x8))
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
          (<< (& (type-number-of arg) 0x7) 0x3))))
    (seq1
      (ref symbol) ; don't let the reference drop
      symbol))))

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
    (fn (rs2 imm rs1)
      (| (& opcode rv.opcode-mask)
        (<< (& imm (bit-mask 0x5)) 0x7)
        (<< (& funct3 rv.funct3-mask) 0xc)
        (<< (& rs1 rv.reg-mask) 0xf)
        (<< (& rs2 rv.reg-mask) 0x14)
        (<< (& (>> imm 0x5) (bit-mask 0x7)) 0x19)))))
(define rv.instr.b
  (fn (opcode funct3)
    (fn (rs1 rs2 imm)
      (| (& opcode rv.opcode-mask)
        (<< (& (>> imm 0xb) 0x1) 0x7)
        (<< (& (>> imm 0x1) (bit-mask 0x4)) 0x8)
        (<< (& funct3 rv.funct3-mask) 0xc)
        (<< (& rs1 rv.reg-mask) 0xf)
        (<< (& rs2 rv.reg-mask) 0x14)
        (<< (& (>> imm 0x5) (bit-mask 0x5)) 0x19)
        (<< (& (>> imm 0xc) 0x1) 0x1f)))))
(define rv.instr.u
  (fn (opcode)
    (fn (rd imm)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 0x7)
        (+ ; add one if 11th bit is set
          (& imm (<< (bit-mask 0x14) 0xc))
          (<< (& imm 0x800) 0x1))))))
(define rv.instr.j
  (fn (opcode)
    (fn (rd imm)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 0x7)
        (& imm (<< (bit-mask 0x8) 0xc))           ; inst[19:12] = imm[19:12]
        (<< (& (>> imm 0xb) 0x1) 0x14)            ; inst[20]    = imm[11]
        (<< (& (>> imm 0x1) (bit-mask 0xa)) 0x15) ; inst[30:21] = imm[10:1]
        (<< (& (>> imm 0x14) 0x1) 0x1f)))))       ; inst[31]    = imm[20]

; RISC-V registers
(define $zero 0x0)
(define $ra 0x1)
(define $sp 0x2)
(define $gp 0x3)
(define $tp 0x4)
(define $t0 0x5)
(define $t1 0x6)
(define $t2 0x7)
(define $s0 0x8)
(define $fp 0x8)
(define $s1 0x9)
(define $a0 0xa)
(define $a1 0xb)
(define $a2 0xc)
(define $a3 0xd)
(define $a4 0xe)
(define $a5 0xf)
(define $a6 0x10)
(define $a7 0x11)
(define $s2 0x12)
(define $s3 0x13)
(define $s4 0x14)
(define $s5 0x15)
(define $s6 0x16)
(define $s7 0x17)
(define $s8 0x18)
(define $s9 0x19)
(define $s10 0x1a)
(define $s11 0x1b)
(define $t3 0x1c)
(define $t4 0x1d)
(define $t5 0x1e)
(define $t6 0x1f)

; RV32I instructions
(define \lui   (rv.instr.u 0x37))
(define \auipc (rv.instr.u 0x17))
(define \jal   (rv.instr.j 0x6f))
(define \jalr  (rv.instr.i 0x67 0x0))
(define \beq   (rv.instr.b 0x63 0x0))
(define \bne   (rv.instr.b 0x63 0x1))
(define \blt   (rv.instr.b 0x63 0x4))
(define \bge   (rv.instr.b 0x63 0x5))
(define \bltu  (rv.instr.b 0x63 0x6))
(define \bgeu  (rv.instr.b 0x63 0x7))
(define \lb    (rv.instr.i 0x3 0x0))
(define \lh    (rv.instr.i 0x3 0x1))
(define \lw    (rv.instr.i 0x3 0x2))
(define \lbu   (rv.instr.i 0x3 0x4))
(define \lhu   (rv.instr.i 0x3 0x5))
(define \sb    (rv.instr.s 0x23 0x0))
(define \sh    (rv.instr.s 0x23 0x1))
(define \sw    (rv.instr.s 0x23 0x2))
(define \addi  (rv.instr.i 0x13 0x0))
(define \slti  (rv.instr.i 0x13 0x2))
(define \sltiu (rv.instr.i 0x13 0x3))
(define \xori  (rv.instr.i 0x13 0x4))
(define \ori   (rv.instr.i 0x13 0x6))
(define \andi  (rv.instr.i 0x13 0x7))
(define \slli  (rv.instr.r 0x13 0x1 0x0))
(define \srli  (rv.instr.r 0x13 0x5 0x0))
(define \srai  (rv.instr.r 0x13 0x5 0x20))
(define \add   (rv.instr.r 0x33 0x0 0x0))
(define \sub   (rv.instr.r 0x33 0x0 0x20))
(define \sll   (rv.instr.r 0x33 0x1 0x0))
(define \slt   (rv.instr.r 0x33 0x2 0x0))
(define \sltu  (rv.instr.r 0x33 0x3 0x0))
(define \xor   (rv.instr.r 0x33 0x4 0x0))
(define \srl   (rv.instr.r 0x33 0x5 0x0))
(define \sra   (rv.instr.r 0x33 0x5 0x20))
(define \or    (rv.instr.r 0x33 0x6 0x0))
(define \and   (rv.instr.r 0x33 0x7 0x0))
; fence is complicated, leaving it out for now
(define \ecall  0x73)
(define \ebreak 0x100073)

; RV64I instructions
(define \lwu   (rv.instr.i 0x3 0x6))
(define \ld    (rv.instr.i 0x3 0x3))
(define \sd    (rv.instr.s 0x23 0x3))
(define \addiw (rv.instr.i 0x1b 0x0))
(define \slliw (rv.instr.r 0x1b 0x1 0x0))
(define \srliw (rv.instr.r 0x1b 0x5 0x0))
(define \sraiw (rv.instr.r 0x1b 0x5 0x20))
(define \addw  (rv.instr.r 0x3b 0x0 0x0))
(define \subw  (rv.instr.r 0x3b 0x0 0x20))
(define \sllw  (rv.instr.r 0x3b 0x1 0x0))
(define \srlw  (rv.instr.r 0x3b 0x5 0x0))
(define \sraw  (rv.instr.r 0x3b 0x5 0x20))

; try a simple assembler program
(define awesome.str$ (allocate 0x8 0x1))
(poke.b awesome.str$
  0x61 0x77 0x65 0x73 0x6f 0x6d 0x65 0x0a
)
(define awesome$ (allocate 0x28 0x8))
(poke.w awesome$
  ; load string to a0
  (\auipc $t0       0x0)
  (\ld    $a0 $t0   0x18)
  ; set length = 8
  (\addi  $a1 $zero 0x8)
  ; load address of put-buf and jump to it
  (\ld    $t0 $t0   0x20)
  (\jalr  $zero $t0 0x0)
  0x0
  ; constants in-line because calculating instructions to load address is too hard
  awesome.str$
  (>> awesome.str$ 0x20)
  put-buf$
  (>> put-buf$ 0x20)
)
(call-native awesome$)

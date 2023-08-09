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
    (call-native allocate$
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

; (print <object>) = <object>
(define print (proc args scope
  (deref (car
    (call-native print-obj$
      (ref (eval scope (car args))))))))

; create native machine instructions for critical math operations
; these are not nice to use as they are but it allows us to at least do
; some math, until we define the proper operator procs later

; addition, a0 + a1
(define +$ (allocate 8 4))
(poke.w +$
  0x00b50533 ; add a0, a0, a1
  0x00008067 ; ret
)

; subtraction, a0 - a1
(define -$ (allocate 8 4))
(poke.w -$
  0x40b50533 ; sub a0, a0, a1
  0x00008067 ; ret
)

; left shift, a0 << a1
(define <<$ (allocate 8 4))
(poke.w <<$
  0x00b51533 ; sll a0, a0, a1
  0x00008067 ; ret
)

; right arithmetic (sign extend) shift, a0 >> a1
(define >>$ (allocate 8 4))
(poke.w >>$
  0x40b55533 ; sra a0, a0, a1
  0x00008067 ; ret
)

; logical and, a0 & a1
(define &$ (allocate 8 4))
(poke.w &$
  0x00b57533 ; and a0, a0, a1
  0x00008067 ; ret
)

; logical or, a0 | a1
(define |$ (allocate 8 4))
(poke.w |$
  0x00b56533 ; or a0, a0, a1
  0x00008067 ; ret
)

; logical xor, a0 ^ a1
(define ^$ (allocate 8 4))
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
(define swap-if$ (allocate 28 4))
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
(define zero?$ (allocate 8 4))
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

; seq multiple
(define seq (proc args scope
  (if (nil? (cdr args))
    (eval scope (car args))
    (seq1
      (eval scope (car args))
      (eval scope (cons seq (cdr args)))))))

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
(define - (fn.native-math -$))
(define << (fn.native-math <<$))
(define >> (fn.native-math >>$))
(define & (fn.native-math &$))
(define | (fn.native-math |$))
(define ^ (fn.native-math ^$))

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

; Calculate bit mask = (1 << n) - 1
(define bit-mask
  (fn (bits) (+ (<< 0x1 bits) -1)))

; RISC-V instruction formats
(define rv.opcode-mask (bit-mask 7))
(define rv.reg-mask (bit-mask 5))
(define rv.funct3-mask (bit-mask 3))
(define rv.funct7-mask (bit-mask 7))
(define rv.instr.r
  (fn (opcode funct3 funct7)
    (fn (rd rs1 rs2)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 7)
        (<< (& funct3 rv.funct3-mask) 12)
        (<< (& rs1 rv.reg-mask) 15)
        (<< (& rs2 rv.reg-mask) 20)
        (<< (& funct7 rv.funct7-mask) 25)))))
(define rv.instr.i
  (fn (opcode funct3)
    (fn (rd rs1 imm)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 7)
        (<< (& funct3 rv.funct3-mask) 12)
        (<< (& rs1 rv.reg-mask) 15)
        (<< (& imm (bit-mask 12)) 20)))))
(define rv.instr.s
  (fn (opcode funct3)
    (fn (rs2 rs1 imm)
      (| (& opcode rv.opcode-mask)
        (<< (& imm (bit-mask 5)) 7)
        (<< (& funct3 rv.funct3-mask) 12)
        (<< (& rs1 rv.reg-mask) 15)
        (<< (& rs2 rv.reg-mask) 20)
        (<< (& (>> imm 5) (bit-mask 7)) 25)))))
(define rv.instr.b
  (fn (opcode funct3)
    (fn (rs1 rs2 imm)
      (| (& opcode rv.opcode-mask)
        (<< (& (>> imm 11) 1) 7)
        (<< (& (>> imm 1) (bit-mask 4)) 8)
        (<< (& funct3 rv.funct3-mask) 12)
        (<< (& rs1 rv.reg-mask) 15)
        (<< (& rs2 rv.reg-mask) 20)
        (<< (& (>> imm 5) (bit-mask 6)) 25)
        (<< (& (>> imm 12) 1) 31)))))
(define rv.instr.u
  (fn (opcode)
    (fn (rd imm)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 7)
        (+ ; add one if 11th bit is set
          (& imm (<< (bit-mask 20) 12))
          (<< (& imm 0x800) 1))))))
(define rv.instr.j
  (fn (opcode)
    (fn (rd imm)
      (| (& opcode rv.opcode-mask)
        (<< (& rd rv.reg-mask) 7)
        (& imm (<< (bit-mask 8) 12))         ; inst[19:12] = imm[19:12]
        (<< (& (>> imm 11) 1) 20)            ; inst[20]    = imm[11]
        (<< (& (>> imm 1) (bit-mask 10)) 21) ; inst[30:21] = imm[10:1]
        (<< (& (>> imm 20) 1) 31)))))        ; inst[31]    = imm[20]

; RISC-V registers
(define $zero 0)
(define $ra 1)
(define $sp 2)
(define $gp 3)
(define $tp 4)
(define $t0 5)
(define $t1 6)
(define $t2 7)
(define $s0 8)
(define $fp 8)
(define $s1 9)
(define $a0 10)
(define $a1 11)
(define $a2 12)
(define $a3 13)
(define $a4 14)
(define $a5 15)
(define $a6 16)
(define $a7 17)
(define $s2 18)
(define $s3 19)
(define $s4 20)
(define $s5 21)
(define $s6 22)
(define $s7 23)
(define $s8 24)
(define $s9 25)
(define $s10 26)
(define $s11 27)
(define $t3 28)
(define $t4 29)
(define $t5 30)
(define $t6 31)

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
(define \ecall  (fn () 0x73))
(define \ebreak (fn () 0x100073))

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

; single-instruction pseudo instructions
(define \ret (fn () (\jalr $zero $ra 0)))

; functional left fold
(define left-fold (fn (f val list)
  (if (nil? list) val
    (left-fold f (f val (car list)) (cdr list)))))

; functional map list
(define map (fn (f list)
  (left-fold
    (fn (out-list val)
      (concat out-list (cons (f val) ())))
    ()
    list)))

; increment number by one
(define increment (fn (val) (+ 1 val)))

; length of a list
(define length (fn (list)
  (left-fold increment 0 list)))

; let multiple
; e.g. (let ((foo 1) (bar 2)) (+ foo bar))
(define let (proc args scope
  (if (nil? (car args))
    (eval scope (cadr args))
    (eval
      (cons
        ; evaluate and define the first variable pair
        (let1 pair (car (car args))
          (cons 
            (car pair)
            (eval scope (cadr pair))))
        scope)
      ; process the rest of the list by recursive call to let
      (cons let
        (cons
          (cdr (car args)) ; the rest of the definition list
          (cdr args))))))) ; the rest of let's args untouched (incl. expression)

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
; symbols defined in context: pc, rel, all sections
; returns the address and size of the program
(define link (proc program scope
  (let
    (
      (program-size (link.program-size program))
      (program-addr (allocate program-size 4))
      (section-addrs (link.section-addrs program-addr program))
      (program-scope
        (cons
          (cons (quote rel) (proc args scope
            ; [0] - pc
            (-
              (eval scope (car args))
              (eval scope (quote pc)))))
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
      ; but we want to return (addr size)
      (cons program-addr (cons program-size ()))))))

; try a simple assembler program
(define awesome.str$ (allocate 0x8 0x1))
(poke.b awesome.str$
  0x61 0x77 0x65 0x73 0x6f 0x6d 0x65 0x0a
)
(define awesome$ (car (link
  (start
    ; initialize counter, stack
    (\addi  $sp $sp (- 0 0x10)) ; negative hex would be nice
    (\sd    $ra $sp 0x00)
    (\sd    $s0 $sp 0x08)
    (\addi  $s0 $zero 5)
  )
  (loop
    ; load address of awesome.str$ to a0
    (\auipc $a0 (rel awesome.str$))
    (\addi  $a0 $a0 (+ (rel awesome.str$) 4))
    ; set length = 8
    (\addi  $a1 $zero 8)
    ; load address of put-buf and call it
    (\auipc $t0 (rel put-buf$))
    (\jalr  $ra $t0 (+ (rel put-buf$) 4))
    ; decrement counter
    (\addi  $s0 $s0 -1)
    ; if not zero jump back to loop
    (\bne   $s0 $zero (rel loop))
  )
  (end
    ; clean up stack, return
    (\ld    $ra $sp 0x00)
    (\ld    $s0 $sp 0x08)
    (\addi  $sp $sp 0x10)
    (\ret)
  )
)))
(call-native awesome$)

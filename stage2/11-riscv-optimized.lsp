; Optimized implementations of the RISC-V instruction formatters
(define rv.format.r$
  (poke.w (allocate (<< 17 2) 4)
    (\andi $a0 $a0 rv.opcode-mask)
    (\andi $a1 $a1 rv.funct3-mask)
    (\andi $a2 $a2 rv.funct7-mask)
    (\andi $a3 $a3 rv.reg-mask) ; rd
    (\andi $a4 $a4 rv.reg-mask) ; rs1
    (\andi $a5 $a5 rv.reg-mask) ; rs2
    (\slli $a3 $a3 7) ; rd
    (\slli $a1 $a1 12) ; funct3
    (\slli $a4 $a4 15) ; rs1
    (\slli $a5 $a5 20) ; rs2
    (\slli $a2 $a2 25) ; funct7
    (\or   $a0 $a0 $a1)
    (\or   $a0 $a0 $a2)
    (\or   $a0 $a0 $a3)
    (\or   $a0 $a0 $a4)
    (\or   $a0 $a0 $a5)
    (\ret)
  ))
(define rv.format.r (quote
  (car (call-native rv.format.r$ 1 opcode funct3 funct7 rd rs1 rs2))))

(define rv.format.i$
  (poke.w (allocate (<< 17 2) 4)
    (\andi $a0 $a0 rv.opcode-mask)
    (\andi $a1 $a1 rv.funct3-mask)
    (\andi $a2 $a2 rv.reg-mask) ; rd
    (\andi $a3 $a3 rv.reg-mask) ; rs1
    ; 12-bit mask
    (\li   $t0 1)
    (\slli $t0 $t0 12)
    (\addi $t0 $t0 -1)
    (\and  $a4 $a4 $t0) ; imm
    (\slli $a2 $a2 7) ; rd
    (\slli $a1 $a1 12) ; funct3
    (\slli $a3 $a3 15) ; rs1
    (\slli $a4 $a4 20) ; imm
    (\or   $a0 $a0 $a1)
    (\or   $a0 $a0 $a2)
    (\or   $a0 $a0 $a3)
    (\or   $a0 $a0 $a4)
    (\ret)
  ))
(define rv.format.i (quote
  (car (call-native rv.format.i$ 1 opcode funct3 rd rs1 imm))))

(define rv.format.s$
  (poke.w (allocate (<< 18 2) 4)
    (\andi $a0 $a0 rv.opcode-mask)
    (\andi $a1 $a1 rv.funct3-mask)
    (\andi $a2 $a2 rv.reg-mask) ; rs2
    (\andi $a3 $a3 rv.reg-mask) ; rs1
    ; split up imm to two fields
    (\andi $t0 $a4 (bit-mask 5))
    (\slli $t0 $t0 7)
    (\srli $t1 $a4 5)
    (\andi $t1 $t1 (bit-mask 7))
    (\slli $t1 $t1 25)
    (\slli $a1 $a1 12) ; funct3
    (\slli $a3 $a3 15) ; rs1
    (\slli $a2 $a2 20) ; rs2
    (\or   $a0 $a0 $a1)
    (\or   $a0 $a0 $a2)
    (\or   $a0 $a0 $a3)
    (\or   $a0 $a0 $t0)
    (\or   $a0 $a0 $t1)
    (\ret)
  ))
(define rv.format.s (quote
  (car (call-native rv.format.s$ 1 opcode funct3 rs2 rs1 imm))))

(define rv.format.u$
  (poke.w (allocate (<< 16 2) 4)
    (\andi $a0 $a0 rv.opcode-mask)
    (\andi $a1 $a1 rv.reg-mask) ; rd
    ; 20-bit upper mask
    (\li   $t0 1)
    (\slli $t0 $t0 20)
    (\addi $t0 $t0 -1)
    (\slli $t0 $t0 12)
    ; add one to 12th bit if 11th bit is set
    (\li   $t1 1)
    (\slli $t1 $t1 11)
    (\and  $t1 $a2 $t1)
    (\slli $t1 $t1 1)
    (\and  $a2 $a2 $t0) ; imm
    (\add  $a2 $a2 $t1)
    (\slli $a1 $a1 7) ; rd
    (\or   $a0 $a0 $a1)
    (\or   $a0 $a0 $a2)
    (\ret)
  ))
(define rv.format.u (quote
  (car (call-native rv.format.u$ 1 opcode rd imm))))

(define rv.format.b$
  (poke.w (allocate (<< 27 2) 4)
    (\andi $a0 $a0 rv.opcode-mask)
    (\andi $a1 $a1 rv.funct3-mask)
    (\andi $a2 $a2 rv.reg-mask)
    (\andi $a3 $a3 rv.reg-mask)
    (\slli $a1 $a1 12) ; funct3
    (\slli $a2 $a2 15) ; rs1
    (\slli $a3 $a3 20) ; rs2
    ; split imm into four pieces
    ; (<< (& (>> imm 11) 1) 7)
    (\srli $t0 $a4 11)
    (\andi $t0 $t0 1)
    (\slli $t0 $t0 7)
    ; (<< (& (>> imm 1) (bit-mask 4)) 8)
    (\srli $t1 $a4 1)
    (\andi $t1 $t1 (bit-mask 4))
    (\slli $t1 $t1 8)
    ; (<< (& (>> imm 5) (bit-mask 6)) 25)
    (\srli $t2 $a4 5)
    (\andi $t2 $t2 (bit-mask 6))
    (\slli $t2 $t2 25)
    ; (<< (& (>> imm 12) 1) 31)
    (\srli $t3 $a4 12)
    (\andi $t3 $t3 1)
    (\slli $t3 $t3 31)
    (\or   $a0 $a0 $a1)
    (\or   $a0 $a0 $a2)
    (\or   $a0 $a0 $a3)
    (\or   $a0 $a0 $t0)
    (\or   $a0 $a0 $t1)
    (\or   $a0 $a0 $t2)
    (\or   $a0 $a0 $t3)
    (\ret)
  ))
(define rv.format.b (quote
  (car (call-native rv.format.b$ 1 opcode funct3 rs1 rs2 imm))))

(define rv.format.j$
  (poke.w (allocate (<< 21 2) 4)
    (\andi $a0 $a0 rv.opcode-mask)
    (\andi $a1 $a1 rv.reg-mask)
    (\slli $a1 $a1 7) ; rd
    ; split imm into 4 fields
    ; (& imm (<< (bit-mask 8) 12))
    (\li   $t0 (bit-mask 8))
    (\slli $t0 $t0 12)
    (\and  $t0 $a2 $t0)
    ; (<< (& (>> imm 11) 1) 20)
    (\srli $t1 $a2 11)
    (\andi $t1 $t1 1)
    (\slli $t1 $t1 20)
    ; (<< (& (>> imm 1) (bit-mask 10)) 21)
    (\srli $t2 $a2 1)
    (\andi $t2 $t2 (bit-mask 10))
    (\slli $t2 $t2 21)
    ; (<< (& (>> imm 20) 1) 31)
    (\srli $t3 $a2 20)
    (\andi $t3 $t3 1)
    (\slli $t3 $t3 31)
    (\or   $a0 $a0 $a1)
    (\or   $a0 $a0 $t0)
    (\or   $a0 $a0 $t1)
    (\or   $a0 $a0 $t2)
    (\or   $a0 $a0 $t3)
    (\ret)
  ))
(define rv.format.j (quote
  (car (call-native rv.format.j$ 1 opcode rd imm))))

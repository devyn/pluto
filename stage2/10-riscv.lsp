; RISC-V assembler (first pass)
(define rv.opcode-len 7)
(define rv.reg-len 5)
(define rv.funct3-len 3)
(define rv.funct7-len 7)
(define rv.opcode-mask (bit-mask rv.opcode-len))
(define rv.reg-mask (bit-mask rv.reg-len))
(define rv.funct3-mask (bit-mask rv.funct3-len))
(define rv.funct7-mask (bit-mask rv.funct7-len))

; RISC-V instruction formats
; These can be optimized later with native implementations using the assembler we're building
(define rv.format.r (quote 
  (left-fold | (& opcode rv.opcode-mask)
    (list
      (<< (& rd rv.reg-mask) 7)
      (<< (& funct3 rv.funct3-mask) 12)
      (<< (& rs1 rv.reg-mask) 15)
      (<< (& rs2 rv.reg-mask) 20)
      (<< (& funct7 rv.funct7-mask) 25)))))
(define rv.instr.r
  (fn (opcode funct3 funct7)
    (fn (rd rs1 rs2)
      (unquote rv.format.r))))

(define rv.format.i (quote
  (left-fold | (& opcode rv.opcode-mask)
    (list
      (<< (& rd rv.reg-mask) 7)
      (<< (& funct3 rv.funct3-mask) 12)
      (<< (& rs1 rv.reg-mask) 15)
      (<< (& imm (bit-mask 12)) 20)))))
(define rv.instr.i
  (fn (opcode funct3)
    (fn (rd rs1 imm)
      (unquote rv.format.i))))

(define rv.format.s (quote
  (left-fold | (& opcode rv.opcode-mask)
    (list
      (<< (& imm (bit-mask 5)) 7)
      (<< (& funct3 rv.funct3-mask) 12)
      (<< (& rs1 rv.reg-mask) 15)
      (<< (& rs2 rv.reg-mask) 20)
      (<< (& (>> imm 5) (bit-mask 7)) 25)))))
(define rv.instr.s
  (fn (opcode funct3)
    (fn (rs2 rs1 imm)
      (unquote rv.format.s))))

(define rv.format.b (quote 
  (left-fold | (& opcode rv.opcode-mask)
    (list
      (<< (& (>> imm 11) 1) 7)
      (<< (& (>> imm 1) (bit-mask 4)) 8)
      (<< (& funct3 rv.funct3-mask) 12)
      (<< (& rs1 rv.reg-mask) 15)
      (<< (& rs2 rv.reg-mask) 20)
      (<< (& (>> imm 5) (bit-mask 6)) 25)
      (<< (& (>> imm 12) 1) 31)))))
(define rv.instr.b
  (fn (opcode funct3)
    (fn (rs1 rs2 imm)
      (unquote rv.format.b))))

(define rv.format.u (quote
  (| (& opcode rv.opcode-mask)
    (| (<< (& rd rv.reg-mask) 7)
      (+ ; add one if 11th bit is set
        (& imm (<< (bit-mask 20) 12))
        (<< (& imm 0x800) 1))))))
(define rv.instr.u
  (fn (opcode)
    (fn (rd imm)
      (unquote rv.format.u))))

(define rv.format.j (quote
  (left-fold | (& opcode rv.opcode-mask)
    (list
      (<< (& rd rv.reg-mask) 7)
      (& imm (<< (bit-mask 8) 12))         ; inst[19:12] = imm[19:12]
      (<< (& (>> imm 11) 1) 20)            ; inst[20]    = imm[11]
      (<< (& (>> imm 1) (bit-mask 10)) 21) ; inst[30:21] = imm[10:1]
      (<< (& (>> imm 20) 1) 31)))))        ; inst[31]    = imm[20]
(define rv.instr.j
  (fn (opcode)
    (fn (rd imm)
      (unquote rv.format.j))))

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
(define \li    (fn (reg value)  (\addi  reg $zero value)))
(define \mv    (fn (dest src)   (\addi  dest src 0)))
(define \j     (fn (offset)     (\jal   $zero offset)))
(define \jr    (fn (reg offset) (\jalr  $zero reg offset)))
(define \callr (fn (reg offset) (\jalr  $ra reg offset)))
(define \ret   (fn ()           (\jalr  $zero $ra 0)))
(define \beqz  (fn (reg offset) (\beq   reg $zero offset)))
(define \bnez  (fn (reg offset) (\bne   reg $zero offset)))
(define \bltz  (fn (reg offset) (\blt   reg $zero offset)))
(define \bgez  (fn (reg offset) (\bge   reg $zero offset)))


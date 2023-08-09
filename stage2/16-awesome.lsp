; try a simple assembler program
(define awesome.str$ (ref "Awesome string!"))
(define awesome$ (car (link
  (start
    ; initialize counter, stack
    (\addi  $sp $sp -0x10)
    (\sd    $ra $sp 0x00)
    (\sd    $s0 $sp 0x08)
    (\li    $s0 5)
  )
  (loop
    ; load address of awesome.str$ to t0
    (\auipc $t0 (rel awesome.str$))
    (\addi  $t0 $t0 (+ (rel awesome.str$) 4))
    ; load string buf to a0
    (\ld    $a0 $t0 0x08)
    ; load string len to a1
    (\ld    $a1 $t0 0x10)
    ; load address of put-buf and call it
    (\auipc $t0 (rel  put-buf$))
    (\callr $t0 (rel+ put-buf$))
    ; print newline
    (\li    $a0 10)
    (\auipc $t0 (rel  putc$))
    (\callr $t0 (rel+ putc$))
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

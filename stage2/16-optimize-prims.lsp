; create some more optimized primitives with the linker
(define eval-list (box-procedure (car (link
  (start
    ; stash locals, set up variables
    (\addi  $sp $sp -0x30)
    (\sd    $ra $sp 0x00)
    (\sd    $s1 $sp 0x08)
    (\sd    $s2 $sp 0x10)
    (\sd    $a1 $sp 0x18) ; locals
    (\sd    $a0 $sp 0x20) ; args / head
    (\sd    $zero $sp 0x28) ; tail
    (\li    $s1 0) ; return value (dest)
    (\li    $s2 0) ; current node of dest to append to
  )
  (setup
    ; evaluate args first
    ; arg 0 - locals (to be used)
    (\ld    $a0 $sp 0x18)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    (\mv    $a1 $a0)
    (\addi  $a0 $sp 0x20)
    (\auipc $ra (rel  eval-head$))
    (\callr $ra (rel+ eval-head$))
    (\bnez  $a0 (rel  ret))
    ; swap provided locals into position
    (\ld    $t0 $sp 0x20) ; new locals
    (\ld    $a1 $sp 0x18) ; old locals (use one more time)
    (\sd    $t0 $sp 0x18) ; save new as locals
    ; shuffle arg list back
    (\ld    $t0 $sp 0x28)
    (\sd    $t0 $sp 0x20)
    (\sd    $zero $sp 0x28)
    ; arg 1 - list to evaluate
    (\addi  $a0 $sp 0x20)
    (\auipc $ra (rel  eval-head$))
    (\callr $ra (rel+ eval-head$))
    (\bnez  $a0 (rel  ret))
    ; release rest of args
    (\ld    $a0 $sp 0x28)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
  )
  (loop
    ; check if next is nil
    (\ld    $t0 $sp 0x20)
    (\beqz  $t0 (rel  done))
    ; acquire locals
    (\ld    $a0 $sp 0x18)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    (\mv    $a1 $a0)
    ; set address of head/tail
    (\addi  $a0 $sp 0x20)
    ; call eval-head$
    (\auipc $ra (rel  eval-head$))
    (\callr $ra (rel+ eval-head$))
    ; handle error
    (\bnez  $a0 (rel  ret))
    ; move tail back to args position
    (\ld    $a0 $sp 0x20)
    (\ld    $t0 $sp 0x28)
    (\sd    $t0 $sp 0x20)
    (\sd    $zero $sp 0x28)
    ; make cons with nil
    (\li    $a1 0)
    (\auipc $ra (rel  cons$))
    (\callr $ra (rel+ cons$))
    ; handle error
    (\beqz  $a0 (rel  nomem))
    ; handle first node specially
    (\beqz  $s1 (rel  first))
    ; set cons into current node
    (\sd    $a0 $s2 0x10) ; tail
    (\mv    $s2 $a0) ; advance
    (\j     (rel loop))
  )
  (first
    ; first node = set to s1 and s2
    (\mv    $s1 $a0)
    (\mv    $s2 $a0)
    (\j     (rel loop))
  )
  (done
    ; ok
    (\li    $a0 0)
    ; take result from s1
    (\mv    $a1 $s1)
    (\mv    $s1 $zero)
  )
  (ret
    (\addi  $sp $sp -0x10)
    (\sd    $a0 $sp 0x00)
    (\sd    $a1 $sp 0x08)
    ; free locals
    (\ld    $a0 $sp 0x28)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    ; free args/head (never need to free tail)
    (\ld    $a0 $sp 0x30)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    ; free s1
    (\mv    $a0 $s1)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    ; restore and return
    (\ld    $a0 $sp 0x00)
    (\ld    $a1 $sp 0x08)
    (\ld    $ra $sp 0x10)
    (\ld    $s1 $sp 0x18)
    (\ld    $s2 $sp 0x20)
    (\addi  $sp $sp 0x40)
    (\ret)
  )
  (nomem
    (\li    $a0 -4) ; EVAL_EXCEPTION_NO_FREE_MEM
    (\li    $a1 0)
    (\j     (rel ret))
  )
))))


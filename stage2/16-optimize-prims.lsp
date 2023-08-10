; create some more optimized primitives with the linker
(define cons (box-procedure (car (link
  (start
    ; reserve stack, preserve return addr
    (\addi  $sp $sp -0x20)
    (\sd    $ra $sp 0x00)
    (\sd    $s1 $sp 0x08)
    (\sd    $a1 $sp 0x10) ; locals
    (\sd    $zero $sp 0x18) ; cons head
    (\mv    $s1 $zero) ; args list
    ; get first arg
    (\auipc $ra (rel  uncons$))
    (\callr $ra (rel+ uncons$))
    (\beqz  $a0 (rel  exc))
    ; store rest of args, stash head for now
    (\mv    $s1 $a2)
    (\sd    $a1 $sp 0x18)
    ; acquire locals
    (\ld    $a0 $sp 0x10)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    ; unstash and eval
    (\mv    $a1 $a0)
    (\ld    $a0 $sp 0x18)
    (\sd    $zero $sp 0x18)
    (\auipc $ra (rel  eval$))
    (\callr $ra (rel+ eval$))
    ; handle err
    (\bnez  $a0 (rel  end))
    ; store result
    (\sd    $a1 $sp 0x18)
    ; get second arg
    (\mv    $a0 $s1)
    (\mv    $s1 $zero)
    (\auipc $ra (rel  uncons$))
    (\callr $ra (rel+ uncons$))
    (\beqz  $a0 (rel  exc))
    ; store rest of args (will release on ret)
    (\mv    $s1 $a2)
    ; eval second arg, give up locals
    (\mv    $a0 $a1)
    (\ld    $a1 $sp 0x10)
    (\sd    $zero $sp 0x10)
    (\auipc $ra (rel  eval$))
    (\callr $ra (rel+ eval$))
    ; handle err
    (\bnez  $a0 (rel  end))
    ; do cons (tail already in a1)
    (\ld    $a0 $sp 0x18)
    (\sd    $zero $sp 0x18)
    (\auipc $ra (rel  cons$))
    (\callr $ra (rel+ cons$))
    (\beqz  $a0 (rel  no-mem))
    ; move cons to a1 (result), set a0 to ok
    (\mv    $a1 $a0)
    (\li    $a0 0)
    ; done
    (\j     (rel end))
  )
  (no-mem
    (\li    $a0 -4) ; no free mem
    (\li    $a1 0)
    (\j     (rel end))
  )
  (exc
    (\li    $a0 -1) ; exception
    (\li    $a1 0)
  )
  (end
    ; stash return value
    (\addi  $sp $sp -0x10)
    (\sd    $a0 $sp 0x00)
    (\sd    $a1 $sp 0x08)
    ; release s1 arg list
    (\mv    $a0 $s1)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; release locals
    (\ld    $a0 $sp 0x20)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; release cons head
    (\ld    $a0 $sp 0x28)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; load stashed data and return
    (\ld    $a0 $sp 0x00)
    (\ld    $a1 $sp 0x08)
    (\ld    $ra $sp 0x10)
    (\ld    $s1 $sp 0x18)
    (\addi  $sp $sp 0x30)
    (\ret)
  )
))))

; define (error), returns exception
; we don't evaluate the args in the asm because it's easy to do that with eval-list
(define error: (box-procedure (car (link
  (start
    ; preserve a0
    (\addi  $sp $sp -0x10)
    (\sd    $ra $sp 0x00)
    (\sd    $a0 $sp 0x08)
    ; free locals (a1)
    (\mv    $a0 $a1)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; set a0 = EVAL_ERROR_EXCEPTION (-1)
    (\li    $a0 -1)
    ; load a1 = args
    (\ld    $a1 $sp 0x08)
  )
  (end
    (\ld    $ra $sp 0x00)
    (\addi  $sp $sp 0x10)
    (\ret)
  )
))))
(define error (proc args scope
  (eval scope
    (cons error:
      (eval-list scope args)))))

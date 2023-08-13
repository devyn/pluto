; create some more optimized primitives with the linker
; length could be a lot faster and is pretty simple
(define length$ (car (link
  (start
    ; set up counter
    (\addi  $sp $sp -0x10)
    (\sd    $ra $sp 0x00)
    (\sd    $s1 $sp 0x08)
    (\li    $s1 0)
  )
  (loop
    ; do cdr in a loop
    (\beqz  $a0 (rel  end))
    (\auipc $ra (rel  cdr$))
    (\callr $ra (rel+ cdr$))
    (\addi  $s1 $s1 1)
    (\j     (rel loop))
  )
  (end
    (\mv    $a0 $s1)
    (\ld    $ra $sp 0x00)
    (\ld    $s1 $sp 0x08)
    (\addi  $sp $sp 0x10)
    (\ret)
  )
)))
(define length (fn (list)
  (car (call-native length$ 1 (ref list)))))

; this is very commonly used and this version is a lot faster
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
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; free args/head (never need to free tail)
    (\ld    $a0 $sp 0x30)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; free s1
    (\mv    $a0 $s1)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
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
    (\li    $a0 -4) ; EVAL_ERROR_NO_FREE_MEM
    (\li    $a1 0)
    (\j     (rel ret))
  )
))))

; replace math
(define binary-op$ (car (link
  ; unbox first arg into s1
  ; args list on stack for eval-head
  (start
    (\addi  $sp $sp -0x48)
    (\sd    $ra $sp 0x00)
    (\sd    $s1 $sp 0x08)
    (\sd    $a1 $sp 0x10) ; locals
    (\sd    $a0 $sp 0x20) ; args
    (\sd    $zero $sp 0x28)
    (\sd    $zero $sp 0x30) ; first flag
    ; load address from data
    (\mv    $a0 $a2)
    (\auipc $ra (rel  unbox-integer$))
    (\callr $ra (rel+ unbox-integer$))
    (\beqz  $a0 (rel  exc))
    (\beqz  $a1 (rel  exc))
    (\sd    $a1 $sp 0x18) ; routine
  )
  (loop
    ; eval arg
    (\ld    $a0 $sp 0x10)
    (\auipc $ra (rel  acquire-object$))
    (\callr $ra (rel+ acquire-object$))
    (\mv    $a1 $a0)
    (\addi  $a0 $sp 0x20)
    (\auipc $ra (rel  eval-head$))
    (\callr $ra (rel+ eval-head$))
    (\bnez  $a0 (rel  ret)) ; err
    ; shuffle and unbox
    (\ld    $a0 $sp 0x20)
    (\ld    $t0 $sp 0x28)
    (\sd    $t0 $sp 0x20)
    (\sd    $zero $sp 0x28)
    (\auipc $ra (rel  unbox-integer$))
    (\callr $ra (rel+ unbox-integer$))
    ; check if first
    (\ld    $t0 $sp 0x30)
    (\beqz  $t0 (rel first))
    ; call routine with a0, a1
    (\ld    $ra $sp 0x18)
    (\mv    $a0 $s1)
    (\callr $ra 0)
    (\mv    $s1 $a0)
    ; check if end
    (\ld    $t0 $sp 0x20)
    (\beqz  $t0 (rel end))
    (\j     (rel loop))
  )
  (first
    ; move arg in
    (\mv    $s1 $a1)
    (\li    $t0 1)
    (\sd    $t0 $sp 0x30) ; set first flag
    (\j     (rel loop))
  )
  (end
    ; box the result
    (\mv    $a0 $s1)
    (\auipc $ra (rel  box-integer$))
    (\callr $ra (rel+ box-integer$))
    (\beqz  $a0 (rel  nomem))
    (\mv    $a1 $a0)
    (\li    $a0 0)
  )
  (ret
    ; stash result
    (\sd    $a0 $sp 0x38)
    (\sd    $a1 $sp 0x40)
    ; release locals
    (\ld    $a0 $sp 0x10)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; release head
    (\ld    $a0 $sp 0x20)
    (\auipc $ra (rel  release-object$))
    (\callr $ra (rel+ release-object$))
    ; restore saved
    (\ld    $ra $sp 0x00)
    (\ld    $s1 $sp 0x08)
    (\ld    $a0 $sp 0x38)
    (\ld    $a1 $sp 0x40)
    (\addi  $sp $sp 0x48)
    (\ret)
  )
  (nomem
    (\li    $a0 -4) ; EVAL_ERROR_NO_FREE_MEM
    (\li    $a1 0)
    (\j     (rel ret))
  )
  (exc
    (\li    $a0 -1) ; EVAL_ERROR_EXCEPTION
    (\li    $a1 0)
    (\j     (rel ret))
  )
)))

(define +  (box-procedure binary-op$ +$))
(define -  (box-procedure binary-op$ -$))
(define << (box-procedure binary-op$ <<$))
(define >> (box-procedure binary-op$ >>$))
(define &  (box-procedure binary-op$ &$))
(define |  (box-procedure binary-op$ |$))
(define ^  (box-procedure binary-op$ ^$))


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

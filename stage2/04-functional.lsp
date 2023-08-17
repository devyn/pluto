; (fn (arg0 arg1) expression)
; allows you to much more nicely define a function - just provide arg list
; and destructuring will happen automatically
(define fn (proc def-args def-scope
  (eval ()
    (concat (quote (proc args scope))
      (cons
        (list eval
          (list concat
            (list assoc
              (list quote (car def-args))
              (quote (eval-list scope args)))
            (list quote def-scope))
          (list quote (cadr def-args))) ())))))

; functional left fold
(define left-fold (fn (f val list)
  (if (nil? list) val
    (left-fold f (f val (car list)) (cdr list)))))

; functional map list
(define map (fn (f list)
  (if (nil? list) ()
    (cons (f (car list)) (map f (cdr list))))))

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

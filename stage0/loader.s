.attribute arch, "rv64im"

.text

.global start
start:
        li t0, 0xcafec0ffee
        j start

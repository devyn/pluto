#!/bin/bash

# Credit: Mark Callaghan, Domas Mituzas
# http://poormansprofiler.org/

# Modified to connect to remote target

if [[ -z "$GDB" ]]; then
  export GDB="${CROSS_COMPILE}gdb"
fi

nsamples=$1
sleeptime=$2
file=$3

[[ -z "$nsamples" ]] && nsamples=1
[[ -z "$sleeptime" ]] && sleeptime=0
[[ -z "$file" ]] && file=stage1.elf

for x in $(seq 1 $nsamples)
  do
    $GDB -ex "file $file" -ex "target remote localhost:1234" -ex "set pagination 0" -ex "thread apply all bt" -batch
    sleep $sleeptime
  done | \
awk '
  BEGIN { s = ""; } 
  /^Thread/ { print s; s = ""; } 
  /^#/ { if (s != "" ) { s = s "," $4} else { s = $4 } } 
  END { print s }' | \
sort | uniq -c | sort -r -n -k 1,1

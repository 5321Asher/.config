#!/bin/zsh
# ask.sh '<request json>' [outfile] : ask the bench shell a question like theme/prompt does
B=${0:A:h}
d=$(mktemp -d $XDG_RUNTIME_DIR/nrask.XXXXXX); mkfifo $d/reply; print -r -- "$1" > $d/request.json
out=$B/${2:-answer}; rm -f $out; ( timeout 60 cat $d/reply > $out; echo "[done]" >> $out ) &
$B/shell.sh ipc prompt ask $d

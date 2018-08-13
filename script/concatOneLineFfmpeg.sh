#!/bin/zsh
out=_spl_join.mp3
for f in $(=ls org*spli*.wav -rt)
do
    echo $f
done

ffmpeg -f concat -safe 0 -i <(for f in $(=ls org*spli*.wav -rt); do echo "file '$(pwd)/$f'"; done) $out

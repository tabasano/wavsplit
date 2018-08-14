#!/bin/zsh
mp=$1
scrdir=~/git/wavsplit
minute=5
len=$((60*$minute))
scr='ffmpeg -i '$mp
sec=`python mp3sec.py $mp`
count=$(( $sec/60/$minute+1 ))
for i in {1..$count}
do
    wav=org$i.wav
    st=$((i-1))
    st=$((st*len))
    scr=$scr" -ss $st -t $len $wav"
done
echo ${=scr}
sleep 3
${=scr}
wavdir=$(pwd)
cd $scrdir

for i in {1..$count}
do
    wav=org$i.wav
    file=$wavdir/$wav
    echo ruby wav-split.rb -m 150 -j -D 6000 $file
    ruby wav-split.rb -m 150 -j -D 6000 $file
done


#!/bin/zsh
echo make 60min_podcast shorter, for low spec pc

echo -n mk: \"$1\" \(60min mp3\) to wavsplit, ok\?
read
./mk5minx12.sh $1
echo --------
echo -n concat\?
read
./concatOneLineFfmpeg.sh
echo --------
echo -n clear tmpfile\?
read
./clear.sh

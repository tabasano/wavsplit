
# wavsplit

> split wave file by silence, etc. 
  to repeat clear sound of narration


usage:

```
 > ruby wav-split.rb -m 42 -t 3 -j sound.wav
```

split sound.wav to about max 42 parts, repeat 3 times, then join them.


```
 > ruby wav-split.rb -m 42 -j -t 1 -D 6000 sound.wav
```
remove long silence spans, then join them.

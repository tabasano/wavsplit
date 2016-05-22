
# wavsplit

> split wave file by silence, etc. 
  to repeat clear sound of narration


usage:

```
 > ruby wav-split.rb -m 42 -t 3 -j sound.wav
```

split sound.wav to about max 42 parts, repeat them 3 times, then join them.


```
 > ruby wav-split.rb -m 42 -j -t 1 -D 6000 sound.wav
```
remove long silence spans, then join them.


---------------

cf. 
study wave format 

[1](http://wavefilegem.com/how_wave_files_work.html)
[2](http://www.joelstrait.com/blog/2009/10/12/a_digital_audio_primer)
[3](http://www.web-sky.org/program/other/wave.php)

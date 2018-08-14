#!/usr/bin/python
import mutagen
import sys,os

fs=sys.argv[1:]
for file in fs:
    m=mutagen.File(file)
    s=int(m.info.length)
    print s

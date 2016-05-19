#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'wav-file'
require './wav-stream'

module WavFile
end

file=ARGV.shift

f = open(file,"rb")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

puts format

bps= format.bitPerSample
id= format.id

dataChunk.setFormat(format)


def save1bitWav f,format,dataChunk
  wavs = dataChunk.unpackAll
  p [:w,wavs.size]

  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    dsize=wavs.size*format.bitPerSample/8
    WavFile::writeFormat(out, format,[dsize])
    h,l=bitMaxMin(format.bitPerSample).map{|i|i/2}

    c=0
    echoPer=dsize/200
    WavFile::writeChunk(out,"data",dsize){|f,pos|
      wavs.each{|v|
        v= v>0 ? h : l
        f << dataChunk.pack(v)
        c+=1
        print"," if c%echoPer==0
      }
    }
  }
  print"..\n" if $DEBUG
  puts
end

file="out.wav"
save1bitWav file,format,dataChunk
puts "This virtual 1bit Wav file made now may be harmful for speakers or earphones."
puts "Before playing it, set volume down."

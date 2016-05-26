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

def save1bitWav2soft f,format,dataChunk,stepmax=false
  wavs = dataChunk.unpackAll
  p [:w,wavs.size]
  p wavs.max,wavs.min,wavs[0..20],wavs[-20..-1]

  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    dsize=wavs.size*format.bitPerSample/8
    WavFile::writeFormat(out, format,[dsize])
    h,l=bitMaxMin(format.bitPerSample).map{|i|i/2}
    stepmax=h*0.03 if ! stepmax
    bigw=(format.bytePerSec/(format.bitPerSample/8))/100.0
    echoPer=dsize/200
    i=0
    last=wavs[0]
      while i<wavs.size-1
        v=last
        c=0
        while i+c<wavs.size-1
          c+=1
          break if not (wavs[i+c]==last)
        end
        last=wavs[i+c]
        v=v*((c+200)/(bigw+200)) if c<bigw
        step=v/(c/2.0)
        step=(step>0 ? stepmax : -stepmax) if step.abs>stepmax
          c.times{|u|
            val=(u<c/2 ? u*step : (c-u)*step)
            wavs[i+u]=val
            print",",val,"/",wavs[i+u],"[#{i},#{u}]" if (i+u)%echoPer==0
          }
        i+=c
      end
    puts"/"
    p wavs.max,wavs.min,wavs[0..20],wavs[-20..-1]
    c=0
    WavFile::writeChunk(out,"data",dsize){|f,pos|
      wavs.each{|v|
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
save1bitWav2soft file,format,dataChunk

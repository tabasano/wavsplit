#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'wav-file'
require './wav-stream'


file=ARGV.shift
highv=ARGV.shift
stepmaxper=ARGV.shift
highv=highv.to_i if highv
stepmaxper=stepmaxper.to_f if stepmaxper
p [file,highv,stepmaxper]

f = open(file,"rb")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

puts format

bps= format.bitPerSample
id= format.id

dataChunk.setFormat(format)

class HighF < Array
  def initialize s=false
    @size=(s ? s: 4000)
    @ar=[]
    @count=0
    @replimit=@size*2
  end
  def adjust n=0
    if n>@size/3
      @ar.shift(@ar.size-n)
    elsif @ar.size>@size
      @ar.shift(@ar.size-@size)
    end
  end
  def << d
    @ar<<d
    self.adjust
  end
  def add ar
    @ar+=ar
    self.adjust(ar.size)
    @count=0
  end
  def down
    @count+=1
    return if @count%40>0
  end
  def get n
    @count+=1
    if @count>@replimit
      print ":replim"
      @ar=[] 
      @count=0
    end
    @ar[n%(1+@ar.size)]||0
  end
end
def save1bitWav2soft f,format,dataChunk,stepmax=false,highv=50
  wavs = dataChunk.unpackAll
  (puts"this is not 1bit wav file.";exit) if wavs.uniq.size>2
  highv||=50
  nwavs=[]
  p [:w,wavs.size]
  #p wavs.max,wavs.min,wavs[0..20],wavs[-20..-1]

  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    dsize=wavs.size*format.bitPerSample/8
    WavFile::writeFormat(out, format,[dsize])
    h,l=bitMaxMin(format.bitPerSample).map{|i|i/2}
    stepmax=0.03 if ! stepmax
    stepmax=h*stepmax
    admax=stepmax*0.3
    bigw=(format.bytePerSec/(format.bitPerSample/8))/400.0
    echoPer=dsize/200
    x=0
    highFreqBuf=HighF.new(1000)
    WavFile::writeChunk(out,"data",dsize){|f,pos|
      i=0
      while i<wavs.size-1
        v= wavs[i]
        c=0
        while i+c<wavs.size-1
          c+=1
          break if not (wavs[i+c]==v)
        end
        v=v*((c+highv)/(bigw+highv)) if c<bigw
        step=v/(c/2.0)
        step=(step>0 ? stepmax : -stepmax) if c<bigw*5.5 && step.abs>stepmax
        vmax=step*(c/2.0)
        cstep=0.0
        val=0
        c.times{|u|
          if c>2
            val=Math.sin(cstep).abs*vmax
          elsif c==2
            val=vmax*u
          else
            val=vmax
          end
          if c>1000
            tmp=wavs[highFreqBuf.get(i+u)]||0
            val+=tmp #(tmp>0 ? admax : -admax) 
          end
          f << dataChunk.pack(val)
          cstep+=Math::PI/c
          print",",val if (i+u)%echoPer==0
        }
        if c<100
          highFreqBuf.add([*i..(i+c)])
        end
        i+=c
      end
    }
  }
  print"..\n" if $DEBUG
  puts
end

file="out.wav"
save1bitWav2soft file,format,dataChunk,stepmaxper,highv

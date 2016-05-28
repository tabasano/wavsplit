#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'wav-file'


module WavFile

  class Buffer
    attr_accessor :buffer
    def initialize(limit=1000)
      @buffer=[]
    end
    def << d
      @buffer<<d
    end
    def [] n
      @buffer[n]
    end
    def shift n
      @buffer.shift(n)
    end
    def size
      @buffer.size
    end
  end
  class FBufferLR
    attr_accessor :bufferSizeLimit,:bufferL,:bufferR
    def initialize(f,limit=1000)
      @out=f
      @bufferL=Buffer.new
      @bufferR=Buffer.new
      @bufferSizeLimit=limit
      @size=0
    end
    def write d
      @out.write(d)
      @size+=d.size
    end
    def writeLR s=false
      s=[@bufferL.size,@bufferR.size].max if ! s
      blank=".."
      s.times{|i|
        @out.write(@bufferL[i]||blank)
        @size+=1
        @out.write(@bufferR[i]||blank)
        @size+=1
      }
      @bufferL.shift(s)
      @bufferR.shift(s)
    end
    def << d
      l,r=d
      @bufferL<<l if l
      @bufferR<<r if r
      usize=[@bufferL.size,@bufferR.size].min
      if usize>@bufferSizeLimit
        self.writeLR(usize)
      end
    end
    def flash
      self << []
    end
    def flashAll
      self.writeLR
    end
    def finalize
      self.flashAll
      @size
    end
  end
end

include WavFile

r=[*1..1000].map{|i|"R#{i}"}
l=[*1..1000].map{|i|"L#{i}"}
fi="test.txt"
f=open(fi,"wb")
lr=FBufferLR.new(f,5)
lr.bufferL << l.shift
lr.bufferR << r.shift
lr.bufferR << r.shift
lr.bufferR << r.shift
lr.bufferR << r.shift
lr.flash
lr << ["L_","R_"]
lr.bufferL << l.shift
lr << ["L/","R/"]
lr.bufferL << l.shift
lr.bufferL << l.shift
lr.bufferL << l.shift
lr.bufferL << l.shift
lr.bufferL << l.shift
100.times{
  if rand(10)>5
    lr.bufferL << l.shift
  elsif rand(10)>5
    lr.bufferR << r.shift
  else
    lr << ["L/","R/"]
  end
}
lr.finalize
f.close
data=open(fi,"rb"){|f|f.read}
lr=data.scan(/[LR][0-9]+|[LR][_\/]|\.\./)
l,r=[],[]
(lr.size/2).times{|i|
  l<<lr.shift
  r<<lr.shift
}
p data,l,r
#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'wav-file'


module WavFile

  class FBufferLR
    attr_accessor :bufferSizeLimit
    def initialize(f,limit=1000)
      @out=f
      @bufferL=[]
      @bufferR=[]
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
    def addL d
      @bufferL<<d
    end
    def addR d
      @bufferR<<d
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
lr.addL l.shift
lr.addR r.shift
lr.addR r.shift
lr.addR r.shift
lr.addR r.shift
lr.flash
lr << ["L_","R_"]
lr.addL l.shift
lr << ["L/","R/"]
lr.addL l.shift
lr.addL l.shift
lr.addL l.shift
lr.addL l.shift
lr.addL l.shift
100.times{
  if rand(10)>5
    lr.addL l.shift
  elsif rand(10)>5
    lr.addR r.shift
  else
    lr << ["L/","R/"]
  end
}
lr.finalize
f.close
p open(fi,"rb"){|f|f.read}

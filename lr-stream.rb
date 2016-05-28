#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require "tempfile"
require 'wav-file'


module WavFile

  class Buffer
    attr_accessor :buffer
    def initialize(step=2)
      @buffer=Tempfile.new("buffer")
      @buffer.binmode
      @size=0
      @step=step
    end
    def << d
      @buffer<<d
    end
    def [] n
      @buffer.seek(@step*n)
      @buffer.read(@step)
    end
    def put pos,d
      @buffer.seek(@step*pos)
      @buffer.write(d)
    end
    def close!
      @path=@buffer.path
      @buffer.close!
      p [:close_buffer,@path,FileTest.exist?(@path) ? :extist : :not_exist]
    end
    def reopen
      @buffer.close
      @buffer.open
      @size=@buffer.size/@step
    end
    def size
      @size
    end
  end
  class FBufferLR
    attr_accessor :bufferSizeLimit,:bufferL,:bufferR
    def initialize(f)
      @out=f
      @bufferL=Buffer.new
      @bufferR=Buffer.new
      @blank=".."
      @size=0
    end
    def write d
      @out.write(d)
      @size+=d.size
    end
    def << d
      l,r=d
      @bufferL<<l if l
      @bufferR<<r if r
    end
    def seekWriteR d,n
      @bufferR.reopen
      @bufferR.put n,d
    end
    def seekWriteL d,n
      @bufferL.reopen
      @bufferL.put n,d
    end
    def finalize
      @bufferL.reopen
      @bufferR.reopen
      open(@out,"wb"){|f|
        [@bufferL.size,@bufferR.size].max.times{|i|
          f.write @bufferL[i]||@blank
          f.write @bufferR[i]||@blank
        }
      }
      @size=@bufferL.size*2
      @bufferL.close!
      @bufferR.close!
      @size
    end
  end
end

include WavFile

r=[*0..100].map{|i|"R#{i.chr}"}*10
l=[*0..100].map{|i|"L#{i.chr}"}*10
fi="test.txt"
f=open(fi,"wb")
lr=FBufferLR.new(f)
lr.bufferL << l.shift
lr.bufferR << r.shift
lr.bufferR << r.shift
lr.bufferR << r.shift
lr.bufferR << r.shift
lr << ["LX","RX"]
lr.bufferL << l.shift
lr << ["LY","RY"]
lr << ["LZ","RZ"]
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
lr.seekWriteR"RS",4
lr.seekWriteR"RS",8
lr.seekWriteL"LS",2
lr.seekWriteR"Rs",5
lr.finalize
f.close
data=open(fi,"rb"){|f|f.read}
lr=data.scan(/../m)
l,r=[],[]
(lr.size/2).times{|i|
  l<<lr.shift
  r<<lr.shift
}
p :raw_data,data
puts
p :left,l
puts
p :right,r

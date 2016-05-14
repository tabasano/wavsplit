#!/usr/bin/ruby
# -*- coding: utf-8 -*-

# sample cf.
# http://www-mmsp.ece.mcgill.ca/documents/audioformats/wave/Samples.html

require 'rubygems'
require 'wav-file'
require './wav-stream'

file=ARGV.shift
rate=ARGV.shift.to_f
(puts "please set volume rate over 0.";exit) if rate==0

f = open(file,"rb")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

puts format

bps= format.bitPerSample
id= format.id

dataChunk.setFormat(format)
wavs = dataChunk.unpackAll
wavs=wavs.map{|v|dataChunk.boost(v,rate)}.flatten


def save f,format,dataChunk
  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    WavFile::write(out, format, [dataChunk].flatten)
  }
  print"..\n" if $DEBUG
end
p [:w,wavs.size]

dataChunk.data=wavs.join
p dataChunk.data.class,dataChunk.data[0..3]
file="out.wav"
save file,format,dataChunk

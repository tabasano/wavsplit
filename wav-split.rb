#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'kconv'
require 'optparse'

require 'rubygems'
require 'wav-file'

max=1000
reptime=1
sflag=true
outdir=false
opt = OptionParser.new
opt.on('-x',"dont save") {|v| sflag=false }
opt.on('-m v',"max") {|v| max=v.to_i }
opt.on('-d v',"out dir") {|v| outdir=v }
opt.on('-j',"out-join mode") {|v| $join=true }
opt.on('-t v',"repeat time") {|v| reptime=v.to_i }
opt.parse!(ARGV)


# cf. shokai.org/blog/archives/5408

# pick up series of level low points of wave stream
# then sort them by length of silence
def checklevel wavs,silent=20,start=0,thr=100
  start||=0
  thr||=100
  puts "size: #{wavs.size}"
  max,min=wavs.max,wavs.min
  puts"max: #{max}"
  puts"min: #{min}"
  p [silent,start,thr]

  spl=[]
  pos=0
  count=0
  fl=false
  curfl=false
  added=false
  minimum=6
  tmp=0
  co=[]
  wavs.each{|i|
    (pos+=1;next) if pos<start
    level=i.ord
    print "#{format"%04d",pos}: #{"*"*(level.abs*20/max)}       \r" if $DEBUG
    # ちいさい
    curfl=(level<silent && level>-silent)
    # ちいさくて直前がおおきい
    fl=curfl
    if ! curfl
      # ちいさくなくて直前まで小さいのの連続ならばcoに入れる
      co<<count if count>minimum
      count=0
    end
    if fl
      count+=1
    end
    pos+=1
  }
  co.sort
end

def show wavs,silent=20,start=0,thr=100
  start||=0
  thr||=100
  puts "size: #{wavs.size}"
  max,min=wavs.max,wavs.min
  puts"max: #{max}"
  puts"min: #{min}"
  p [silent,start,thr]


  spl=[]
  pos=0
  count=0
  fl=false
  curfl=false
  added=false
  tmp=0
  wavs.each{|i|
    (pos+=1;next) if pos<start
    level=i.ord
    print "#{format"%04d",pos}: #{"*"*(level.abs*20/max)}       \r" if $DEBUG
    curfl=level<silent && level>-silent
    (count=0;curfl=false;added=false) if not curfl
    if curfl
      count+=1
      (spl<<pos;added=true) if count>thr && ! added
    end
    pos+=1
  }
  spl
end

file,st=ARGV
def f2data file
p [file]
  f = open(file,"rb")
  format = WavFile::readFormat(f)
  dataChunk = WavFile::readDataChunk(f)
  f.close

  puts format

  bit = 's*' if format.bitPerSample == 16 # int16_t
  bit = 'C*' if format.bitPerSample == 8 # signed char
  wavs = dataChunk.data.unpack(bit) # read binary #.force_encoding( 'ASCII-8BIT' )
  [dataChunk,wavs,bit,format]
end

dataChunk,wavs,bit,format=f2data(file)
chime="myIntervalTone-short.wav"
chwav=f2data(chime)[1]

co=checklevel(wavs,200,st)
p :co,co.size,:co_sort,co[-200..-1] if $DEBUG

thr=100
if co.size>max
  thr=co[-max]-1
end
spl=show(wavs,200,st,thr)

p spl.size
p spl if $DEBUG
play=[0]
base=1000
(spl.size-1).times{|i|
  play<<spl[i+1] if spl[i+1]-play[-1] > base
}


def save f,format,dataChunk
  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    WavFile::write(out, format, [dataChunk])
  }
  print"..\n" if $DEBUG
end
p [:size, spl.size, play.size,($join ? :join : :not_join)]
spl=play
p :save_start

form="%0#{spl.size>100 ? 4 : 3}d"
wavtmp=[]
pkd=""
(spl.size-1).times{|i|
  st,en=spl[i],spl[i+1]
  wavtmp=[]
  pkd="" if ! $join
  wpkd=wavs[st..en].pack(bit)
  cpkd=chwav.pack(bit)
  reptime.times{|i|
    pkd+=wpkd
    pkd+=cpkd if i<reptime-1
  }
  print (en-st)/1000,","
  num=format(form,i)
  name="#{file}_split-#{num}.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  if sflag && ! $join
    dataChunk.data = pkd
    save name,format,dataChunk
  end
}
if sflag && $join
  name="#{file}_split-join.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  dataChunk.data = pkd
  save name,format,dataChunk
end


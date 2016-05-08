#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'kconv'
require 'optparse'

require 'rubygems'
require 'wav-file'


extra=6
max=1000
reptime=1
sflag=true
outdir=false
opt = OptionParser.new
opt.on('-x',"dont save") {|v| sflag=false }
opt.on('-e v',"extra num to omit too short spans") {|v| extra=v.to_i }
opt.on('-m v',"max") {|v| max=v.to_i }
opt.on('-d v',"out dir") {|v| outdir=v }
opt.on('-j',"out-join mode") {|v| $join=true }
opt.on('-t v',"repeat time") {|v| reptime=v.to_i }
opt.on('-s',"show raw mode") {|v| $showraw=true }
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
  # Array of set [silence-length, position]
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
      co<<[count,pos] if count>minimum
      count=0
    end
    if fl
      count+=1
    end
    pos+=1
  }
  co.sort_by{|c,pos|c}
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

copos=checklevel(wavs,200,st)
p :co,copos.size,:co_sort,copos[-200..-1] if $DEBUG

n=copos.size
if copos.size>max+extra
  n=max+extra
end
# sort by count => sort by position
spl=copos[-n..-1].map{|c,pos|pos}.sort

p [:copos,copos.size,:spl,spl.size]
p spl if $DEBUG
# [position,step from previous]
play=[[0,0]]
base=1000
(spl.size-1).times{|i|
  step=spl[i+1]-play[-1][0]
  play<<[spl[i+1],step] if step > base
}
rest=wavs.size-play[-1][0]
play<<[wavs.size,rest] if play[-1][0]!=wavs.size

# reject too short spans
minus=play.sort_by{|po,st|st}[0..extra]
p [:extra,extra],minus
minus=minus.map{|po,st|po}-[0,wavs.size]
play.reject!{|po,st|minus.member?(po)}
p [:max,play[-1],play[-2],"...",play[1],play[0]]

def save f,format,dataChunk
  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    WavFile::write(out, format, [dataChunk])
  }
  print"..\n" if $DEBUG
end
p [:size, spl.size, play.size,($join ? :join : :not_join)]
tmp=play.map{|pos,step|step}
spzero,spmin,splast,spmax=tmp[0],tmp[1],tmp[-2],tmp[-1]
p [:span_minmax,spmin,spmax,spzero,splast]
spl=play.map{|pos,step|pos/2*2}
p :save_start

form="%0#{spl.size>100 ? 4 : 3}d"
wavtmp=[]
pkd=""
log=[]
log<<[:wav,wavs.size]
pksize=0
unit=1000
unit=1 if $showraw
(spl.size-1).times{|i|
  st,en=spl[i],spl[i+1]
  wavtmp=[]
  tmpsize=0
  pkd="" if ! $join
  wpkd=(tmp=wavs[st...en];tmpsize=tmp.size;pksize+=tmpsize;tmp).pack(bit)
  cpkd=chwav.pack(bit)
  reptime.times{|i|
    pkd+=wpkd
    pkd+=cpkd if i<reptime-1
  }
  print tmpsize/unit,","
  num=format(form,i)
  name="#{file}_split-#{num}.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  if sflag && ! $join
    dataChunk.data = pkd
    save name,format,dataChunk
  end
}
log<<[:pksize,pksize]
if sflag && $join
  name="#{file}_split-join.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  dataChunk.data = pkd
  save name,format,dataChunk
end
p log

#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'kconv'
require 'optparse'

require 'rubygems'
require 'wav-file'

dropShortNum=6
extra=9
max=1000
minimumSilent=3000
limitrate=1.3
reptime=1
sflag=true
outdir=false
tlog=[]

opt = OptionParser.new
opt.on('-x',"dont save") {|v| sflag=false }
opt.on('-e v',"extra num to omit too short spans") {|v| extra=v.to_i }
opt.on('-E v',"dropShort num to omit too short spans") {|v| dropShortNum=v.to_i }
opt.on('-m v',"max") {|v| max=v.to_i }
opt.on('-d v',"out dir") {|v| outdir=v }
opt.on('-r v',"limit rate") {|v| limitrate=v.to_f }
opt.on('-j',"out-join mode") {|v| $join=true }
opt.on('-t v',"repeat time") {|v| reptime=v.to_i }
opt.on('-s',"show raw mode") {|v| $showraw=true }
opt.on('-S',"minimum silence length(#{minimumSilent})") {|v| minimumSilent=v.to_i }
opt.parse!(ARGV)


def midpercent first,last,mid
  span=last-first
  mid.map{|i|(i-first)*100/span}
end
class Array
  def tshow
    last=self[0][1]
    self.each{|c,t|
      p [c,last-t]
      last=t
    }
  end
  def midval a,b,num=1
    num=num.to_i
    m=self.select{|c,pos|pos>a && pos<b}
p [:msize,m.size,:n,num]
    if m.size>num*2
      csel=num*2+(m.size-num*2)*0.4
      r=m.sort_by{|c,pos|c}[-csel.to_i..-1]
      r=r.map{|c,pos|pos}.sort
      per=midpercent(a,b,r)
      res=[]
      lastnum=0
      min,max,minstep=15,85,100/num/5
p [:csize,r.size,:n,num,:minstep,minstep]
      r.size.times{|i|
        if per[i]>min && per[i]<max
          if res.size==0 || per[i]-per[lastnum]>minstep
            res<<r[i]
            lastnum=i
            print :o,per[i]
          else
            print :s,per[i]
          end
        else
          print :x,per[i]
        end
      }
      res=r if res.size<num
      res[0..num]
    elsif m.size>num
      r=m.sort_by{|c,pos|c}[-num..-1]
      r.map{|c,pos|pos}.sort
    else
      m.map{|c,pos|pos}.sort
    end
  end
  #diff values
  def steps
    r=[]
    (self.size-1).times{|i|
      r<<self[i+1]-self[i]
    }
    r
  end
  def prebig i
    (self[i]-self[i-2]).abs>(self[i+1]-self[i-1]).abs
  end
  def dropBySpanShortOne n=1
    t=self
    sp=[]
    (t.size-1).times{|i|
      sp<<t[i+1]-t[i]
    }
    min=sp.min
    val=:skip
    sp.each_with_index{|e,i|
      if min==e
        p [t[i],t[i+1],t[i+2],:diff,t[i+1]-t[i]] if $DEBUG
        #last value
        if i==sp.size-1
          t[i]=val
        # merge to shorter; preceding or succeeding
        elsif i<2
          t[i+1]=val
        elsif t.prebig(i+1)
          t[i+1]=val
        else
          t[i]=val
        end
        break
      end
    }
    t-[val]
  end
  def dropBySpanShort n=1
    n.times{
      self.replace(self.dropBySpanShortOne)
    }
    self
  end
end

# cf. shokai.org/blog/archives/5408

# pick up series of level low points of wave stream
# then sort them by length of silence
def checklevel wavs,silent=20,start=0,minimumSilent=1000
  start||=0
  minimumSilent||=1000
  sectionTopSilent=minimumSilent/2
  puts "size: #{wavs.size}"
  max,min=wavs.max,wavs.min
  puts"max: #{max}"
  puts"min: #{min}"
  p [silent,start,minimumSilent]

  spl=[]
  pos=0
  count=0
  fl=false
  curfl=false
  added=false
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
      rewind=count>minimumSilent*2 ? minimumSilent : sectionTopSilent
      co<<[count,pos-rewind] if count>minimumSilent
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
tlog<<[:f2data,Time.now]
dataChunk,wavs,bit,format=f2data(file)
chime="myIntervalTone-short.wav"
chwav=f2data(chime)[1]
tlog<<[:checklevel,Time.now]

copos=checklevel(wavs,200,st,minimumSilent)
p :co,copos.size,:co_sort,copos[-200..-1] if $DEBUG

n=copos.size
if copos.size>max+extra+dropShortNum
  n=max+extra+dropShortNum
end
# sort by count => sort by position
spl=copos[-n..-1].map{|c,pos|pos}.sort
copos=copos.sort_by{|c,pos|pos}
plus=[]
limit=wavs.size/max*limitrate
last=0
tlog<<[:midval_start,Time.now]

spl.each{|i|
  if i-last>limit
    n=(i-last)/limit+1
    m=copos.midval(last,i,n)
p [last,i,:mid,midpercent(last,i,m)]
    plus<<m
  end
  last=i
}
p [:limit,limit,plus]
plus.flatten!
dropShortNum+=plus.size
spl+=plus
spl.sort!

tlog<<[:basecheck,Time.now]

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

tlog<<[:minus,Time.now]
# reject too short silence by length order
minus=play.sort_by{|po,step|step}[0..extra]
p [:extra,extra],minus
minus=minus.map{|po,st|po}-[0,wavs.size]
play.reject!{|po,st|minus.member?(po)}
p [:max,play[-1],play[-2],"...",play[1],play[0]]
p [:pla]+play.map{|i,st|i}.steps.map{|i|i/1000}+[:size,play.size]

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

# drop too short spans
tlog<<[:dropShort,Time.now]
spl=play.map{|pos,step|pos/2*2}.dropBySpanShort(dropShortNum)
p [:spl]+spl.steps.map{|i|i/1000}+[:size,spl.size]

tlog<<[:zip,Time.now]
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
tlog<<[:end,Time.now]
p log
tlog.tshow

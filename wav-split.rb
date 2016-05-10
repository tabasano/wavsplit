#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'kconv'
require 'optparse'

require 'rubygems'
require 'wav-file'
# cf. shokai.org/blog/archives/5408

module WavFile
  class BlankChunk < WavFile::Chunk
    def initialize(name)
      @name = name[0...4]
      @data = ""
      @size = @data.size
    end
  end
end

def cmtChunk name,cmt=""
  exChunk=WavFile::BlankChunk.new(name)
#unpackしないとエラーが出る。sizeがおかしくなる？
#  exChunk.data=cmt.toutf8.unpack("C*").pack("C*")
  exChunk.data=cmt.toutf8.force_encoding("ASCII-8BIT")
  exChunk
end

# wav file for interval tone
chime="myIntervalTone-short.wav"
chunkname="note"
mycmt=[]
mycmt<<[chunkname,"test desu."]

dropShortNum=7
extra=9
max=1000
threshold=200
eachLength=8000
minimumSilent=3400
lenForCheck=minimumSilent*20
limitrate=1.3
reptime=1
sflag=true
outdir=false
tlog=[]
minimumUseLongSilentNum=false
mkcheckfile=false
zerosize=false
dropSilence=false
pre=false
$silent=true
showspent=false

opt = OptionParser.new
opt.on('-c',"make check file mode") {|v| mkcheckfile=true }
opt.on('-C v',"each length for make check file mode(#{lenForCheck})") {|v| lenForCheck=v.to_i }
opt.on('-D v',"drop silence minimum length") {|v| dropSilence=v.to_i }
opt.on('-x',"dont save") {|v| sflag=false }
opt.on('-X v',"comment chunk test [(note:)sentence]") {|v|
  name=chunkname
  v=~/:/
  if $&
    name,v=$`,$'
  end
  mycmt<<[name,v]
}
opt.on('-z v',"insert zero sound before each part; set length") {|v| zerosize=v.to_i }
opt.on('-e v',"extra num to omit too short spans") {|v| extra=v.to_i }
opt.on('-E v',"dropShort num to omit too short spans") {|v| dropShortNum=v.to_i }
opt.on('-m v',"split num") {|v| max=v.to_i }
opt.on('-b v',"minimum num of longSilence use") {|v| minimumUseLongSilentNum=v.to_i }
opt.on('-B v',"(bell tone) interval wav file name") {|v| chime=v }
opt.on('-d v',"out dir") {|v| outdir=v }
opt.on('-r v',"limit rate") {|v| limitrate=v.to_f }
opt.on('-j',"out-join mode") {|v| $join=true }
opt.on('-t v',"repeat time") {|v| reptime=v.to_i }
opt.on('-T v',"threshold value(#{threshold})") {|v| threshold=v.to_i }
opt.on('-l v',"each length minimum (#{eachLength})") {|v| eachLength=v.to_i }
opt.on('-s',"show raw mode") {|v| $showraw=true }
opt.on('-S',"minimum silence length(#{minimumSilent})") {|v| minimumSilent=v.to_i }
opt.on('-p',"only print wav format") {|v| pre=true }
opt.on('-P v',"print log;[1,2]") {|v|
  showspent=true
  $silent=false if v.to_i>1
}
opt.parse!(ARGV)


minimumUseLongSilentNum||=max/2
file,st=ARGV

def midpercent first,last,mid
  span=last-first
  mid.map{|i|(i-first)*100/span}
end
def lshow *d
  return if $silent
  print *d
end
def lp *d
  return if $silent
  p d
end
class Array
  def fadeOut
    s=self.size
    c=0
    trsize=s/3
    self[0...(s-trsize)]+self[(s-trsize)..-1].map{|i|tmp=i*((100-c.to_f/trsize*100)/100);c+=1;tmp}
  end
  def fadeIn
    self.reverse.fadeOut.reverse
  end
  def timeshow
    last=self.first[1]
    self.each{|c,t|
      p [c,format("%.3f",t-last)]
      last=t
    }
    p [:total,format("%.3f",self.last[1]-self.first[1])]
  end
  def midval a,b,num=1
    num=num.to_i
    m=self.select{|c,pos|pos>a && pos<b}
    lshow [:msize,m.size,:n,num]
    if m.size>num*2
      csel=num*2+(m.size-num*2)*0.2
      r=m.sort_by{|c,pos|c}[-csel.to_i..-1]
      r=r.map{|c,pos|pos}.sort
      per=midpercent(a,b,r)
      res=[]
      lastnum=0
      min,max,minstep=15,85,100/num/5
      lp [:csize,r.size,:n,num,:minstep,minstep]
      r.size.times{|i|
        if per[i]>min && per[i]<max
          if res.size==0 || per[i]-per[lastnum]>minstep
            res<<r[i]
            lastnum=i
            lshow :o,per[i]
          else
            lshow :s,per[i]
          end
        else
          lshow :x,per[i]
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
  def dropTailByLevel v,len
    s=self.size
    n=0
    s.times{|i|
      level=self[-i-1]
      curfl=(level<v && level>-v)
      break if ! curfl
      n=i
    }
    if len>n
      self
    else
      lshow "#{n}! "
      self[0..-n-1]
    end
  end
  def dropBySpanShortOne
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
def wavAbs v,bps
  if bps==8
    (v-0x80).abs
  else
    v.abs
  end
end
def riffle level,silent,bps
  if bps==8
    level=level-0x80
  end
  level.abs<silent
end

# pick up series of level low points of wave stream
# then sort them by length of silence

# silent: threshold
# minimumSilent: duration of silence

def checklevel wavs,bps,silent=20,start=0,minimumSilent=1000,drop=false
  start||=0
  minimumSilent||=1000
  sectionTopSilent=minimumSilent/2
  lp "size: #{wavs.size}"
  max,min=wavs.max,wavs.min
  lp "max: #{max}"
  lp "min: #{min}"
  lp [silent,start,minimumSilent]

  spl=[]
  pos=0
  count=0
  curfl=false
  added=false
  rewind=0
  tmp=0
  # Array of set [silence length, position]
  co=[]
  wavs.each{|i|
    (pos+=1;next) if pos<start
    level=i.ord
    print "#{format"%04d",pos}: #{"*"*(wavAbs(level,bps)*20/max)}       \r" if $DEBUG
    # ちいさい
    curfl=(bps==8 ? (level-0x80).abs<silent : level.abs<silent)
    # ちいさくて直前がおおきい
    if ! curfl
      # ちいさくなくて直前まで小さいのの連続ならばcoに入れる
      if ! drop
        rewind=count>minimumSilent*2 ? minimumSilent : sectionTopSilent
      end
      co<<[count,pos-rewind] if count>minimumSilent
      count=0
    else
      count+=1
    end
    pos+=1
  }
  co.sort_by{|c,pos|c}
end


def f2data file,silent=false
  lp [file]
  f = open(file,"rb")
  format = WavFile::readFormat(f)
  dataChunk = WavFile::readDataChunk(f)
  f.close
  if not silent
    lp format
  end

  bit = 's*' if format.bitPerSample == 16 # int16_t
  bit = 'C*' if format.bitPerSample == 8
  wavs = dataChunk.data.unpack(bit) # read binary
  [wavs,bit,format.bitPerSample,format,dataChunk]
end
def trwav wav,bps,tbps
  if not wav
    false
  elsif tbps==bps
    wav
  elsif bps==8 && tbps==16
    wav.map{|i|(i-0x80)*0x100}
  elsif bps==16 && tbps==8
    wav.map{|i|i/0x100+0x80}
  else
    p [bps,tbps]
    raise
  end
end

tlog<<[:start,Time.now]
wavs,bit,bps,format,dataChunk=f2data(file)
chimewav,cbit,cbps,cformat,cdataChunk=File.exist?(chime) ? f2data(chime) : false
if cbps!=bps
  chimewav=trwav(chimewav,cbps,bps)
end
cpkd=chimewav ? chimewav.pack(bit) : ""
tlog<<[:wav2data,Time.now]
exit if pre

copos=checklevel(wavs,bps,threshold,st,minimumSilent,dropSilence)
lp [:longSilentCheck,copos.size,minimumUseLongSilentNum]
longSilentPos=copos[-minimumUseLongSilentNum..-1].map{|c,pos|pos}
p :co,copos.size,:co_sort,copos[-200..-1] if $DEBUG

n=copos.size
if copos.size>max+extra+dropShortNum
  n=max+extra+dropShortNum
end
# sort by count => select => sort by position
spl=copos[-n..-1].map{|c,pos|pos}.sort
copos=copos.sort_by{|c,pos|pos}
plus=[]
limit=wavs.size/max*limitrate
last=0
tlog<<[:checkSplitPoint,Time.now]

spl.each{|i|
  if i-last>limit
    n=(i-last)/limit+1
    m=copos.midval(last,i,n)
    lp [last,i,:mid,midpercent(last,i,m)]
    plus<<m
  end
  last=i
}
tlog<<[:insertMidValueIntoTooLongSpan,Time.now]

lp [:limit,limit,plus]
plus.flatten!
dropShortNum+=plus.size
spl+=plus
spl.sort!


lp [:copos,copos.size,:spl,spl.size]
p spl if $DEBUG
# [position,step from previous]
play=[[0,0]]
(spl.size-1).times{|i|
  step=spl[i+1]-play[-1][0]
  play<<[spl[i+1],step] if step > eachLength
}
rest=wavs.size-play[-1][0]
play<<[wavs.size,rest] if play[-1][0]!=wavs.size

tlog<<[:basecheck,Time.now]

# reject too short silence by length order
minus=play.sort_by{|po,step|step}[0..extra]
lp [:extra,extra,minus]
minus=minus.map{|po,st|po}-[0,wavs.size]
play.reject!{|po,st|minus.member?(po)}
lp [:max,play[-1],play[-2],"...",play[1],play[0]]
lp [:pla]+play.map{|i,st|i}.steps.map{|i|i/1000}+[:size,play.size]

def save f,format,dataChunk
  print"save!" if $DEBUG
  open(f, "wb"){|out|
   # f.binmode
    WavFile::write(out, format, [dataChunk].flatten)
  }
  print"..\n" if $DEBUG
end
lp [:size, spl.size, play.size,($join ? :join : :not_join)]
tmp=play.map{|pos,step|step}
spzero,spmin,splast,spmax=tmp[0],tmp[1],tmp[-2],tmp[-1]
lp [:span_minmax,spmin,spmax,spzero,splast]
tlog<<[:minus,Time.now]

# drop too short spans
spl=play.map{|pos,step|pos}.dropBySpanShort(dropShortNum)+longSilentPos
spl=spl.sort.uniq.map{|i|i/2*2}
lp [:spl]+spl.steps.map{|i|i/1000}+[:size,spl.size]
tlog<<[:dropShort,Time.now]

form="%0#{spl.size>100 ? 4 : 3}d"
wavtmp=[]
pkd=[]
log=[]
log<<[:wav,wavs.size]
pksize=0
zpkd=""
zpkd=([0]*zerosize).pack(bit) if zerosize
unit=1000
unit=1 if $showraw
(spl.size-1).times{|i|
  st,en=spl[i],spl[i+1]
  wavtmp=[]
  pkd=[] if ! $join
  if mkcheckfile
    tmp=en-st>lenForCheck*2 ? wavs[st...st+lenForCheck].fadeOut+wavs[en-lenForCheck...en].fadeIn : wavs[st...en]
  else
    tmp=wavs[st...en]
  end
  if dropSilence
    tmp=tmp.dropTailByLevel(threshold,dropSilence)
  end
  wpkd=tmp.pack(bit)
  pksize+=tmp.size
  reptime.times{|i|
    pkd<<zpkd if zerosize
    pkd<<wpkd
    pkd<<cpkd if i<reptime-1
  }
  lshow tmp.size/unit,","
  num=format(form,i)
  name="#{file}_split-#{num}.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  if sflag && ! $join
    dataChunk.data = pkd.join
    save name,format,dataChunk
  end
}
log<<[:pksize,pksize]
if sflag && $join
  name="#{file}_split-join.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  dataChunk.data = pkd.join
  ex=mycmt.map{|t,v|cmtChunk(t,v)}
  save name,format,[dataChunk,ex]
end
tlog<<[:zip,Time.now]

lp log
tlog.timeshow if showspent || ! $silent

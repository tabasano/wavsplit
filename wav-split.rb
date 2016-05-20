#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'pp'
require 'kconv'
require 'optparse'

require 'rubygems'
require 'wav-file'
# cf. shokai.org/blog/archives/5408

require './wav-stream'

module WavFile
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
mycmtChunk=[]
#mycmt<<[chunkname,"test desu."]

dropShortNum=7
extra=9
max=1000
thresholdPercent=0.611
eachLength=8000
minimumSilentMSec=18
lenForCheckSec=2.0
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
useOrg=true

opt = OptionParser.new
opt.on('-b v',"minimum num of longSilence use") {|v| minimumUseLongSilentNum=v.to_i }
opt.on('-B v',"(bell tone) interval wav file name") {|v| chime=v }
opt.on('-c',"make check file mode") {|v| mkcheckfile=true }
opt.on('-C v',"sec. for each sample in making split-point-check file mode(default: #{lenForCheckSec} sec.)") {|v| lenForCheck=v.to_f }
opt.on('-d v',"out dir") {|v| outdir=v }
opt.on('-D v',"drop silence minimum length") {|v| dropSilence=v.to_i }
opt.on('-e v',"extra num to omit too short spans") {|v| extra=v.to_i }
opt.on('-E v',"dropShort num to omit too short spans") {|v| dropShortNum=v.to_i }
opt.on('-j',"out-join mode") {|v| $join=true }
opt.on('-l v',"each length minimum (#{eachLength})") {|v| eachLength=v.to_i }
opt.on('-m v',"split num") {|v| max=v.to_i }
opt.on('-n v',"add note chunk [sentence]") {|v|
  mycmtChunk<<[chunkname,v]
}
opt.on('-p',"only print wav format") {|v| pre=true }
opt.on('-P v',"print log;[1,2]") {|v|
  case v.to_i
  when 0
    showspent=false
    $silent=true
  when 1
    showspent=true
    $silent=true
  else
    $silent=false
  end
}
opt.on('-r v',"limit rate") {|v| limitrate=v.to_f }
opt.on('-s',"show raw mode") {|v| $showraw=true }
opt.on('-S v',"minimum silence msec.(#{minimumSilentMSec})") {|v| minimumSilentMSec=v.to_i }
opt.on('-t v',"repeat time") {|v| reptime=v.to_i }
opt.on('-T v',"threshold percent(#{thresholdPercent}%)") {|v| thresholdPercent=v.to_f }
opt.on('-U',"don't use unpacked if possible") {|v| useOrg=false }
opt.on('-x',"don't save") {|v| sflag=false }
opt.on('-z v',"insert zero sound before each part; set length") {|v| zerosize=v.to_i }
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
      p [c,t-last]
      last=t
    }
    p [:total,self.last[1]-self.first[1]]
  end
  #select some points between a and b, situated moderately sparsely
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
  def dropTailPosByLevel v,len
    s=self.size
    n=0
    s.times{|i|
      level=self[-i-1]
      curfl=(level<v && level>-v)
      break if ! curfl
      n=i
    }
    if len>n
      s
    else
      lshow "#{n}! "
      (s-1-n)/2*2
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
def zeroby bps
  bps==8 ? 0x80 : 0
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

def checkspan max,silent,bps
  r=true
  co=0
  while r
    break if co>max
    i=yield(co)
    level=i.ord
    if bps==8
      r=((level-0x80).abs<silent)
    else
      r=(level.abs<silent)
    end
    co+=1
  end
  return r,co
end
# pick up series of level low points of wave stream
# then sort them by length of silence

# silent: threshold
# minimumSilent: duration of silence sample length

def checklevel dataChunk,bps,format,silent=20,start=0,minimumSilent=1000,drop=false
  start||=0
  minimumSilent||=1000
  sectionTopSilent=minimumSilent/2
  samplesize=dataChunk.data.size/(format.bitPerSample/8)
  lp "size: #{samplesize}"
  lp [:threshold,silent,:start,start]
  steplong=format.bytePerSec/(format.bitPerSample/8)/80+1
  stepshort=format.bytePerSec/(format.bitPerSample/8)/240+1
  # check at first current data then from far to near data in checklist, fibonacci-like
  checklist=(n=0.7;[*0..15].map{|i|n=n*1.46+1;n.round}.reverse).unshift(0,1)
  checkmax=checklist.max
  checknumMin=3
  lp [:fiblikelist,checklist]

  spl=[]
  pos=0
  count=0
  curfl=false
  added=false
  rewind=0
  tmp=0
  # Array of set [silence length, position]
  co=[]
  checked=0
  num=0
  skipNumFast=stepshort+rand(4)
  skipNumSlow=steplong+rand(4)
  skipNum=skipNumSlow
  lp [:skipNum,skipNumFast,skipNumSlow]
  pos=start if pos<start
  pluslog=Hash.new(0)
  while pos<samplesize-checkmax
    clist=checklist.select{|i|i<skipNum/3+1}
    # silent or not
    curfl,n=checkspan(clist.size-1,silent,bps){|plus| dataChunk.dataAt(pos+clist[plus]).first }
    checked+=n
    pluslog[n]+=1
    if ! curfl
      # add to position list if current is over silent threshold and preceding series of data is not.
      if count>minimumSilent
        rewind=count>minimumSilent*2 ? minimumSilent : sectionTopSilent
        rewind=skipNum if drop
        co<<[count,pos-rewind]
        skipNum=skipNumFast+rand(2)
      end
      count=0
    else
      skipNum=skipNumSlow
      count+=skipNumSlow
    end
    pos+=skipNum
#    checked+=1
  end
  lp [:plusCaseLevel,pluslog.keys.sort.map{|k|"#{k}=>#{pluslog[k]}"}]
  lp [:checked_data,format("%.4f%",checked.to_f*100/(samplesize-start)),checked]
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

  st=Time.now
    dataChunk.setFormat(format)
    wavs = dataChunk.unpackAll
  p [:_unpack,Time.now-st] if ! $silent
  [wavs,dataChunk.bit,format.bitPerSample,format,dataChunk]
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
mx=WavFile.bitMaxR(bps)
mx=1 if format.id==3 # ?; float
threshold=mx*thresholdPercent/100
lp [:thr,thresholdPercent,bps,WavFile.bitMaxR(bps),threshold]
tlog<<[:wav2data,Time.now]
chimewav,cbit,cbps,cformat,cdataChunk=File.exist?(chime) ? f2data(chime) : false
cpkd=""
if chimewav
  if cbps!=bps
    chimewav=trwav(chimewav,cbps,bps)
    cpkd=chimewav.pack(bit)
  else
    cpkd=cdataChunk.data
  end
end
tlog<<[:chWav2data,Time.now]
exit if pre

minimumSilent=format.bytePerSec/1000*minimumSilentMSec
lenForCheck=lenForCheckSec*(format.bytePerSec/(format.bitPerSample/8))
lp [:silentMSec,minimumSilentMSec,:silentSampleNum,minimumSilent,:bytePerSec,format.bytePerSec]
copos=checklevel(dataChunk,bps,format,threshold,st,minimumSilent,dropSilence)
lp [:longSilentCheck,copos.size,minimumUseLongSilentNum]
minimumUseLongSilentNum=copos.size/2 if minimumUseLongSilentNum>copos.size-1
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

# reject too short block by length order
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
def cdpos pos,bps
  pos*(bps/8)
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
zpkd=([zeroby(bps)]*zerosize).pack(bit) if zerosize
unit=1000
unit=1 if $showraw
bc=WavFile::BlankChunk.new("data")
(spl.size-1).times{|i|
  st,en=spl[i],spl[i+1]
  wavtmp=[]
  pkd=[] if ! $join
  if mkcheckfile
    useOrg=false
    tmp=en-st>lenForCheck*2 ? wavs[st...st+lenForCheck].fadeOut+wavs[en-lenForCheck...en].fadeIn : wavs[st...en]
  else
    tmp=wavs[st...en]
  end
  if dropSilence
    en=st+tmp.dropTailPosByLevel(threshold,dropSilence)
    tmp=wavs[st...en]
  end
  if useOrg
    wpkd=dataChunk.data[cdpos(st,bps)...cdpos(en,bps)]
  else
    wpkd=tmp.pack(bit)
  end
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
    bc.data = pkd.join
lshow [:one,bc.size,num]
    save name,format,bc
  end
}
log<<[:pksize,pksize]
if sflag && $join
  name="#{file}_split-join.wav"
  name="#{outdir}/#{File.basename(name)}" if outdir
  bc.data = pkd.join
  ex=mycmtChunk.map{|t,v|cmtChunk(t,v)}
  save name,format,[bc,ex]
end
tlog<<[:zip,Time.now]

lp log
tlog.timeshow if showspent || ! $silent

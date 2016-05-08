require 'rubygems'
require 'wav-file'

# cf. shokai.org/blog/archives/5408
def show wavs,silent=20,thr=100
  puts wavs.size
  max,min=wavs.max,wavs.min
  puts"max: #{max}"
  puts"min: #{min}"


  spl=[]
  p=0
  count=0
  fl=false
  curfl=false
  added=false
  tmp=0
  co=[]
  wavs.each{|i|
    level=i.ord
    print "#{format"%04d",p}: #{"*"*(level.abs*20/max)}       \r" if $DEBUG
    fl=true if level<silent && level>-silent && ! fl
    curfl=level<silent && level>-silent
    (co<<count if count>1;count=0;fl=false;added=false) if not curfl
    if fl && curfl
      count+=1
      (spl<<p;added=true) if count>thr && ! added
    end
    p+=1
  }
  [spl,co]
end

file,st,dump=ARGV
f = open(file)
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
f.close

puts format

bit = 's*' if format.bitPerSample == 16 # int16_t
bit = 'c*' if format.bitPerSample == 8 # signed char
wavs = dataChunk.data.unpack(bit) # read binary

spl,co=show(wavs,200,8)
p spl
play=[0]
base=1000
(spl.size-1).times{|i|
  play<<spl[i+1] if spl[i+1]-play[-1] > base
}
p play
spl=play

def save f,format,dataChunk
  print"save!"
  open(f, "wb"){|out|
   # f.binmode
    WavFile::write(out, format, [dataChunk])
  }
  print"..\n"
end
bai=12
stock=[]
(spl.size-1).times{|i|
  st,en=spl[i],spl[i+1]
  wavtmp=wavs[st..en]
  stock<<wavtmp
  wavtmp*=bai
  dataChunk.data = wavtmp.pack(bit)
  name="split-#{i}.wav"
  save name,format,dataChunk
}

wavtmp=[]
(stock.size*3).times{
  wavtmp+=stock[rand(stock.size)]*(rand(3)+1)
}
dataChunk.data = wavtmp.pack(bit)
save"split-rand.wav",format,dataChunk

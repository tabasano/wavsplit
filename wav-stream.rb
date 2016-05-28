#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'wav-file'

def calcDiff ar
  h=Hash.new(0)
  ar.each{|i|
    h[i]+=1
  }
  s=Hash.new(0)
  last=false
  c=0
  h.keys.sort.each{|k|
    #puts "#{k}: #{h[k]}"
    if last
      s[k-last]+=1
    end
    last=k
    c+=1
    print"," if c%1000==0
  }
  p [:diff_count,s.keys.sort.map{|k|"#{k}=>#{s[k]}"}]
  return h,s
end

def wave_format_info id
#cf. https://www.videolan.org/developers/vlc/doc/doxygen/html/vlc__codecs_8h.html
d=%Q(
#define 	WAVE_FORMAT_UNKNOWN   0x0000 /* Microsoft Corporation */
#define 	WAVE_FORMAT_PCM   0x0001 /* Microsoft Corporation */
#define 	WAVE_FORMAT_ADPCM   0x0002 /* Microsoft Corporation */
#define 	WAVE_FORMAT_IEEE_FLOAT   0x0003 /* Microsoft Corporation */
#define 	WAVE_FORMAT_ALAW   0x0006 /* Microsoft Corporation */
#define 	WAVE_FORMAT_MULAW   0x0007 /* Microsoft Corporation */
#define 	WAVE_FORMAT_DTS_MS   0x0008 /* Microsoft Corporation */
#define 	WAVE_FORMAT_WMAS   0x000a /* WMA 9 Speech */
#define 	WAVE_FORMAT_IMA_ADPCM   0x0011 /* Intel Corporation */
#define 	WAVE_FORMAT_YAMAHA_ADPCM   0x0020 /* Yamaha */
#define 	WAVE_FORMAT_TRUESPEECH   0x0022 /* TrueSpeech */
#define 	WAVE_FORMAT_GSM610   0x0031 /* Microsoft Corporation */
#define 	WAVE_FORMAT_MSNAUDIO   0x0032 /* Microsoft Corporation */
#define 	WAVE_FORMAT_AMR_NB_2   0x0038 /* AMR NB rogue */
#define 	WAVE_FORMAT_MSG723   0x0042 /* Microsoft G.723 [G723.1] */
#define 	WAVE_FORMAT_G726   0x0045 /* ITU-T standard */
#define 	WAVE_FORMAT_MPEG   0x0050 /* Microsoft Corporation */
#define 	WAVE_FORMAT_MPEGLAYER3   0x0055 /* ISO/MPEG Layer3 Format Tag */
#define 	WAVE_FORMAT_AMR_NB   0x0057 /* AMR NB */
#define 	WAVE_FORMAT_AMR_WB   0x0058 /* AMR Wideband */
#define 	WAVE_FORMAT_G726_ADPCM   0x0064 /* G.726 ADPCM */
#define 	WAVE_FORMAT_VOXWARE_RT29   0x0075 /* VoxWare MetaSound */
#define 	WAVE_FORMAT_DOLBY_AC3_SPDIF   0x0092 /* Sonic Foundry */
#define 	WAVE_FORMAT_VIVOG723   0x0111 /* Vivo G.723.1 */
#define 	WAVE_FORMAT_AAC   0x00FF /* */
#define 	WAVE_FORMAT_AAC_MS   0xa106 /* Microsoft AAC */
#define 	WAVE_FORMAT_SIPRO   0x0130 /* Sipro Lab Telecom Inc. */
#define 	WAVE_FORMAT_WMA1   0x0160 /* WMA version 1 */
#define 	WAVE_FORMAT_WMA2   0x0161 /* WMA (v2) 7, 8, 9 Series */
#define 	WAVE_FORMAT_WMAP   0x0162 /* WMA 9 Professional */
#define 	WAVE_FORMAT_WMAL   0x0163 /* WMA 9 Lossless */
#define 	WAVE_FORMAT_CREATIVE_ADPCM   0x0200 /* Creative */
#define 	WAVE_FORMAT_ULEAD_DV_AUDIO_NTSC   0x0215 /* Ulead */
#define 	WAVE_FORMAT_ULEAD_DV_AUDIO_PAL   0x0216 /* Ulead */
#define 	WAVE_FORMAT_ATRAC3   0x0270 /* Atrac3, != from MSDN doc */
#define 	WAVE_FORMAT_SONY_ATRAC3   0x0272 /* Atrac3, != from MSDN doc */
#define 	WAVE_FORMAT_IMC   0x0401
#define 	WAVE_FORMAT_INDEO_AUDIO   0x0402 /* Indeo Audio Coder */
#define 	WAVE_FORMAT_ON2_AVC   0x0500 /* VP7 */
#define 	WAVE_FORMAT_ON2_AVC_2   0x0501 /* VP6 */
#define 	WAVE_FORMAT_AAC_2   0x1601 /* Other AAC */
#define 	WAVE_FORMAT_AAC_LATM   0x1602 /* AAC/LATM */
#define 	WAVE_FORMAT_A52   0x2000 /* a52 */
#define 	WAVE_FORMAT_DTS   0x2001 /* DTS */
#define 	WAVE_FORMAT_AVCODEC_AAC   0x706D
#define 	WAVE_FORMAT_DIVIO_AAC   0x4143 /* Divio's AAC */
#define 	WAVE_FORMAT_GSM_AMR_FIXED   0x7A21 /* Fixed bitrate, no SID */
#define 	WAVE_FORMAT_GSM_AMR   0x7A22 /* Variable bitrate, including SID */
#define 	WAVE_FORMAT_DK3   0x0062
#define 	WAVE_FORMAT_DK4   0x0061
#define 	WAVE_FORMAT_VORBIS   0x566f
#define 	WAVE_FORMAT_VORB_1   0x674f
#define 	WAVE_FORMAT_VORB_2   0x6750
#define 	WAVE_FORMAT_VORB_3   0x6751
#define 	WAVE_FORMAT_VORB_1PLUS   0x676f
#define 	WAVE_FORMAT_VORB_2PLUS   0x6770
#define 	WAVE_FORMAT_VORB_3PLUS   0x6771
#define 	WAVE_FORMAT_G723_1   0xa100
#define 	WAVE_FORMAT_AAC_3   0xa106
#define 	WAVE_FORMAT_SPEEX   0xa109 /* Speex audio */
#define 	WAVE_FORMAT_FLAC   0xf1ac /* Xiph Flac */
#define 	WAVE_FORMAT_EXTENSIBLE   0xFFFE /* Microsoft */
)
  ar=d.split("\n").select{|i|i=~/WAVE_FORMAT/}.map{|i|i=~/(WAVE_FORMAT_[^ ]*) +(0x[^ ]*)/;[$1+$',$2]}
  hs={}
  ar.each{|t,n|hs[n.hex]=t}
  hs[id]
end
#signed int max and min
def bitMaxMin n
  l=2**n
  min=-l/2
  max=-min-1
  return max,min
end
def lcmByBit odd,bit
  a=odd/bit if re==0
  odd.times{|i|
    if ((i+1)*bit)%odd==0
      a=i+1
      break
    end
  }
  [a,bit*a/odd]
end
module WavFile

  class FBuffer
    attr_accessor :bufferSizeLimit
    def initialize(f)
      @out=f
      @buffer=""
      @bufferSizeLimit=1000
      @size=0
    end
    def write d
      @out.write(d)
      @size+=d.size
    end
    def << d
      @buffer<<d
      if @buffer.size>@bufferSizeLimit
        self.write(@buffer)
        @buffer=""
      end
    end
    def finalize
      self.write(@buffer)
      @size
    end
  end

  class BlankChunk < Chunk
    def initialize(name)
      @name = name[0...4]
      @data = ""
      @size = @data.size
    end
  end
  class BlankDataChunk < BlankChunk
    def initialize
      super("data")
    end
    
  end

  class WavFile::Chunk
    attr_accessor :bit
    def dumpv
      p [:bps_si_id_un_pk_bit,@bps, @single, @id, @unpack, @pack,@bit]
    end
    def isFloat
      @id==3
    end
    def setFormat format
      @bps= format.bitPerSample
      @single=@bps/8
      @id= format.id
      @center=0
      @unsigned=(@bps==8)
      @unpack=:unpack0
      @pack=:pack0
      setPackEnv
      #@force=true
      (p "unimplemented bitPerSec(#{@bps})";raise) if @single*8!=@bps && ! @force
    end
    def setPackEnv
      case @bps
      when 16
        @bit = 's*'
      when 8
        @bit = 'C*'
        @center=0x80
        @min=0
        @max=0xff
      when 32
        if self.isFloat
          @bit = 'e*'
        else
          @bit = 'l*' #?
        end
      when 64
        if self.isFloat
          @bit = 'E*'
        else
          @bit = 'q*' #?
        end
      when 24
        @bit = 'l*'
        @unpack=:unpack24
        @pack=:pack24
        @max,@min=bitMaxMin(24)
      when 12
        @bit = 'B*'
        @unpack=:unpack12
        @pack=:pack12
        @max,@min=bitMaxMin(12)
      end
    end
    def unpack24 d
      #d.scan(/.../m).map {|s| (0.chr+s).unpack(@bit)}.flatten
      [*0...d.size/3].map{|i| d.slice(i*3,3)}.map{|s|
        r= (0.chr+s).unpack(@bit)[0]
        r/0x100
      }.flatten
    end
    def unpackByBit d,odd
      # odd(1-15) bit to 16bit
      byte,step=WavFile.lcm odd
      adjust="0"*(16-odd)
      d.scan(/.{#{byte}}/m).map {|s| 
        t=s.unpack('B*')[0].scan(/.{#{odd}}/m).flatten
        t.map{|i|
          [(adjust+i)].pack('B*').unpack('s*')
        }
      }.flatten
    end
    def unpack12 d
      # 12bit to 16bit
      d.scan(/.../m).map {|s| 
        t=s.unpack('B*')[0].scan(/.{12}/m).flatten
        t.map{|i|
          [("0000"+i)].pack('B*').unpack('s*')
        }
      }.flatten
    end
    def unpack0 d
      d.unpack(@bit)
    end
    def pack24 d
      [d*0x100].pack(@bit)[1..-1]
      #[d].pack(@bit)[0..-2]
    end
    def packByBit d,odd
      # 16bit to odd(1-15) bit then pack them. no adjust
      d=[d] if d.class != Array
      s=d.pack('s*').unpack('B*').first
      [s.scan(/.{#{16-odd}}(.{#{odd}})/).flatten.join].pack('B*')
    end
    def pack12 d
      # 16bit to 12bit then pack them
      d=[d] if d.class != Array
      s=d.pack('s*').unpack('B*').first
      [s.scan(/.{4}(.{12})/).flatten.join].pack('B*')
    end
    def pack0 d
      d=[d] if d.class != Array
      d.pack(@bit)
    end
    def pack d
      self.method(@pack).call(d)
    end
    def unpack d
      self.method(@unpack).call(d)
    end
    def dataAt(pos,len=1)
      from=pos*@single
      self.unpack(@data[from,@single*len])
    end
    def unpackAll
      self.unpack(@data)
    end
    def boost d,rate
      d=(@unsigned ? (d-@center)*rate+@center : d*rate)
      d=[[d,@min].max,@max].min if defined? @max
      self.pack(d)
    end
    def boostNoAdjust d,rate
      d=(@unsigned ? (d-@center)*rate+@center : d*rate)
      self.pack(d)
    end
  end
  def WavFile.bitMaxR n,id
    l=2**n
    min=-l/2
    max=-min-1
    max=1.0 if id==3
    return max
  end
  def WavFile.lcm odd
    lcmByBit odd,16
  end
  def WavFile.writeFormat(f, format,chunkDataSizes)
    header_file_size = 4
    chunkDataSizes.each{|c|
      header_file_size += c + 8
    }
    f.write('RIFF' + [header_file_size].pack('V') + 'WAVE')
    f.write("fmt ")
    f.write([format.to_bin.size].pack('V'))
    f.write(format.to_bin)
  end
  def WavFile.rewriteChunkDataSize(f,dsize,csizePos)
    f.seek(csizePos)
    f.write([dsize].pack('V'))
  end
  def WavFile.writeChunk(f,name,dsize)
    f.write(name)
    csizePos=f.pos
    f.write([dsize].pack('V'))
    out=FBuffer.new(f)
    yield out,csizePos
    s=out.finalize
    tpos=f.pos
    if dsize!=s
      f.seek(csizePos,IO::SEEK_SET)
      f.write([s].pack('V'))
      f.seek(tpos,IO::SEEK_SET)
    end
    return s
  end
end

def cmtChunk name,cmt=""
  exChunk=WavFile::BlankChunk.new(name)
#  exChunk.data=cmt.toutf8.unpack("C*").pack("C*")
  exChunk.data=cmt.toutf8.force_encoding("ASCII-8BIT")
  exChunk
end


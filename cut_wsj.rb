def r file
  dat=""
  open(file){|f|
    dat+=f.read
  }
  dat
end
def sec t
  min,sec=t.split(':')
  min.to_i*60+sec.to_i
end

inf,outf,tlength=ARGV
ARGV.shift
ARGV.shift
ARGV.shift
if File.exist?(outf) || tlength !~/:/
  p "bad parameter" if File.exist?(outf)
  p "bad length[mm:ss]" if tlength !~/:/
  puts "ruby #{$0} input output length(mm:ss) 00:00-1:00 2:00-3:00 4:00-20:00"
  exit
end
tlength=sec(tlength)
dat=r(inf)
totalsize=dat.size*1.0
seclength=(totalsize/tlength).to_i
pair=[]
ARGV.each{|i|
  p i
  startp,endp=i.split('-')
  startp=sec(startp)
  endp=sec(endp)
  pair.push([startp,endp])
}
p pair
p seclength
outfp=open(outf,"a")
result=""
pair.each{|sp,ep|
  from=sp*seclength
  to=ep*seclength
  to=-1 if to>totalsize
  outfp.write dat[from...to]
}
p totalsize
p result.size

outfp.close


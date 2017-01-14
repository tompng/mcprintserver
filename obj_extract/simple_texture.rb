require 'chunky_png'
require 'pry'
require 'net/http'
domain = ARGV[0]
html = Net::HTTP.get URI.parse(domain)
csspath = html.match(/[^'"]*all[^'"]*\.css/).to_s
css = Net::HTTP.get URI.parse(domain+csspath)

defs = css.scan(/\.items-\d+-\d+-\d{[^{}]+}/)
blocks = {}
defs.each do |definition|
  /\.items-\d+-(?<id>\d+)-(?<data>\d+){(?<style>.+)}/ =~ definition
  /url\((?<img>.+)\) 0 -?(?<offset>\d+)/ =~ style
  block = {img: img, offset: offset.to_i}
  blocks[[id.to_i,0]]||=block
  blocks[[id.to_i,data.to_i]]=block
end
images = {}
images.define_singleton_method :get do |url|
  self[url] ||= ChunkyPNG::Image.from_string Net::HTTP.get(URI.parse(domain+url))
end

overrides = {
  [[125,0],[126,0],[53],[85],[107]] => [5,0],
  [[125,1],[126,1],[134],[183],[188]] => [5,1],
  [[125,2],[126,2],[135],[184],[189]] => [5,2],
  [[125,3],[126,3],[136],[185],[190]] => [5,3],
  [[125,4],[126,4],[163],[186],[191]] => [5,4],
  [[125,5],[126,5],[164],[187],[192]] => [5,5],
  [[179],[180],[182]] => [179],
  [[201],[202],[203],[204],[205]] => [201],
  [[67],[139,0]] => [4],
  [[108],[44,4]] => [45],
  [[109],[44,5]] => [98],
  [[113],[44,6],[114]] => [112],
  [[109],[44,7],[155],[156]] => [155]
}.each do |keys, dst|
  dstid, dstdata = dst
  dstblock = blocks[[dstid, dstdata||0]]
  keys.each do |id, data|
    if data
      blocks[[id,data]]=dstblock
    else
      16.times{|d|blocks[[id,d]]=dstblock}
    end
  end
end




piximage = ChunkyPNG::Image.new 64, 64
[*0...256].product([*0...16]) do |id, data|
  x = id%16*4+data%4
  y = id/16*4+data/4
  block = blocks[[id,data]]||blocks[[id,0]]
  next unless block
  color=[0,0,0]
  weight=0
  img = images.get(block[:img])
  32.times.to_a.repeated_permutation(2) do |i,j|
    a,b,g,r=img[i,block[:offset]+j].digits(256)
    [r,g,b].each_with_index do |c,i|
      color[i]+=a*(c||0)
    end
    weight+=a
  end
  weight, color = 1, [0x7D,0xB0,0x57] if id==2

  color=color.map{|c|[c/(weight.nonzero?||1),255].min}
  piximage[x,y] = color[0]<<24|color[1]<<16|color[2]<<8|(weight==0?0:0xff)
end

piximage.save 'texture.png'

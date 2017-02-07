require 'chunky_png'
require 'pry'
require 'net/http'
domain = ARGV[0]
html = Net::HTTP.get URI.parse(domain)
csspath = html.match(/[^'"]*all[^'"]*\.css/).to_s
css = Net::HTTP.get URI.parse(domain+csspath)

defs = css.scan(/\.items-\d+-\d+-\d+{[^{}]+}/)
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
  [[125,0],[126,0],[43,2],[53],[85],[107]] => [5,0], # oak
  [[125,1],[126,1],[134],[183],[188]] => [5,1], # spruce
  [[125,2],[126,2],[135],[184],[189]] => [5,2], # birch
  [[125,3],[126,3],[136],[185],[190]] => [5,3], # jungle
  [[125,4],[126,4],[163],[186],[191]] => [5,4], # acacia
  [[125,5],[126,5],[164],[187],[192]] => [5,5], # dark oak
  [[43,0]] =>[44,0], # stone slab
  [[20]] => [102], # glass
  [[24],[128],[43,1],[44,1]] => [24], # sandstone
  [[179],[180],[181],[182]] => [179], # red sandstone
  [[201],[202],[203],[204],[205]] => [201], # purpur
  [[67],[43,3],[97,1],[139,0]] => [4], # cobblestone
  [[108],[43,4],[44,4]] => [45], # bricks
  [[109],[43,5],[44,5],[98,3]] => [98,0], # stone bricks
  [[113],[43,6],[44,6],[114]] => [112], # nether bricks
  [[43,7],[44,7],[155],[156]] => [155] # quarts
}
16.times{|i|overrides[[[95,i]]]=[160,i]} # stained glass
overrides.each do |keys, dst|
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
  weight, color = 1, [0x55,0x77,0x33] if id==2

  color=color.map{|c|[c/(weight.nonzero?||1),255].min}
  piximage[x,y] = color[0]<<24|color[1]<<16|color[2]<<8|(weight==0?0:0xff)
end

piximage.save 'texture.png'

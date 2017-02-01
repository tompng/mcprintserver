require 'json'
require 'pry'
require './mc_world/world'
require 'chunky_png'

def gen_void
  (-2..2).to_a.repeated_permutation(2) do |x, z|
    next if x.zero? && z.zero?
    world = MCWorld::World.new x: x, z: z
    32.times.to_a.repeated_permutation(2){|ix,iz|world[ix*16, iz*16, 0] = nil}
    File.write "spigot/world/region/r.#{x}.#{z}.mca", world.encode
  end
end

def noise n, scale
  arr = n.times.map{n.times.map{rand}}
  oneway = ->line{
    a,b,c=0,0,0
    p=Math.exp -1.fdiv(scale)
    line.each do |l|
      a=a*p+l
      b=b*p*p+l
      c=c*p*p*p+l
    end
    a/=1-p**line.size
    b/=1-(p*p)**line.size
    c/=1-(p*p*p)**line.size
    line.map do |l|
      a=a*p+l
      b=b*p*p+l
      c=c*p*p*p+l
      5*a-4*b+c-l
    end
  }
  smooth = ->line{
    oneway[line].zip(oneway[line.reverse].reverse).map(&:sum)
  }
  arr = arr.map(&smooth).transpose.map(&smooth)
  values = arr.flatten
  av = values.sum/values.size
  dev = Math.sqrt(values.map{|a|(a-av)**2}.sum/values.size)
  arr.map{|l|l.map{|v|(v-av)/dev}}
end

size = 1024

base = noise size, 64
base2 = noise size, 8
mount = noise size, 16
mnoise1 = noise size, 8
mnoise2 = noise size, 4
rbase = noise size, 64
rnoise = noise size, 16
beachnoise = noise size, 32
arr=size.times.map{[]}
size.times.to_a.repeated_permutation(2){|i,j|
  b=base[i][j]
  m=mount[i][j]-0.8
  n1=mnoise1[i][j]
  n2=mnoise2[i][j]
  b = (b+Math.sqrt(b*b+0.25))/2
  arr[i][j] = 0.1*b+base2[i][j]*0.05 + (m+Math.sqrt(m*m+0.25))/8 * (1+n1/4+n2/8)
}
sea = arr.flatten.min
size.times.to_a.repeated_permutation(2){|i,j|
  rpm = rbase[i][j]+rnoise[i][j]/8
  rval = 1-1/(1+rpm*rpm)
  arr[i][j]= sea + (arr[i][j]-sea)*rval-0.01/(1+32*rpm*rpm)*(0.05+arr[i][j]-sea)
}
arr=arr.map{|l|l.map{|v|
  v>sea ? v : (Math.exp(16*(v-sea))-1)+sea
}}
min = arr.flatten.min
max = arr.flatten.max
arr=arr.map{|l|l.map{|v|
  h = 63+32*(v-sea)/(max-min)
  h.floor
}}

img = ChunkyPNG::Image.new size, size
size.times.to_a.repeated_permutation(2).each do |i, j|
  h=arr[i][j]
  r,g,b=[arr[i][j]]*3
  if h<63
    r*=0.8
    g*=0.8
  end
  img[i,j]=(r.to_i<<24)|(g.to_i<<16)|(b.to_i<<8)|0xff
end
img.save 'tmp.png'

world = MCWorld::World.new x:0, z:0
tallgrassnoise = noise size, 32
biomes = noise size, 64

gen_tree = ->x,z,y,oak{
  if oak
    wood = MCWorld::Block::OakWood
    leaves = MCWorld::Block::OakLeaves
  else
    wood = MCWorld::Block::BirchWood
    leaves = MCWorld::Block::BirchLeaves
  end
  h = [3,4,5].sample
  xz = rand-0.5
  (h-2..h+3).each do |iy|
    (-2..2).to_a.repeated_permutation(2) do |ix, iz|
      next if x+ix<0||x+ix>=512||z+iz<0||z+iz>=512
      r2 = (h-1.5-iy)**2+ix**2+iz**2
      world[x+ix,z+iz,y+iy] = leaves if r2+ix*iz*xz < 8
    end
  end
  h.times{|iy|world[x,z,y+iy] = wood}
}
512.times.to_a.repeated_permutation(2){|x,z|
  p [x,z] if x == z
  h = arr[x][z]
  world[x,z,0]=MCWorld::Block::Bedrock
  br = (3+3*beachnoise[x][z]).to_i
  beach = (-br..br).to_a.repeated_permutation(2).any?{|i,j|arr[(x+i)%arr.size][(z+j)%arr.size]<63}
  (1..h).each do |y|
    if y<h-10
      world[x,z,y]=MCWorld::Block::Stone
    else
      world[x,z,y]=beach ? MCWorld::Block::Sand : MCWorld::Block::Dirt
    end
  end
  world[x,z,h] = MCWorld::Block::Grass if h>=63 && !beach
  (h+1..63).each { |y| world[x,z,y] = MCWorld::Block::StillWater }
  if world[x,z,h] == MCWorld::Block::Grass && world[x,z,h+1].nil?
    if rand < 0.5+0.2*tallgrassnoise[x][z]
      tallgrass = MCWorld::Block::TallGrass[1]
      if rand < 0.95
        plant = tallgrass
      else
        plants = [MCWorld::Block::Dandelion, MCWorld::Block::Poppy, MCWorld::Block::Poppy[3], MCWorld::Block::Poppy[8]]
        if biomes[x][z] > 0
          plant = plants.sample
        elsif biomes[x-64][128-z] > 0.5
          plant = [*(4..7).map{|i|MCWorld::Block::Poppy[i]}].sample
        elsif biomes[512-x][z-256] > 0
          plant = [tallgrass, MCWorld::Block::Poppy[2]].sample
        else
          plant = [tallgrass, MCWorld::Block::Poppy[1]].sample
        end
      end
      world[x,z,h+1] = plant
      if rand < 0.02 && rand < 0.02 + (h-63)/64.0
        gen_tree.call x,z,h+1,rand > biomes[z-384][256-x]
      end
    end
  end
}
File.write "spigot/world/region/r.0.0.mca", world.encode
#
#
# chunks = JSON.parse File.read('chunks.json') rescue nil
# chunks ||= [[1,1],[1,7],[1,9],[1,11],[1,13],[3,11],[4,6],[4,25],[4,27],[4,30],[6,1],[6,20],[6,24],[6,26],[6,28],[6,30],[7,8],[7,10],[7,22],[8,1],[8,26],[8,28],[8,30],[9,10],[10,1],[10,27],[11,18],[11,20],[11,25],[12,5],[12,12],[13,3],[14,5],[14,14],[14,21],[14,29],[15,18],[15,25],[16,1],[16,15],[16,23],[16,28],[17,4],[17,19],[17,26],[18,6],[18,8],[18,29],[19,22],[19,24],[20,26],[20,30],[21,9],[21,17],[22,6],[22,20],[22,30],[23,8],[24,19],[24,21],[25,8],[25,24],[26,1],[26,6],[26,18],[26,20],[26,22],[27,14],[27,27],[28,4],[28,12],[28,21],[29,1],[29,15],[29,19],[29,23],[30,10],[30,17],[30,21],[30,26],[30,28],[30,30]]
# jsonfile = 'areas.json'
# world = MCWorld::World.new file: infile
# ymax = ->cx,cz{
#   world.chunk(cx,cz).instance_eval{@blocks}.size
# }
# void_block = MCWorld::Block[217]
# block_ids = Set.new %w(Bedrock Stone Sandstone Grass Dirt Gravel Sand Sandstone IronOre CoalOre Cobblestone).map{|name|
#   MCWorld::Block.const_get(name).id
# }
# bottom = ->x,z{
#   ymax[x/16,z/16].times.reverse_each.find do |y|
#     block_ids.include? world[x,z,y]&.id
#   end
# }
# size = 16
# offset = 8
# ccoords = (8-size/2...8+size/2).to_a.repeated_permutation 2
# acoords = (8-size/2-offset...8+size/2+offset).to_a.repeated_permutation 2
# areas = []
# chunks.each do |cx,cz|
#   cpos = ccoords.map{|x,z|[cx*16+x,cz*16+z]}
#   apos = acoords.map{|x,z|[cx*16+x,cz*16+z]}
#   cmin = cpos.map{|x,z|bottom[x,z]}.min
#   amin = apos.map{|x,z|bottom[x,z]}.min
#   (8-size/2-1..8+size/2).to_a.repeated_permutation(2).each do |x,z|
#     (amin...cmin).each{|y|world[16*cx+x,16*cz+z,y]=MCWorld::Block::Bedrock}
#   end
#   ox, oz, oy = 16*cx+8-size/2, 16*cz+8-size/2, cmin
#   areas << {
#     print: {
#       min: {x: ox, z: oz, y: cmin},
#       max: {x: ox+size-1, z: oz+size-1, y: cmin+size-1}
#     },
#     area: {
#       min: {x: ox-offset+1, z: oz-offset+1, y: amin},
#       max: {x: ox+size+offset-2, z: oz+size+offset-2, y: cmin+size+offset-2}
#     }
#   }
#   (-1..size).each{|i|
#     world[ox+i, oz-1, cmin-1]=MCWorld::Block::Bedrock
#     world[ox+i, oz+size, cmin-1]=MCWorld::Block::Bedrock
#     world[ox-1, oz+i, cmin-1]=MCWorld::Block::Bedrock
#     world[ox+size, oz+i, cmin-1]=MCWorld::Block::Bedrock
#
#     world[ox+i, oz-1, cmin+size]=MCWorld::Block::Bedrock
#     world[ox+i, oz+size, cmin+size]=MCWorld::Block::Bedrock
#     world[ox-1, oz+i, cmin+size]=MCWorld::Block::Bedrock
#     world[ox+size, oz+i, cmin+size]=MCWorld::Block::Bedrock
#     world[ox-1,oz-1,cmin+i]=MCWorld::Block::Bedrock
#     world[ox-1,oz+size,cmin+i]=MCWorld::Block::Bedrock
#     world[ox+size,oz-1,cmin+i]=MCWorld::Block::Bedrock
#     world[ox+size,oz+size,cmin+i]=MCWorld::Block::Bedrock
#   }
#   apos.each do |x,z|
#     world[x,z,amin-1]=MCWorld::Block::Bedrock
#   end
#   apos.each do |x,z|
#     world[x,z,cmin+size+offset-1]=void_block
#   end
#   fill = ->(x,z){
#     air_flag = true
#     (amin..cmin+size+offset).reverse_each do |y|
#       id = world[x,z,y]&.id
#       air_flag = false if block_ids.include?(id) || id == MCWorld::Block::StillWater.id
#       world[x,z,y] = air_flag ? void_block : MCWorld::Block::Bedrock
#     end
#   }
#   (-offset...size+offset).each do |i|
#     fill.call ox+i, oz-offset
#     fill.call ox+i, oz+size+offset-1
#     fill.call ox-offset, oz+i
#     fill.call ox+size+offset-1, oz+i
#   end
# end
# File.write jsonfile, areas.to_json
# # File.write outfile, world.encode

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
biomes = noise size, 32

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
        types = [biomes[x][z], biomes[x-64][128-z], biomes[512-x][z-256], biomes[512-z][x-256]]
        case types.index types.max
        when 0
          plant = plants.sample
        when 1
          plant = [*(4..7).map{|i|MCWorld::Block::Poppy[i]}].sample
        when 2
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

def gen_chunk arr, world
  size = 16
  areas = []
  chunkinfo = {}
  (1...31).to_a.repeated_permutation(2).each do |i, j|
    x0,y0 = 16*i,16*j
    cheights = 16.times.to_a.repeated_permutation(2).map{|ix, iy|arr[x0+ix][y0+iy]}
    aheights = (-7...16+7).to_a.repeated_permutation(2).map{|ix, iy|arr[x0+ix][y0+iy]}
    cmin, cmax = cheights.minmax
    amin = aheights.min
    next if cmax<63||cmin<62||cmax-cmin>4
    chunkinfo[[i,j]] = {x: i*16, z: j*16, cmin: cmin, cmax: cmax, amin: amin}
  end
  chunks = chunkinfo.values.select{|c|c[:cmax]>=63&&c[:cmin]>=62&&c[:cmax]-c[:cmin]<=4}.shuffle.sort_by{|a|a[:cmax]-a[:cmin]}
  occupied = {}

  void_block = MCWorld::Block[217]
  block_ids = Set.new %w(Bedrock Stone Sandstone Grass Dirt Gravel Sand Sandstone IronOre CoalOre Cobblestone).map{|name|
    MCWorld::Block.const_get(name).id
  }
  chunks.each do |c|
    x,z,cmin,cmax,amin = c.values
    next if [-size,0,size].repeated_permutation(2).any?{|i,j|occupied[[x+i,z+j]]}
    occupied[[x,z]] = true
    size = 16
    offset = 8
    areas << {
      print: {
        min: {x: x, z: z, y: cmin},
        max: {x: x+size-1, z: z+size-1, y: cmin+size-1}
      },
      area: {
        min: {x: x-offset+1, z: z-offset+1, y: amin},
        max: {x: x+size+offset-2, z: z+size+offset-2, y: cmin+size+offset-1}
      }
    }
    (8-size/2-1...8+size/2+1).to_a.repeated_permutation(2) do |i,j|
      (amin...cmin).each{|y|world[x+i,z+j,y]=MCWorld::Block::Bedrock}
    end
    (-1..size).each do |i|
      world[x+i, z-1, cmin-1]=MCWorld::Block::Bedrock
      world[x+i, z+size, cmin-1]=MCWorld::Block::Bedrock
      world[x-1, z+i, cmin-1]=MCWorld::Block::Bedrock
      world[x+size, z+i, cmin-1]=MCWorld::Block::Bedrock

      world[x+i, z-1, cmin+size]=MCWorld::Block::Bedrock
      world[x+i, z+size, cmin+size]=MCWorld::Block::Bedrock
      world[x-1, z+i, cmin+size]=MCWorld::Block::Bedrock
      world[x+size, z+i, cmin+size]=MCWorld::Block::Bedrock
      world[x-1,z-1,cmin+i]=MCWorld::Block::Bedrock
      world[x-1,z+size,cmin+i]=MCWorld::Block::Bedrock
      world[x+size,z-1,cmin+i]=MCWorld::Block::Bedrock
      world[x+size,z+size,cmin+i]=MCWorld::Block::Bedrock
    end
    (8-size/2-offset...8+size/2+offset).to_a.repeated_permutation(2) do |i,j|
      world[x+i,z+j,amin-1]=MCWorld::Block::Bedrock
    end
  end
  File.write 'areas.json', areas.to_json
  File.write "spigot/world/region/r.0.0.mca", world.encode
  File.unlink 'area_users.json'
end
gen_chunk arr, world

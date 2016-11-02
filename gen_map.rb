require 'pry'
require 'chunky_png'
require './mc_world/world'

def load_world file=nil
  MCWorld::World.new file: (file||'spigot/world/region/r.0.0.mca')
end

def image world
  size=512
  img = ChunkyPNG::Image.new size, size
  img2 = ChunkyPNG::Image.new size, size
  map = []
  size.times.to_a.repeated_permutation(2) do |x,z|
    p x if z==0
    zmax = world.chunk(x/16,z/16).instance_eval{@blocks}.size
    y = world[x,z,0] ? zmax.times.reverse_each.find{|y|world[x,z,y]} : 0
    block = world[x,z,y]
    if block&.type == MCWorld::Block::StillWater || block&.type == MCWorld::Block::FlowingWater
      y2 = y.times.reverse_each.find{|y|
        bt = world[x,z,y]&.type
        bt && bt != MCWorld::Block::StillWater && bt != MCWorld::Block::FlowingWater
      } || 0
      (map[x]||=[])[z]=[y2,world[x,z,y2], y-y2]
    else
      (map[x]||=[])[z]=[y,world[x,z,y], 0]
    end
  end
  darkh = -> dh { Math.exp -dh/16.0 }
  size.times{|x|
    prev=0
    size.times.reverse_each{|z|
      h, block,w = map[x][z]
      br = darkh[prev - h]
      rgb = [block.id*123, block.id*162+block.data*241, block.id*172+193*block.data]
      r, g, b = rgb.map{|a|((a&0xff)*br).to_i}
      if w>0
        d=0.5*Math.exp(-w/8.0)
        r=0x10+r*d
        g=0x10+g*d
        b=0x80+b*d
        img2[x,z]=((h-w-10)<<24)|((h-w-10)<<16)|(h<<8)|0xff
      else
        img2[x,z]=(h*0x1010100)|0xff
      end
      r,g,b = [r,g,b].map{|c|(c<0?0:c>0xff?0xff:c).to_i}
      img[x,z] = (r<<24)|(g<<16)|(b<<8)|0xff
      prev=h
    }
  }
  img.save('mcmap.png')
  img2.save('mcheight.png')
end

image load_world 'spigot/world/region/r.0.0_original.mca'

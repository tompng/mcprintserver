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
  colormap = ChunkyPNG::Image.from_file 'public/texture.png'
  color = ->(id, data){
    rgba = colormap[id%16*4+data%4, id/16*4+data/4]
    a,b,g,r =(rgba+0x100000000).digits(0x100)
    [r,g,b]
  }
  map = []
  size.times.to_a.repeated_permutation(2) do |x,z|
    p x if z==0
    zmax = world.chunk(x/16,z/16).instance_eval{@blocks}.size
    y = world[x,z,0] ? zmax.times.reverse_each.find{|y|
      b = world[x,z,y]
      b&&b.id!=217
    } : 0
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
  darkh = -> dh { 2/(1+Math.exp(-dh/16.0)) }
  size.times{|x|
    size.times.reverse_each{|z|
      h, block,w = map[x][z]
      br = darkh.call map[x][[z+2,size-1].min][0]+map[x][[z+1,size-1].min][0]-map[x][[z-1,0].max][0]-map[x][[z-2].max][0]
      rgb = color[block&.id||0, block&.data||0]
      r, g, b = rgb.map{|a|a*br}
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
  img.save('public/mcmap.png')
  img2.save('public/mcheight.png')
end

# image load_world 'spigot/world/region/r.0.0_original.mca'
image load_world 'spigot/world/region/r.0.0.mca'

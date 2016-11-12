require_relative '../mc_world/world'
require 'chunky_png'
require 'json'
class OBJExtract
  def self.gen_mtl
    grass_color = [0x60, 0x90, 0x30]
    stem_color1 = [0x40, 0x80, 0x10]
    stem_color2 = [0x80, 0x70, 0x10]
    leaf_color  = [0x40, 0x80, 0x10]
    redstone_color = [0x80,-0xff,-0xff]
    colors = {
      'grass_top' => grass_color,
      'fern' => grass_color,
      'tallgrass' => grass_color,
      'double_plant_fern_bottom' => grass_color,
      'double_plant_fern_top' => grass_color,
      'double_plant_grass_bottom' => grass_color,
      'double_plant_grass_top' => grass_color,
      'leaves_acacia' => leaf_color,
      'leaves_big_oak' => leaf_color,
      'leaves_birch' => [0x60,0x80,0x40],
      'leaves_jungle' => leaf_color,
      'leaves_oak' => leaf_color,
      'leaves_spruce' => [0x40,0x80,0x40],
      'melon_stem_connected' => stem_color1,
      'melon_stem_disconnected' => stem_color1,
      'pumpkin_stem_connected' => stem_color2,
      'pumpkin_stem_disconnected' => stem_color2,
      'vine' => grass_color,
      'waterlily' => grass_color,
      'redstone_dust_dot' => redstone_color,
      'redstone_dust_line0' => redstone_color,
      'redstone_dust_line1' => redstone_color,
    }

    png_dir = "#{File.dirname(__FILE__)}/blocks"
    files = Dir.glob("#{png_dir}/*.png")
    image = ChunkyPNG::Image.new 512, 512
    meta = {}
    files.each_slice(32).with_index do |slice, y|
      slice.each_with_index do |file, x|
        name = File.basename(file).gsub(/\.png$/, '')
        meta[name] = {x: x, y: y}
        img = ChunkyPNG::Image.from_file file
        color = colors[name]
        (0...16).to_a.repeated_permutation 2 do |ix, iy|
          c = img[ix%img.width, iy%img.height]
          if color
            a,b,g,r = 4.times.map{|i|(c>>(8*i))&0xff}
            r += color[0]-0x80
            g += color[1]-0x80
            b += color[2]-0x80
            a = 0xff if name =~ /leaves/
            r,g,b = [r,g,b].map{|c|[0,c,0xff].sort[1]}
            image[16*x+ix, 16*y+iy] = [a,b,g,r].each_with_index.map{|c,i|c<<(8*i)}.inject(:|)
          else
            image[16*x+ix, 16*y+iy] = c
          end
        end
      end
    end
    File.write 'meta.json', meta.to_json
    image.save 'texture.png'
    File.write 'block.mtl', %(newmtl block\n  map_Ka texture.png\n  map_Ka texture.png)
  end

  def initialize file
    @world = MCWorld::World.new file: file
  end

  def stl name='shape'
    @output = []
    @output << "solid #{name}"
    yield
    @output << "endsolid #{name}"
    @output.join "\n"
  end
  def face pos, dir
    val, axis = dir.each.with_index.find{ |val, axis| val.nonzero? }
    p00, p01, p10, p11 = 4.times.map { dir.dup }
    p00[ (axis+1) % 3] = -1
    p00[ (axis+2) % 3] = -1
    p01[ (axis+1) % 3] = -1
    p01[ (axis+2) % 3] = +1
    p10[ (axis+1) % 3] = +1
    p10[ (axis+2) % 3] = -1
    p11[ (axis+1) % 3] = +1
    p11[ (axis+2) % 3] = +1
    p10, p01 = p01, p10 if val < 0
    vertex = ->(p){pos.zip(p).map{|ps,p|ps+(1+p)/2}.join ' '}
    @output << %(
      facet normal #{dir.join ' '}
        outer loop
          vertex #{vertex[p00]}
          vertex #{vertex[p10]}
          vertex #{vertex[p11]}
        endloop
      endfacet
      facet normal #{dir.join ' '}
        outer loop
          vertex #{vertex[p00]}
          vertex #{vertex[p11]}
          vertex #{vertex[p01]}
        endloop
      endfacet
    )
  end

  def extract xmin,ymin,zmin,xmax,ymax,zmax
    table = {}
    set = ->(x,y,z){table[(((x-xmin)&0xff)<<16)|(((y-ymin)&0xff)<<8)|((z-zmin)&0xff)]=true}
    get = ->(x,y,z){table[(((x-xmin)&0xff)<<16)|(((y-ymin)&0xff)<<8)|((z-zmin)&0xff)]}
    (xmin..xmax).each{|x|
      (ymin..ymax).each{|y|
        (zmin..zmax).each{|z|
          set[x,y,z] if @world[x,z,y]
        }
      }
    }
    stl 'mc' do
      (xmin..xmax).each{|x|
        (ymin..ymax).each{|y|
          (zmin..zmax).each{|z|
            next unless get[x,y,z]
            [[-1,0,0],[1,0,0],[0,-1,0],[0,1,0],[0,0,-1],[0,0,1]].each{|dx,dy,dz|
              face [x-(xmin+xmax)/2,y-(ymin+ymax)/2,z-(zmin+zmax)/2], [dx,dy,dz] unless get[x+dx,y+dy,z+dz]
            }
          }
        }
      }
    end
  end
end


OBJExtract.gen_mtl

require_relative '../mc_world/world'
require 'chunky_png'
require 'json'
require_relative './block_textures'
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
    @meta = meta
    File.write 'meta.json', meta.to_json
    image.save 'texture.png'
    File.write 'block.mtl', %(newmtl block\n  map_Ka texture.png\n  map_Kd texture.png\n)
  end
  gen_mtl

  def self.texture_uvs texture_id
    pos = @meta[texture_id.to_s]
    [[0,0],[1,0],[1,1],[0,1]].map do |x, y|
      [(pos[:x]+x)/32.0, (32-pos[:y]-y)/32.0]
    end
  end

  def initialize file
    @world = MCWorld::World.new file: file
    @verts = []
    @uvs = []
    @faces = []
    @norms = []
  end

  def vert x,y,z
    @verts << [x,y,z].map{|x|x/8.0}
    @verts.size
  end

  def uv u,v
    @uvs << [u,v]
    @uvs.size
  end

  def face a, b, c
    pa, pb, pc = @verts[a[0]-1], @verts[b[0]-1], @verts[c[0]-1]
    ax, ay, az = pa.zip(pc).map{|a,c|a-c}
    bx, by, bz = pb.zip(pc).map{|b,c|b-c}
    nx = ay*bz-az*by
    ny = az*bx-ax*bz
    nz = ax*by-ay*bx
    nr = Math.sqrt(nx**2+ny**2+nz**2)
    @norms << [nx/nr, ny/nr, nz/nr]
    n = @norms.size
    @faces << [[*a,n],[*b,n],[*c,n]]
  end

  def quadface pos, dir, texture_id
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
    vertex = ->(p){pos.zip(p).map{|ps,p|ps+(1+p)/2}}

    verts = [vertex[p00], vertex[p10], vertex[p11], vertex[p01]].map{|v|vert *v}
    uvs = self.class.texture_uvs(texture_id).map{|tc|uv *tc}

    face *[0,1,2].map{|i|[verts[i],uvs[i]]}
    face *[0,2,3].map{|i|[verts[i],uvs[i]]}
  end

  def data
    vert_defs = @verts.map{|v|"v #{v.join ' '}\n"}
    uv_defs = @uvs.map{|uv|"vt #{uv.join ' '}\n"}
    norm_defs = @norms.map{|n|"vn #{n.join ' '}\n"}
    face_defs = @faces.map{|f|"f #{f.map{|x|x.join '/'}.join ' '}\n"}
    header = "mtllib block.mtl\no block\ng block\nusemtl block"
    [header,vert_defs.join,uv_defs.join,norm_defs.join,face_defs.join].join "\n"
  end

  def extract xmin,ymin,zmin,xmax,ymax,zmax
    table = {}
    get = ->(x,y,z){
      @world[x,z,y] if (xmin..xmax).include?(x) && (ymin..ymax).include?(y) && (zmin..zmax).include?(z)
    }
    (xmin..xmax).each{|x|
      (ymin..ymax).each{|y|
        (zmin..zmax).each{|z|
          block = BlockTextures::Info[get[x,y,z]]
          next unless block
          [[-1,0,0],[1,0,0],[0,-1,0],[0,1,0],[0,0,-1],[0,0,1]].each{|dx,dy,dz|
            facing = BlockTextures::Info[get[x+dx,y+dy,z+dz]]
            quadface [x-(xmin+xmax)/2,y-(ymin+ymax)/2,z-(zmin+zmax)/2], [dx,dy,dz], block unless facing
          }
        }
      }
    }
    data
  end
end

objext = OBJExtract.new('../spigot/world/region/r.0.0.mca')
File.write '../public/assets/block.obj', objext.extract(16,66-12,16,31,81-12,31)

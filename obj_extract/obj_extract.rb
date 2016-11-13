require_relative '../mc_world/world'
require 'chunky_png'
require 'json'
require_relative './block_textures'
class OBJExtract
  def initialize file
    @world = MCWorld::World.new file: file
    @verts = {}
    @vert_array = []
    @uvs = {}
    @norms = {}
    @faces = []
  end

  def vert x,y,z
    v = [x,y,z].map{|x|(x/8.0).round(3)}
    vi = @verts[v.join(' ')] ||= @verts.size+1
    @vert_array[vi-1] ||= v
    vi
  end

  def uv u,v
    uv = [u, v].join(' ')
    @uvs[uv] ||= [@uvs.size+1, uv]
    @uvs[uv].first
  end

  def norm x,y,z
    n = [x,y,z].map{|x|x.round(3)}.join(' ')
    @norms[n] ||= [@norms.size+1, n]
    @norms[n].first
  end

  def face a, b, c, d=nil
    if d
      face a,b,c
      face a,c,d
      return
    end
    pa, pb, pc = [a,b,c].map{|vi,_|@vert_array[vi-1]}
    ax, ay, az = pa.zip(pc).map{|a,c|a-c}
    bx, by, bz = pb.zip(pc).map{|b,c|b-c}
    nx = ay*bz-az*by
    ny = az*bx-ax*bz
    nz = ax*by-ay*bx
    nr = Math.sqrt(nx**2+ny**2+nz**2)
    n = norm nx/nr, ny/nr, nz/nr
    @faces << [[*a,n],[*b,n],[*c,n]]
  end

  def quadface pos, dir, texture_uvs
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
    uvs = texture_uvs.map{|tc|uv *tc}

    face *verts.zip(uvs)
  end

  def data
    round = ->v{v.map{|x|x.round(2)}.join(' ')}
    vert_defs = @vert_array.map{|v|"v #{v.join(' ')}\n"}
    uv_defs = @uvs.values.map{|_,uv|"vt #{uv}\n"}
    norm_defs = @norms.values.map{|_,n|"vn #{n}\n"}
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
          pos = [x-(xmin+xmax)/2,y-(ymin+ymax)/2,z-(zmin+zmax)/2]
          if block.cube?
            [[-1,0,0],[1,0,0],[0,-1,0],[0,1,0],[0,0,-1],[0,0,1]].each{|dx,dy,dz|
              facing = BlockTextures::Info[get[x+dx,y+dy,z+dz]]
              next if facing&.cube?
              quadface pos, [dx,dy,dz], block.face(dx,dy,dz)
            }
          else
            block.render self, pos
          end
        }
      }
    }
    data
  end
end

objext = OBJExtract.new('../spigot/world/region/r.0.0.mca')
File.write '../public/assets/block.obj', objext.extract(16,66-12,16,31,81-12,31)

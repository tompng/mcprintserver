require_relative '../mc_world/world'
require 'chunky_png'

module Shape
  def self.build mcblock
    return nil unless mcblock
    Block.new mcblock.id, mcblock.data
  end
  class Block
    attr_reader :id, :data
    def initialize id, data
      @id, @data = id, data
    end
    def uv
      [(id%16*4+data%4+0.5)/64, 1-(id/16*4+data/4+0.5)/64]
    end
    def build env
    end
    def to_obj
    end
  end
  class Stairs < Block
    def build env
      dir = @data&3
      up = (@data&4)>0?0:1
      dirvecs = [[1,0], [-1,0], [0,1], [0,-1]]
      dvec = dirvecs[dir]
      blockback = env.call(*dvec)
      blockfront = env.call(*dvec.map(&:-@))
      @shape = [[[false,false],[false,false]],[[false,false],[false,false]]]
      4.times{|i|@shape[i%2][i/2][1-up]=true}
      if Stairs === blockback && blockback.data&4==@data&4 && blockback.data&2!=@data&2
        dvec2 = dirvecs[blockback.data&3]
        dx=dvec[0]+dvec2[0]>0?1:0
        dy=dvec[1]+dvec2[1]>0?1:0
        @shape[dx][dy][up]=true
      elsif Stairs === blockfront && blockfront.data&4==@data&4 && blockfront.data&2!=@data&2
        dvec2 = dirvecs[blockfront.data&3]
        dx=dvec[0]+dvec2[0]>0?0:1
        dy=dvec[1]+dvec2[1]>0?0:1
        4.times{|i|@shape[i%2][i/2][up]=true}
        @shape[dx][dy][up]=false
      else
        2.times{
          dx=(dvec[0].nonzero?||(2*i-1))>0?1:0
          dy=(dvec[1].nonzero?||(2*i-1))>0?1:0
          @shape[dx][dy][up]=true
        }
      end
    end
  end
end

class OBJ
  def initialize
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
end
class OBJExtract
  def initialize file
    @obj = OBJ.new
    @world = MCWorld::World.new file: file
  end
  def extract xmin,ymin,zmin,xmax,ymax,zmax
    table = {}
    get = ->(x,y,z){
      @world[x,z,y] if (xmin..xmax).include?(x) && (ymin..ymax).include?(y) && (zmin..zmax).include?(z)
    }
    (xmin..xmax).each{|x|
      (ymin..ymax).each{|y|
        (zmin..zmax).each{|z|
          block = Shape.build get[x,y,z]
          next unless block
          pos = [x-(xmin+xmax)/2,y-(ymin+ymax)/2,z-(zmin+zmax)/2]
          [[-1,0,0],[1,0,0],[0,-1,0],[0,1,0],[0,0,-1],[0,0,1]].each{|dx,dy,dz|
            facing = Shape.build get[x+dx,y+dy,z+dz]
            next if facing
            @obj.quadface pos, [dx,dy,dz], [block.uv]*10
          }
        }
      }
    }
    @obj.data
  end
end

objext = OBJExtract.new('../spigot/world/region/r.0.0.mca')
File.write '../public/assets/block.obj', objext.extract(16,66-12,16,31,81-12,31)

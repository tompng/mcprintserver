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
  end
  class Cube < Block
    def build &env
      @face = []
      3.times do |axis|
        [-1,1].each do |dir|
          vec = [0,0,0]
          vec[axis] = dir
          unless Cube === env.call(*vec).class
            @face << vec
          end
        end
      end
    end
    def save x, y, z, output:
      @face.each do |dx, dy, dz|
        output.cubeface [x+0.5,y+0.5,z+0.5], [dx,dy,dz], [uv]*4
      end
    end
  end
  class TransparentCube < Cube;end
  class Wall < Block
    def connectable? block
      !!block
    end
    def square_width
      0.25
    end
    def wall_width
      0.1
    end
    def build &env
      dirs = [[-1,0],[1,0],[0,-1],[0,1]]
      @connects = []
      dirs.each do |dx, dy|
        @connects << [dx, dy] if connectable? env.call(dx,dy,0)
      end
    end
    def save x, y, z, output:
      dirs = 6.times.map{|i|[0,0,0].tap{|a|a[i/2]=i%2*2-1}}
      dirs.each do |dx, dy, dz|
        output.cubeface [x+0.5,y+0.5,z+0.5], [dx,dy,dz], [uv]*4, xsize: square_width, ysize: square_width
        @connects.each do |cx, cy|
          s = (1-square_width)/2.0
          t = square_width/2+s/2
          xs = cx.nonzero? ? s : wall_width
          ys = cy.nonzero? ? s : wall_width
          output.cubeface [x+0.5+t*cx,y+0.5+t*cy,z+0.5], [dx,dy,dz], [uv]*4, xsize: xs, ysize: ys
        end
      end
    end
  end
  class ThinWall < Wall
    def connectable? block
      Cube === block || ThinWall === block
    end
    def square_width;0.25;end
    def wall_width;0.25;end
  end
  class StoneWall < Wall
    def connectable? block
      StoneWall === block || (Cube === block && !(TransparentCube === block))
    end
    def square_width;0.6;end
    def wall_width;0.5;end
  end
  class FenceWall < Wall
    def connectable? block
      FenceWall === block || (Cube === block && !(TransparentCube === block))
    end
    def square_width;0.4;end
    def wall_width;0.3;end
  end
  class FenceWall2 < Wall
    def connectable? block
      FenceWall2 === block || (Cube === block && !(TransparentCube === block))
    end
    def square_width;0.4;end
    def wall_width;0.3;end
  end
  class Slab < Block
    def build &env
      @upper=(@data&0x8)!=0
      @face = [[-1,0,0],[1,0,0],[0,-1,0],[0,1,0]]
      @face << [0,0,1] if !@upper || env.call(0,0,1).class != Block
      @face << [0,0,-1] if @upper || env.call(0,0,-1).class != Block
    end
    def save x, y, z, output:
      @face.each do |dx, dy, dz|
        output.cubeface [x+0.5,y+0.5,z+(@upper?0.75:0.25)], [dx,dy,dz], [uv]*4, zsize: 0.5
      end
    end
  end
  class Stairs < Block
    def build &env
      dir = @data&3
      up = (@data&4)>0?0:1
      dirvecs = [[1,0], [-1,0], [0,1], [0,-1]]
      dvec = dirvecs[dir]
      blockback = env.call(*dvec,0)
      blockfront = env.call(*dvec.map(&:-@),0)
      @shape = 2.times.map{2.times.map{[false,false]}}
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
        2.times{|i|
          dx=(dvec[0].nonzero?||(2*i-1))>0?1:0
          dy=(dvec[1].nonzero?||(2*i-1))>0?1:0
          @shape[dx][dy][up]=true
        }
      end
    end
    def save x, y, z, output:
      dirs = 6.times.map{|i|[0,0,0].tap{|a|a[i/2]=i%2*2-1}}
      [0,1].repeated_permutation(3).each do |i,j,k|
        next unless @shape[i][j][k]
        dirs.each do |di, dj, dk|
          next if [0,1].include?(di+i)&&[0,1].include?(dj+j)&&[0,1].include?(dk+k)&&@shape[di+i][dj+j][dk+k]
          output.cubeface [x+0.25+i/2.0,y+0.25+j/2.0,z+0.25+k/2.0], [di,dj,dk], [uv]*4, size: 0.5
        end
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

  def cubeface pos, dir, texture_uvs, size: nil, xsize: 1, ysize: 1, zsize: 1
    xsize = ysize = zsize = size if size
    val, axis = dir.each.with_index.find{ |val, axis| val.nonzero? }
    p00, p01, p10, p11 = 4.times.map { dir.dup }
    p00[(axis+1)%3]=-1
    p00[(axis+2)%3]=-1
    p01[(axis+1)%3]=-1
    p01[(axis+2)%3]=+1
    p10[(axis+1)%3]=+1
    p10[(axis+2)%3]=-1
    p11[(axis+1)%3]=+1
    p11[(axis+2)%3]=+1
    p10, p01 = p01, p10 if val < 0
    vertex = ->(p){pos.zip(p, [xsize,ysize,zsize]).map{|ps,p,s|ps+p/2.0*s}}
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
    # @world = MCWorld::World.new file: file
  end
  def extract xmin,ymin,zmin,xmax,ymax,zmax
    # table = {}
    # get = ->(x,y,z){
    #   @world[x,z,y] if (xmin..xmax).include?(x) && (ymin..ymax).include?(y) && (zmin..zmax).include?(z)
    # }
    block_at = ->x,y,z{
      range = (0...16)
      return nil unless [x,y,z].all?{|v|range.include?(v)}
      break if z>5+3*Math.cos(0.2*x+0.3*y)+2*Math.sin(0.3*y-0.2*x)
      id, data = (13*x+17*y+19*z)%256, (5*x+7*y+11*z)%16
      if z+1>5+3*Math.cos(0.2*x+0.3*y)+2*Math.sin(0.3*y-0.2*x)
        klass = [Shape::Stairs, Shape::ThinWall, Shape::Slab, Shape::StoneWall, Shape::FenceWall][(x+y)/4%5]
        klass.new id, data
      else
        Shape::Cube.new id, data
      end
    }
    map3d={}
    iterator = 16.times.to_a.repeated_permutation(3)
    iterator.each{|x,y,z|map3d[[x,y,z]]=block_at[x,y,z]}
    iterator.each{|x,y,z|map3d[[x,y,z]]&.build{|i,j,k|map3d[[x+i, y+j, z+k]]}}
    iterator.each{|x,y,z|map3d[[x,y,z]]&.save(x-8,y-8,z-8,output: @obj)}

    @obj.data
  end
end

objext = OBJExtract.new('../spigot/world/region/r.0.0.mca')
File.write '../public/assets/block.obj', objext.extract(16,66-12,16,31,81-12,31)

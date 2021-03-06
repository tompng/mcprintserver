require_relative 'mc_world/world'

class STLExtract
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

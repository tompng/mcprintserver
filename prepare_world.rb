require 'json'
require './mc_world/world'

chunks = [[1,1],[1,7],[1,9],[1,11],[1,13],[3,11],[4,6],[4,25],[4,27],[4,30],[6,1],[6,20],[6,24],[6,26],[6,28],[6,30],[7,8],[7,10],[7,22],[8,1],[8,26],[8,28],[8,30],[9,10],[10,1],[10,27],[11,18],[11,20],[11,25],[12,5],[12,12],[13,3],[14,5],[14,14],[14,21],[14,29],[15,18],[15,25],[16,1],[16,15],[16,23],[16,28],[17,4],[17,19],[17,26],[18,6],[18,8],[18,29],[19,22],[19,24],[20,26],[20,30],[21,9],[21,17],[22,6],[22,20],[22,30],[23,8],[24,19],[24,21],[25,8],[25,24],[26,1],[26,6],[26,18],[26,20],[26,22],[27,14],[27,27],[28,4],[28,12],[28,21],[29,1],[29,15],[29,19],[29,23],[30,10],[30,17],[30,21],[30,26],[30,28],[30,30]]
infile='spigot/world/region/r.0.0_original.mca'
outfile='spigot/world/region/r.0.0.mca'
jsonfile = 'areas.json'
world = MCWorld::World.new file: infile
ymax = ->cx,cz{
  world.chunk(cx,cz).instance_eval{@blocks}.size
}
void_block = MCWorld::Block[217]
block_ids = Set.new %w(Bedrock Stone Sandstone Grass Dirt Gravel Sand Sandstone IronOre CoalOre Cobblestone).map{|name|
  MCWorld::Block.const_get(name).id
}
bottom = ->x,z{
  ymax[x/16,z/16].times.reverse_each.find do |y|
    block_ids.include? world[x,z,y]&.id
  end
}
size = 16
offset = 8
ccoords = (8-size/2...8+size/2).to_a.repeated_permutation 2
acoords = (8-size/2-offset...8+size/2+offset).to_a.repeated_permutation 2
areas = []
chunks.each do |cx,cz|
  cpos = ccoords.map{|x,z|[cx*16+x,cz*16+z]}
  apos = acoords.map{|x,z|[cx*16+x,cz*16+z]}
  cmin = cpos.map{|x,z|bottom[x,z]}.min
  amin = apos.map{|x,z|bottom[x,z]}.min
  (8-size/2-1..8+size/2).to_a.repeated_permutation(2).each do |x,z|
    (amin...cmin).each{|y|world[16*cx+x,16*cz+z,y]=MCWorld::Block::Bedrock}
  end
  ox, oz, oy = 16*cx+8-size/2, 16*cz+8-size/2, cmin
  areas << {
    print: {
      min: {x: ox, z: oz, y: cmin},
      max: {x: ox+size-1, z: oz+size-1, y: cmin+size-1}
    },
    area: {
      min: {x: ox-offset+1, z: oz-offset+1, y: amin},
      max: {x: ox+size+offset-2, z: oz+size+offset-2, y: cmin+size+offset-2}
    }
  }
  (-1..size).each{|i|
    world[ox+i, oz-1, cmin-1]=MCWorld::Block::Bedrock
    world[ox+i, oz+size, cmin-1]=MCWorld::Block::Bedrock
    world[ox-1, oz+i, cmin-1]=MCWorld::Block::Bedrock
    world[ox+size, oz+i, cmin-1]=MCWorld::Block::Bedrock

    world[ox+i, oz-1, cmin+size]=MCWorld::Block::Bedrock
    world[ox+i, oz+size, cmin+size]=MCWorld::Block::Bedrock
    world[ox-1, oz+i, cmin+size]=MCWorld::Block::Bedrock
    world[ox+size, oz+i, cmin+size]=MCWorld::Block::Bedrock
    world[ox-1,oz-1,cmin+i]=MCWorld::Block::Bedrock
    world[ox-1,oz+size,cmin+i]=MCWorld::Block::Bedrock
    world[ox+size,oz-1,cmin+i]=MCWorld::Block::Bedrock
    world[ox+size,oz+size,cmin+i]=MCWorld::Block::Bedrock
  }
  apos.each do |x,z|
    world[x,z,amin-1]=MCWorld::Block::Bedrock
  end
  apos.each do |x,z|
    world[x,z,cmin+size+offset-1]=void_block
  end
  fill = ->(x,z){
    air_flag = true
    (amin..cmin+size+offset).reverse_each do |y|
      id = world[x,z,y]&.id
      air_flag = false if block_ids.include?(id) || id == MCWorld::Block::StillWater.id
      world[x,z,y] = air_flag ? void_block : MCWorld::Block::Bedrock
    end
  }
  (-offset...size+offset).each do |i|
    fill.call ox+i, oz-offset
    fill.call ox+i, oz+size+offset-1
    fill.call ox-offset, oz+i
    fill.call ox+size+offset-1, oz+i
  end
end
File.write jsonfile, areas.to_json
File.write outfile, world.encode

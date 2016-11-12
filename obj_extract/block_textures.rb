require_relative '../mc_world/world'
require 'json'
module BlockTextures
  class CubeBlock
    def initialize top, side=nil, bottom=nil
      @top = top
      @side = side || top
      @bottom = bottom || top
    end
    def cube?
      true
    end
    def face dx, dy, dz
      if dy>0
        BlockTextures.texture_uvs @top
      elsif dy<0
        BlockTextures.texture_uvs @bottom
      else
        BlockTextures.texture_uvs @side
      end
    end
  end
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

  def self.estimateds
    files = JSON.parse File.read('meta.json')
    MCWorld::Block::BlockDefinition.keys.map{|key|
      keywords = key.to_s.scan(/[A-Z][^A-Z]+/).map(&:downcase)
      matcheds = keywords.map{|kw|
        files.keys.select{|k|k.include?(kw)}
      }.reject(&:empty?)
      keys = matcheds.inject(:&)
      if keys&.size == 1
        [MCWorld::Block.const_get(key), CubeBlock.new(keys.first)]
      end
    }.compact.to_h
  end
  def self.overrides
    {
      MCWorld::Block::Grass => CubeBlock.new('grass_top', 'grass_side', 'dirt'),
      MCWorld::Block::Dirt => CubeBlock.new('dirt'),
      MCWorld::Block::Stone => CubeBlock.new('stone'),
      MCWorld::Block::SlimeBlock => CubeBlock.new('slime'),
      MCWorld::Block::EndStoneBricks => CubeBlock.new('end_bricks'),
      MCWorld::Block::Andesite => CubeBlock.new('stone_andesite'),
      MCWorld::Block::Granite => CubeBlock.new('stone_granite'),
      MCWorld::Block::Diorite => CubeBlock.new('stone_diorite'),
      MCWorld::Block::PolishedAndesite => CubeBlock.new('stone_andesite_smooth'),
      MCWorld::Block::PolishedGranite => CubeBlock.new('stone_granite_smooth'),
      MCWorld::Block::PolishedDiorite => CubeBlock.new('stone_diorite_smooth')
    }
  end
  Info = estimateds.merge overrides
end

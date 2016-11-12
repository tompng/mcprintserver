require_relative '../mc_world/world'
require 'json'
module BlockTextures
  def self.render_plane ctx, texture_id, position:, rotate: 0, scale: 1
    pos = @meta[texture_id]
    get = ->(x,y){
      return false unless (0...16).include?(x) && (0...16).include?(y)
      @image[16*pos[:x]+x, 16*pos[:y]+y]&0xff > 0x80
    }
    theta = Math::PI*rotate/180
    cos, sin = Math.cos(theta), Math.sin(theta)
    pixel = ->(*points){
      verts = points.map do |x, y, z|
        ctx.vert(
          position[0]+((x-8)*cos+(z-0.5)*sin)/16.0*scale,
          position[1]+(1-y/16.0)*scale,
          position[2]+((z-0.5)*cos-(x-8)*sin)/16.0*scale
        )
      end
      uvs = points.map do |x,y,z|
        ctx.uv (16*pos[:x]+[0.5, x, 15.5].sort[1])/512.0, 1-(16*pos[:y]+[0.5, y, 15.5].sort[1])/512.0
      end
      ctx.face *verts.zip(uvs)
    }
    (0...16).to_a.repeated_permutation(2).each do |x, y|
      next unless get.call x, y
      pixel.call [x, y,0], [x+1, y, 0], [x+1, y+1, 0], [x, y+1, 0]
      pixel.call [x, y, 1], [x, y+1, 1], [x+1, y+1, 1], [x+1, y, 1]
      unless get.call x-1, y
        pixel.call [x, y, 0], [x, y+1, 0], [x, y+1, 1], [x, y, 1]
      end
      unless get.call x+1, y
        pixel.call [x+1, y, 0], [x+1, y, 1], [x+1, y+1, 1], [x+1, y+1, 0]
      end
      unless get.call x, y-1
        pixel.call [x, y, 0], [x, y, 1], [x+1, y, 1], [x+1, y, 0]
      end
      unless get.call x, y+1
        pixel.call [x, y+1, 0], [x+1, y+1, 0], [x+1, y+1, 1], [x, y+1, 1]
      end
    end
  end

  class CrossBlock
    def initialize texture
      @texture = texture
    end
    def cube?
      false
    end
    def render ctx, pos
      position = pos.zip([0.5, 0, 0.5]).map{|a|a.inject :+}
      BlockTextures.render_plane ctx, @texture, position: position, rotate: 45, scale: Math.sqrt(2)
      BlockTextures.render_plane ctx, @texture, position: position, rotate: -45, scale: Math.sqrt(2)
    end
  end

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
        idx = dx>0 ? 0 : dz>0 ? 1 : dx<0 ? 2: 3
        rotates = [3,2,2,3]
        BlockTextures.texture_uvs @side, rotate: rotates[idx]
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
    @image = ChunkyPNG::Image.new 512, 512
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
            @image[16*x+ix, 16*y+iy] = [a,b,g,r].each_with_index.map{|c,i|c<<(8*i)}.inject(:|)
          else
            @image[16*x+ix, 16*y+iy] = c
          end
        end
      end
    end
    @meta = meta
    File.write 'meta.json', meta.to_json
    @image.save 'texture.png'
    File.write 'block.mtl', %(newmtl block\n  map_Ka texture.png\n  map_Kd texture.png\n)
  end
  gen_mtl

  def self.texture_uvs texture_id, rotate: 0, flip: false
    pos = @meta[texture_id.to_s]
    uvs = [[0,0],[1,0],[1,1],[0,1]].map{|x, y|
      [(pos[:x]+x)/32.0, (32-pos[:y]-y)/32.0]
    }
    uvs = [uvs[0],uvs[3],uvs[1],uvs[2]] if flip
    uvs.rotate(rotate)
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
    # require 'pry';binding.pry
    {
      MCWorld::Block::TallGrass => CrossBlock.new('tallgrass'),
      MCWorld::Block::Dandelion => CrossBlock.new('flower_dandelion'),
      MCWorld::Block::BlueOrchid => CrossBlock.new('flower_blue_orchid'),
      MCWorld::Block::Allium => CrossBlock.new('flower_allium'),
      MCWorld::Block::RedTulip => CrossBlock.new('flower_tulip_red'),
      MCWorld::Block::OrangeTulip => CrossBlock.new('flower_tulip_orange'),
      MCWorld::Block::WhiteTulip => CrossBlock.new('flower_tulip_white'),
      MCWorld::Block::PinkTulip => CrossBlock.new('flower_tulip_pink'),
      MCWorld::Block::OxeyeDaisy => CrossBlock.new('flower_oxeye_daisy'),

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

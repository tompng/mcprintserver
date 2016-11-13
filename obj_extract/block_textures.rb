require_relative '../mc_world/world'
require 'json'
module BlockTextures
  def self.render_plane ctx, texture_id, position:, rotate: 0, scale: 1, horizontal: false
    pos = @meta[texture_id]
    get = ->(x,y){
      return false unless (0...16).include?(x) && (0...16).include?(y)
      @image[16*pos[:x]+x, 16*pos[:y]+y]&0xff > 0x80
    }
    theta = Math::PI*rotate/180
    cos, sin = Math.cos(theta), Math.sin(theta)
    pixel = ->(*points){
      verts = points.map do |x, y, z|
        x -= 8
        z -= 0.5
        y -= 8
        z,y = y,-z if horizontal
        ctx.vert(
          position[0]+(x*cos-z*sin)/16.0*scale,
          position[1]+(-y/16.0)*scale,
          position[2]+(z*cos+x*sin)/16.0*scale
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

  class SharpmarkBlock
    def initialize texture
      BlockTextures.validate_texture! texture
      @texture = texture
    end
    def cube?
      false
    end
    def render ctx, pos
      position = ->(x,z){pos.zip([x, 0.5, z]).map{|a|a.inject :+}}
      BlockTextures.render_plane ctx, @texture, position: position[0.5,0.25+1/32.0], rotate: 0
      BlockTextures.render_plane ctx, @texture, position: position[0.5,0.75-1/32.0], rotate: 0
      BlockTextures.render_plane ctx, @texture, position: position[0.25+1/32.0,0.5], rotate: 90
      BlockTextures.render_plane ctx, @texture, position: position[0.75-1/32.0,0.5], rotate: 90
    end
  end

  class CrossBlock
    def initialize texture
      BlockTextures.validate_texture! texture
      @texture = texture
    end
    def cube?
      false
    end
    def render ctx, pos
      scale = Math.sqrt(2)*16/17
      position = pos.zip([0.5, 0.5*scale, 0.5]).map{|a,b|a+b}
      BlockTextures.render_plane ctx, @texture, position: position, rotate: 45, scale: scale
      BlockTextures.render_plane ctx, @texture, position: position, rotate: -45, scale: scale
    end
  end

  class FloorMountedBlock
    def initialize texture, dir: 0
      BlockTextures.validate_texture! texture
      @texture = texture
      @dir = dir
    end
    def cube?
      false
    end
    def render ctx, pos
      position = pos.zip([0.5, 0.5-7.5/16, 0.5]).map{|a,b|a+b}
      BlockTextures.render_plane ctx, @texture, position: position, horizontal: true, rotate: @dir*90
    end
  end

  class WallMountedBlock
    def initialize texture, dir: 0
      BlockTextures.validate_texture! texture
      @texture = texture
      @dir = dir
    end
    def cube?
      false
    end
    def render ctx, pos
      th = Math::PI*@dir/2
      position = pos.zip([0.5+Math.cos(th)*7.5/16, 0.5, 0.5+Math.sin(th)*7.5/16]).map{|a,b|a+b}
      BlockTextures.render_plane ctx, @texture, position: position, rotate: (@dir-1)*90
    end
  end

  class CubeBlock
    def initialize top, side=nil, bottom=nil
      @top = top
      @side = side || top
      @bottom = bottom || top
      BlockTextures.validate_texture! @top, @side, @bottom
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

  def self.validate_texture! *texture_ids
    texture_ids.each do |t|
      raise "invalid texture #{t}" unless @meta[t.to_s]
    end
  end

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
    camelize = ->s{s.split('_').map(&:capitalize).join}
    colors = %w(black blue brown cyan gray green light_blue lime magenta orange pink purple red silver white yellow).map{|c|
      [c, (c == 'silver' ? 'LightGray' : camelize[c])]
    }.to_h
    woods = {acacia: 'Acacia', big_oak: 'DarkOak', birch: 'Birch', jungle: 'Jungle', oak: 'Oak', spruce: 'Spruce'}
    defs = {}
    4.times.map do |i|
      defs[MCWorld::Block::BeetrootBlock[i]] = SharpmarkBlock.new "beetroots_stage_#{i}"
      defs[MCWorld::Block::Carrots[i]] = SharpmarkBlock.new "carrots_stage_#{i}"
      defs[MCWorld::Block::Potatoes[i]] = SharpmarkBlock.new "potatoes_stage_#{i}"
    end
    3.times.map do |i|
      defs[MCWorld::Block::NetherWart[i]] = SharpmarkBlock.new "nether_wart_stage_#{i}"
    end
    8.times.map do |i|
      defs[MCWorld::Block::WheatCrops[i]] = SharpmarkBlock.new "wheat_stage_#{i}"
    end
    defs[MCWorld::Block::SugarCanes] = CrossBlock.new 'reeds'
    defs[MCWorld::Block::Fern] = CrossBlock.new 'fern'
    defs[MCWorld::Block::TallGrass] = CrossBlock.new 'tallgrass'
    defs[MCWorld::Block::Dandelion] = CrossBlock.new 'flower_dandelion'
    defs[MCWorld::Block::BlueOrchid] = CrossBlock.new 'flower_blue_orchid'
    defs[MCWorld::Block::Allium] = CrossBlock.new 'flower_allium'
    defs[MCWorld::Block::RedTulip] = CrossBlock.new 'flower_tulip_red'
    defs[MCWorld::Block::OrangeTulip] = CrossBlock.new 'flower_tulip_orange'
    defs[MCWorld::Block::WhiteTulip] = CrossBlock.new 'flower_tulip_white'
    defs[MCWorld::Block::PinkTulip] = CrossBlock.new 'flower_tulip_pink'
    defs[MCWorld::Block::OxeyeDaisy] = CrossBlock.new 'flower_oxeye_daisy'
    defs[MCWorld::Block::Fire] = CrossBlock.new 'fire_layer_0'
    defs[MCWorld::Block::BrownMushroom] = CrossBlock.new 'mushroom_brown'
    defs[MCWorld::Block::OakSapling] = CrossBlock.new 'sapling_oak'
    defs[MCWorld::Block::SpruceSapling] = CrossBlock.new 'sapling_spruce'
    defs[MCWorld::Block::BirchSapling] = CrossBlock.new 'sapling_birch'
    defs[MCWorld::Block::JungleSapling] = CrossBlock.new 'sapling_jungle'
    defs[MCWorld::Block::AcaciaSapling] = CrossBlock.new 'sapling_acacia'
    defs[MCWorld::Block::DarkOakSapling] = CrossBlock.new 'sapling_roofed_oak'

    defs[MCWorld::Block::Bookshelf] = CubeBlock.new 'planks_oak', 'bookshelf', 'planks_oak'
    defs[MCWorld::Block::Bricks] = CubeBlock.new 'brick'
    defs[MCWorld::Block::Clay] = CubeBlock.new 'clay'
    defs[MCWorld::Block::BlockofCoal] = CubeBlock.new 'coal_block'
    #cobblestone_mossy
    defs[MCWorld::Block::Cobblestone] = CubeBlock.new 'cobblestone'
    defs[MCWorld::Block::CraftingTable] = CubeBlock.new 'crafting_table_top', 'crafting_table_side', 'planks_oak'
    defs[MCWorld::Block::Podzol] = CubeBlock.new 'dirt_podzol_top', 'dirt_podzol_side', 'dirt'
    defs[MCWorld::Block::Grass] = CubeBlock.new 'grass_top', 'grass_side', 'dirt'
    defs[MCWorld::Block::Dirt] = CubeBlock.new 'dirt'
    defs[MCWorld::Block::EndStoneBricks] = CubeBlock.new 'end_bricks'
    4.times do |i|
      defs[MCWorld::Block::FrostedIce[i]] = CubeBlock.new "frosted_ice_#{i}"
    end
    defs[MCWorld::Block::Glass] = CubeBlock.new 'glass'
    colors.each do |color, blockcolor|
      defs[MCWorld::Block.const_get "#{blockcolor}StainedGlass"] = CubeBlock.new "glass_#{color}"
    end
    defs[MCWorld::Block::HardenedClay] = CubeBlock.new 'hardened_clay'
    colors.each do |color, blockcolor|
      defs[MCWorld::Block.const_get "#{blockcolor}StainedClay"] = CubeBlock.new "hardened_clay_stained_#{color}"
    end
    defs[MCWorld::Block::HayBale] = CubeBlock.new 'hay_block_top', 'hay_block_side'
    defs[MCWorld::Block::Ice] = CubeBlock.new 'ice'
    defs[MCWorld::Block::Jukebox] = CubeBlock.new 'jukebox_top', 'jukebox_side'
    woods.each do |texname, blockname|
      defs[MCWorld::Block.const_get "#{blockname}Wood"] = CubeBlock.new "log_#{texname}_top", "log_#{texname}"
      defs[MCWorld::Block.const_get "#{blockname}WoodPlank"] = CubeBlock.new "planks_#{texname}"
    end
    defs[MCWorld::Block[213]] = CubeBlock.new 'magma'
    defs[MCWorld::Block::MelonBlock] = CubeBlock.new 'melon_top', 'melon_side'
    defs[MCWorld::Block::Mycelium] = CubeBlock.new 'mycelium_top', 'mycelium_side'
    defs[MCWorld::Block::NetherBrick] = CubeBlock.new 'mycelium_top', 'nether_brick'
    defs[MCWorld::Block[214]] = CubeBlock.new 'nether_wart_block'
    defs[MCWorld::Block[215]] = CubeBlock.new 'nether_wart_block'
    defs[MCWorld::Block::Prismarine] = CubeBlock.new 'prismarine_rough'
    #pumpkin
    defs[MCWorld::Block::PurpurPillar] = CubeBlock.new 'purpur_pillar_top', 'purpur_pillar'
    defs[MCWorld::Block::QuartzBlock] = CubeBlock.new 'quartz_block_top', 'quartz_block_side', 'quartz_block_bottom'
    defs[MCWorld::Block::ChiseledQuartzBlock] = CubeBlock.new 'quartz_block_chiseled_top', 'quartz_block_chiseled'
    defs[MCWorld::Block::PillarQuartzBlock] = CubeBlock.new 'quartz_block_lines_top', 'quartz_block_lines'
    defs[MCWorld::Block::RedSand] = CubeBlock.new 'red_sand'
    defs[MCWorld::Block::RedSandstone] = CubeBlock.new 'red_sandstone_top', 'red_sandstone_normal', 'red_sandstone_bottom'
    defs[MCWorld::Block::ChiseledRedSandstone] = CubeBlock.new 'red_sandstone_top', 'red_sandstone_carved', 'red_sandstone_bottom'
    defs[MCWorld::Block::SmoothRedSandstone] = CubeBlock.new 'red_sandstone_top', 'red_sandstone_smooth', 'red_sandstone_bottom'
    defs[MCWorld::Block::RedstoneLampOn] = CubeBlock.new 'redstone_lamp_on'

    defs[MCWorld::Block::Sand] = CubeBlock.new 'sand'
    defs[MCWorld::Block::Sandstone] = CubeBlock.new 'sandstone_top', 'sandstone_normal', 'sandstone_bottom'
    defs[MCWorld::Block::ChiseledSandstone] = CubeBlock.new 'sandstone_top', 'sandstone_carved', 'sandstone_bottom'
    defs[MCWorld::Block::SmoothSandstone] = CubeBlock.new 'sandstone_top', 'sandstone_smooth', 'sandstone_bottom'

    defs[MCWorld::Block::Snow] = CubeBlock.new 'snow'
    defs[MCWorld::Block::SoulSand] = CubeBlock.new 'soul_sand'
    defs[MCWorld::Block::Sponge] = CubeBlock.new 'sponge'
    defs[MCWorld::Block::Stone] = CubeBlock.new 'stone'
    defs[MCWorld::Block::SlimeBlock] = CubeBlock.new 'slime'
    defs[MCWorld::Block::Andesite] = CubeBlock.new 'stone_andesite'
    defs[MCWorld::Block::Granite] = CubeBlock.new 'stone_granite'
    defs[MCWorld::Block::Diorite] = CubeBlock.new 'stone_diorite'
    defs[MCWorld::Block::PolishedAndesite] = CubeBlock.new 'stone_andesite_smooth'
    defs[MCWorld::Block::PolishedGranite] = CubeBlock.new 'stone_granite_smooth'
    defs[MCWorld::Block::PolishedDiorite] = CubeBlock.new 'stone_diorite_smooth'
    defs[MCWorld::Block::StoneBricks] = CubeBlock.new 'stonebrick'
    defs[MCWorld::Block::MossyStoneBricks] = CubeBlock.new 'stonebrick_mossy'
    defs[MCWorld::Block::CrackedStoneBricks] = CubeBlock.new 'stonebrick_cracked'
    defs[MCWorld::Block::ChiseledStoneBricks] = CubeBlock.new 'stonebrick_carved'
    defs[MCWorld::Block::TNT] = CubeBlock.new 'tnt_top', 'tnt_side', 'tnt_bottom'
    colors.each do |color, blockcolor|
      defs[MCWorld::Block.const_get "#{blockcolor}Wool"] = CubeBlock.new "wool_colored_#{color}"
    end

    %w(oak iron spruce birch jungle acacia dark_oak).each do |type|
      wtype = type == 'oak' ? 'wood' : type
      4.times do |i|
        door = MCWorld::Block.const_get "#{camelize[type]}DoorBlock"
        defs[door[i]] = WallMountedBlock.new "door_#{wtype}_lower", dir: i
        defs[door[i+8]] = WallMountedBlock.new "door_#{wtype}_lower", dir: 3-i
        defs[door[i+4]] = WallMountedBlock.new "door_#{wtype}_upper", dir: i
        defs[door[i+12]] = WallMountedBlock.new "door_#{wtype}_upper", dir: 3-i
      end
    end

    require 'pry';binding.pry
    defs
  end
  Info = estimateds.merge overrides
end

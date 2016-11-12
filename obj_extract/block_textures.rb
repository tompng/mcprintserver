require_relative '../mc_world/world'
require 'json'
module BlockTextures
  def self.estimateds
    files = JSON.parse File.read('meta.json')
    MCWorld::Block::BlockDefinition.keys.map{|key|
      keywords = key.to_s.scan(/[A-Z][^A-Z]+/).map(&:downcase)
      matcheds = keywords.map{|kw|
        files.keys.select{|k|k.include?(kw)}
      }.reject(&:empty?)
      keys = matcheds.inject(:&)
      if keys&.size == 1
        [MCWorld::Block.const_get(key), keys.first]
      end
    }.compact.to_h
  end
  def self.overrides
    {
      MCWorld::Block::Dirt => 'dirt',
      MCWorld::Block::Stone => 'stone',
      MCWorld::Block::SlimeBlock => 'slime',
      MCWorld::Block::EndStoneBricks => 'end_bricks',
      MCWorld::Block::Andesite => 'stone_andesite',
      MCWorld::Block::Granite => 'stone_granite',
      MCWorld::Block::Diorite => 'stone_diorite',
      MCWorld::Block::PolishedAndesite => 'stone_andesite_smooth',
      MCWorld::Block::PolishedGranite => 'stone_granite_smooth',
      MCWorld::Block::PolishedDiorite => 'stone_diorite_smooth'
    }
  end
  Info = estimateds.merge overrides
end

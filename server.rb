#spigot入れる(build)
#worldedit worldguard入れる
require 'pry'
require 'json'
require 'yaml'

class Regions
  def initialize
    @areas = JSON.parse File.read('areas.json')
  end

  def register area_users
    @area_users = area_users
  end

  def area_regions index
    area = @areas[index]
    cx = area['print']['min']['x']/16
    cz = area['print']['min']['z']/16
    name = "area_#{cx}_#{cz}"
    regions = {}
    regions[name] = region(
      min: area['area']['min'],
      max: area['area']['max'],
      members: {players: [:tompng]},
      flags: {greeting: "Welcome to Area-#{cx}-#{cz}"},
      priority: 1
    )
    area_y = area['area']['min']['y']
    print_y = area['print']['min']['y']
    border_min = area['print']['min'].map{|k,v|[k,v-1]}.to_h
    border_max = area['print']['max'].map{|k,v|[k,v+1]}.to_h
    bedrocks = ->type,min,max{
      regions["#{name}_#{type}"] = region(
        min: min, max: max, owners: {groups: ['admins']}, priority: 2
      )
    }
    if area_y != print_y-1
      bedrocks.call :bed, border_min.merge('y' => area_y), border_max.merge('y' => print_y-1)
    end
    4.times do |i|
      x = [border_min, border_max][i%2]['x']
      z = [border_min, border_max][i/2]['z']
      bedrocks.call(
        "pole#{i}",
        {x: x, y: border_min['y']+1, z: z},
        {x: x, y: border_max['y'], z: z}
      )
    end
    top11 = border_max
    top00 = border_min.merge 'y' => border_max['y']
    top10 = border_max.merge 'z' => border_min['z']
    top01 = border_max.merge 'x' => border_min['x']
    bedrocks.call :top0, top00, top01
    bedrocks.call :top1, top00, top10
    bedrocks.call :top2, top10, top11
    bedrocks.call :top3, top01, top11
    regions
  end

  def save
    regions = {}
    @areas.each.with_index do |_, i|
      regions.merge! area_regions(i)
    end
    regions.merge! default_regions
    File.write 'spigot/plugins/WorldGuard/worlds/world/regions.yml', JSON.parse({regions: regions}.to_json).to_yaml
  end

  def region min: nil, max: nil, members: {}, flags: {}, deny: [], allow: [], type: 'cuboid', priority: 0, owners: {}
    shape = min && max ? {min: min, max: max, type: 'cuboid'} : {type: 'global'}
    shape.merge(
      members: members,
      flags: flags.merge((deny.map{|name|[name, 'deny']}+allow.map{|name|[name, 'allow']}).to_h),
      priority: priority,
      owners: owners
    )
  end

  def default_regions
    {
      map: region(
        min: {x: -64, y: 0, z: -64},
        max: {x: 576, y: 512, z: 576},
        deny: %w(exit)
      ),
      __global__: region(
        deny: %w(enderman-grief enderpearl chorus-fruit-teleport mob-spawning pvp item-drop),
        owners: {groups: ['admins']}
      )
    }
  end
end

class Server
  def initialize
    @cv = ConditionVariable.new
    @mutex = Mutex.new
    @saved = Time.now
    Dir.chdir 'minecraft_server' do
      @io = IO.popen 'java -jar minecraft_server.1.10.2.jar nogui', 'r+'
      at_exit { @io.close }
    end
    Thread.new do
      loop do
        s = @io.gets
        puts s
        Process.exit if s.nil?
        Thread.new{signal_update { @saved = Time.now } if s =~ /Saved/}
      end
    end
  end

  def save
    time = Time.now
    command 'save-all'
    wait_until { @saved > time }
  end

  def command msg
    @io.puts msg
  end

  private
  def signal_update &block
    @mutex.synchronize do
      block.call
      @cv.signal
    end
  end

  def wait_until &block
    @mutex.synchronize do
      @cv.wait @mutex until block.call
    end
  end

end

# s=Server.new
Regions.new.save
# binding.pry
exit
p 1

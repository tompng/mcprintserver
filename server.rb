#spigot入れる(build)
#worldedit worldguard入れる
require 'pry'
require 'json'
require 'sinatra'
require 'yaml'
require './stl_extract'
require './obj_extract/obj_extract'
class Regions
  def initialize
    @areas = JSON.parse File.read('areas.json')
    @area_users = {}
    @areas.each do |area|
      cx = area['print']['min']['x']/16
      cz = area['print']['min']['z']/16
      @area_users["#{cx}_#{cz}"]=[]
    end
  end

  def areas_by_user user
    @area_users.select{|name, users| users.include? user}.keys.map{|key|area key}
  end

  def area id
    @areas.find do |area|
      "#{area['print']['min']['x']/16}_#{area['print']['min']['z']/16}" == id
    end
  end

  def area_users
    @area_users
  end

  def register key, users
    @area_users[key] = users if @area_users[key]
  end

  def area_position id
    area = area id
    return unless area
    min = area['print']['min']
    max = area['print']['max']
    {
      x: (min['x']+max['x'])/2,
      z: (min['z']+max['z'])/2,
      y: max['y']+10
    }
  end

  def area_regions area
    cx = area['print']['min']['x']/16
    cz = area['print']['min']['z']/16
    name = "area_#{cx}_#{cz}"
    regions = {}
    players = @area_users["#{cx}_#{cz}"]
    message = "Area-#{cx}-#{cz}"
    message += " (#{players.join ', '})" unless players.empty?
    regions[name] = region(
      min: area['area']['min'],
      max: area['area']['max'],
      members: {players: players},
      flags: {greeting: message},
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
    @areas.each do |area|
      regions.merge! area_regions(area)
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
    @watch = {}
    @command_queue = Queue.new
    @mutex = Mutex.new
    Dir.chdir 'spigot' do
      old_pid = `pgrep -f spigot`.to_i
      `kill -INT #{old_pid}` if old_pid > 0
      @io = IO.popen 'java -jar spigot-1.10.2.jar nogui', 'r+'
      at_exit { @io.close }
    end
    Thread.new do
      begin
      loop do
        msg, block, callback = @command_queue.deq
        callback << [_command(msg, &block)]
      end
      rescue=>e
        p e
      ensure
        p :error
        Process.exit
      end
    end
    Thread.new do
      begin
        loop do
          s = @io.gets
          puts s
          @watch.each do |pattern, block|
            Thread.new{block.call s} if pattern =~ s
          end
          Process.exit if s.nil?
          @mutex.synchronize do
            @queue << s if @queue
          end
        end
      rescue => e
        p e
      ensure
        p :error
        begin;@io.close;rescue=>e;end
        Process.exit
      end
    end
  end

  def on pattern, &block
    @watch[pattern] = block
  end

  def save
    command 'save-all', /^\[[^\]]+\]: Saved the world/
  end

  def rg_reload
    command 'rg reload', /^\[[^\]]+\]: Successfully load the region data for all worlds\./
  end

  def tp name, x:, y: 80, z:
    command "tp #{name} #{x} #{y} #{z}", /^\[[^\]]+\]: (Teleported|The entity UUID provided is in an invalid format)/
  end

  def command msg, pattern=nil, &block
    block = ->s{pattern.match s} if pattern
    cb = Queue.new
    @command_queue << [msg, block, cb]
    cb.deq
  end

  private

  def _command msg, &block
    p :exec_cmd
    @mutex.synchronize do
      @queue = Queue.new
    end
    @io.puts msg
    result = nil
    loop do
      result = block.call @queue.deq
      break if result
    end
    @mutex.synchronize do
      @queue = nil
    end
    p :exec_done
    result
  end
end


regions = Regions.new
server = Server.new
server.on /\[[^\]]+\]: UUID of player/ do |line|
  begin
  next unless /UUID of player (?<name>[a-zA-Z0-9_-]+)/ =~ line
  areas = regions.areas_by_user name
  if areas.size==1
    print_area = areas.first['print']
    server.tp(
      name,
      x: (print_area['min']['x']+print_area['max']['x'])/2,
      z: (print_area['min']['z']+print_area['max']['z'])/2,
      y: print_area['max']['y']+8,
    )
  else
    server.tp name, x: 290, z: 275, y: 80
  end
  rescue=>e
    p 'login hook error'
    p e.backtrace
  end
end

set :public_folder, './public'

user_list_op = lambda do |area_id, user_id, add:|
  next unless user_id =~ /\A[a-zA-Z0-9_-]+\z/
  users = regions.area_users[area_id]
  if add
    users |= [user_id]
  else
    users -= [user_id]
  end
  regions.register area_id, users
  regions.save
  server.tp user_id, regions.area_position(area_id) if add
  server.rg_reload
end

post '/tp' do
  user_id = params[:user_id]
  next unless user_id =~ /\A[a-zA-Z0-9_-]+\z/
  pos = regions.area_position params[:area_id]
  server.tp user_id, pos if pos
  content_type :json
  pos.to_json
end

get '/user_list' do
  content_type :json
  regions.area_users.to_json
end

post '/user_list_add' do
  user_list_op.call params[:area_id], params[:user_id], add: true
  content_type :json
  regions.area_users.to_json
end

post '/user_list_remove' do
  user_list_op.call params[:area_id], params[:user_id], add: false
  content_type :json
  regions.area_users.to_json
end

get '/obj' do
  area = regions.area params[:area_id]
  next unless area
  server.save
  sleep 4
  OBJExtract.new('spigot/world/region/r.0.0.mca').extract(
    *%w(x y z).map{|axis|area['print']['min'][axis]},
    *%w(x y z).map{|axis|area['print']['max'][axis]}
  )
end

get '/stl' do
  area = regions.area params[:area_id]
  next unless area
  server.save
  sleep 4
  STLExtract.new('spigot/world/region/r.0.0.mca').extract(
    *%w(x y z).map{|axis|area['print']['min'][axis]},
    *%w(x y z).map{|axis|area['print']['max'][axis]}
  )
end

Sinatra::Application.run!

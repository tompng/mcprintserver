require 'pry'
require 'chunky_png'
require './mc_world/world'

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
    @io.puts 'save-all'
    wait_until { @saved > time }
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

def load_world
  MCWorld::World.new file: 'minecraft_server/world/region/r.0.0.mca'
end

def image
  world = load_world
  haschunk = {}
  img = ChunkyPNG::Image.new 512, 512
end

s=Server.new
binding.pry
p 1

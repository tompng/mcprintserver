#spigot入れる(build)
#worldedit worldguard入れる
require 'pry'
require 'json'

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

s=Server.new
binding.pry
p 1

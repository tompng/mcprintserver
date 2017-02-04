class Mcapi
  def self.teleport
  end

  def self.ip
    ENV['MCPRINT_SERVER_IP'] || 'localhost'
  end

  def self.endpoint path=nil
    "http://#{ip}:4567/#{path}"
  end

  def self.objfile i, j
    api_get "obj?area_id=#{i}_#{j}"
  end

  def self.user_list
    JSON.parse api_get('user_list')
  end

  def self.mcmap
    @map ||= api_get 'mcmap.png'
  end

  def self.update_user_list list
  end

  private

  def self.api_get path
    Net::HTTP.get URI.parse(endpoint(path))
  end
end

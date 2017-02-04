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
    api_get 'obj', area_id: "#{i}_#{j}"
  end

  def self.user_list
    JSON.parse api_get('user_list')
  end

  def self.teleport area_id:, username:
    api_post 'tp', area_id: area_id, user_id: username
  end

  def self.mcmap
    @map ||= api_get 'mcmap.png'
  end

  def self.update_user_list userlist
    api_post 'user_list', user_list: userlist
  end

  private

  def self.register
    url = "http://#{ENV['SERVER_HOSTNAME'] || 'localhost:3000'}/areas/user_list"
    api_post 'register', fetch_url: url
  end

  def self.token
    ENV['MCPRINT_SERVER_TOKEN'] || 'dev_token'
  end

  def self.api_get path, params={}
    path += "?#{params.merge(_token: token).to_param}"
    Net::HTTP.get URI.parse(endpoint(path))
  end

  def self.api_post path, params={}
    Net::HTTP.post(
      URI.parse(endpoint(path)),
      params.merge(_token: token).to_json,
      content_type: 'application/json'
    )
  end
end

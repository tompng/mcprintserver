class Area < ActiveRecord::Base
  has_many :demo_accounts, inverse_of: :area, dependent: :destroy

  def self.prepare
    coords = load_data.keys.map { |k| k.split('_') }
    areas = coords.map do |i, j|
      Area.where(coord_i: i, coord_j: j).first_or_create
    end
    Area.where.not(id: areas).destroy_all
  end

  def self.load_data
    JSON.parse Net::HTTP.get URI.parse('http://localhost:4567/user_list')
  end
end

class Area < ActiveRecord::Base
  has_many :demo_accounts, inverse_of: :area, dependent: :destroy

  def add_demo_account name
    demo_accounts.where(username: name).first_or_create
    reload
    demo_accounts.min_by(&:id).first.destroy if demo_accounts.count > 4
  end

  def remove_demo_account name
    demo_accounts.where(username: name).destroy_all
  end


  def self.prepare
    coords = load_data.keys.map { |k| k.split('_').map(&:to_i) }
    existing_areas = Area.all.index_by { |a| [a.coord_i, a.coord_j] }
    areas = coords.map do |i, j|
      existing_areas[[i,j]] || Area.create(coord_i: i, coord_j: j)
    end
    Area.where.not(id: areas).destroy_all
  end

  def self.load_data
    JSON.parse Net::HTTP.get URI.parse('http://localhost:4567/user_list')
  end
end

class Area < ActiveRecord::Base
  has_many :demo_accounts, inverse_of: :area, dependent: :destroy
  has_one :area_cached_obj, inverse_of: :area, dependent: :destroy
  USERS_PER_AREA = 4

  def to_param
    "#{coord_i}_#{coord_j}"
  end

  def usernames
    demo_accounts.map &:username
  end

  def add_demo_account name
    demo_account = demo_accounts.where(username: name).first_or_create
    user_accounts = DemoAccount.where(username: name).order(id: :asc).to_a
    user_accounts.shift.destroy while user_accounts.size > 1
    area_accounts = reload.demo_accounts.order(id: :asc).to_a
    area_accounts.shift.destroy while area_accounts.size > USERS_PER_AREA
    Area.notify_update
    demo_account
  end

  def remove_demo_account name
    demo_accounts.where(username: name).destroy_all
    Area.notify_update
  end

  def self.user_list
    Area.includes(:demo_accounts).map { |a|
      [a.to_param, a.usernames]
    }.sort_by(&:first).to_h
  end

  def self.notify_update
    Mcapi.update_user_list user_list
  end

  def self.prepare
    coords = Mcapi.user_list.keys.map { |k| k.split('_').map(&:to_i) }
    existing_areas = Area.all.index_by { |a| [a.coord_i, a.coord_j] }
    areas = coords.map do |i, j|
      existing_areas[[i,j]] || Area.create(coord_i: i, coord_j: j)
    end
    Area.where.not(id: areas).destroy_all
  end
end

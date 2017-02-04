class DemoAccount < ActiveRecord::Base
  belongs_to :area, inverse_of: :demo_accounts
  validates :username, format: { with: /\A[a-zA-Z0-9_.-]+\z/ }, length: { maximum: 32 }
  before_validation on: :create do
    api_response = Net::HTTP.get URI.parse("https://api.mojang.com/users/profiles/minecraft/#{username}")
    errors[:username] << 'not in mojang' unless api_response
  end
end

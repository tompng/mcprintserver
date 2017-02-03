class DemoAccount < ActiveRecord::Base
  belongs_to :area, inverse_of: :demo_accounts
  validates :username, format: { with: /\A[a-zA-Z0-9_.-]+\z/ }, length: { maximum: 32 }
end

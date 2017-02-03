class DemoAccount < ActiveRecord::Base
  belongs_to :area, inverse_of: :demo_accounts
end

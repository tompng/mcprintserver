class AreaCachedObj < ActiveRecord::Base
  belongs_to :area, inverse_of: :area_cached_obj
end

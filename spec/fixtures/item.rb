class Item < ActiveRecord::Base
  references_by_array :tags, :validate=>true
end

atcbd = ActiveRecord::AttributeMethods::Read::ATTRIBUTE_TYPES_CACHED_BY_DEFAULT

atcbd << /_array$/
def atcbd.include?(val)
  any?{|type| type === val}
end

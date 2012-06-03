ar_am = ActiveRecord::AttributeMethods
atcbd = ActiveRecord::VERSION::MAJOR < 3 ?
    ar_am::ATTRIBUTE_TYPES_CACHED_BY_DEFAULT :
    ar_am::Read::ATTRIBUTE_TYPES_CACHED_BY_DEFAULT

atcbd << /_array$/
def atcbd.include?(val)
  any?{|type| type === val}
end

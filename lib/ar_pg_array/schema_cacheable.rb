adjust_cached_types = lambda do |atcbd|
  atcbd << /_array$/
  def atcbd.include?(val)
    any?{|type| type === val}
  end
end
if ActiveRecord::VERSION::MAJOR < 3
  adjust_cached_types.call(ActiveRecord::AttributeMethods::ATTRIBUTE_TYPES_CACHED_BY_DEFAULT)
else
  adjust_cached_types.call(ActiveRecord::AttributeMethods::Read::ATTRIBUTE_TYPES_CACHED_BY_DEFAULT)
end

module ActiveRecord
  module Dirty
    private
      def attribute_will_change!(attr)
        val = changed_attributes[attr] = clone_attribute_value(:read_attribute, attr)
        if Array === val && !(Array === @attributes[attr])
          send(attr) unless @attributes_cache.has_key?(attr)
          @attributes[attr] = @attributes_cache[attr]
        end
        val
      end
  end
end

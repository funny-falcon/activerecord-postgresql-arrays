module Arel
  module Attributes
    %w{Integer Float Decimal Boolean String Time}.each do |basetype|
      module_eval <<-"END"
        class #{basetype}Array < Attribute
        end
      END
    end
  end

  module Attributes
    class << self
      def for_with_postgresql_arrays(column)
        if column.type.to_s =~ /^(.+)_array$/
          ('Arel::Attributes::' + for_without_postgresql_arrays(column.base_column).name.split('::').last + 'Array').constantize
        else
          for_without_postgresql_arrays(column)
        end
      end
      alias_method_chain :for, :postgresql_arrays
    end
  end
end

module ActiveRecord
  class << Base
    if method_defined?(:column_defaults)
      alias column_defaults_without_extradup column_defaults
      def column_defaults_with_extradup
        res = {}
        column_defaults_without_extradup.each{|k, v|
          res[k] = Array === v ? v.dup : v
        }
        res
      end
      def column_defaults
        defaults = column_defaults_without_extradup
        if defaults.values.grep(Array).empty?
          alias column_defaults column_defaults_without_extradup
        else
          alias column_defaults column_defaults_with_extradup
        end
        column_defaults
      end
    end
  end
end

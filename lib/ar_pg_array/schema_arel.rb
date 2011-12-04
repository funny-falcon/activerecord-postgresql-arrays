module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def prepare_for_arel( value, column )
        return value unless value
        if Array === value && "#{column.type}" =~ /^(.+)_array$/
          prepare_array_for_arel_by_base_type(value, $1)
        else
          super
        end
      end
    end
  end
end

module ActiveRecord
  # I hope ticket 5047 will be included in Rails 3 reliz
  unless ConnectionAdapters::AbstractAdapter.method_defined? :prepare_for_arel
    module ConnectionAdapters
      class AbstractAdapter
        def prepare_for_arel( value, column )
          if value && (value.is_a?(Hash) || value.is_a?(Array))
            value.to_yaml
          else
            value
          end
        end
      end
    end
  
    class Base
      private
      # Returns a copy of the attributes hash where all the values have been safely quoted for use in
      # an Arel insert/update method.
      def arel_attributes_values(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
        attrs = {}
        attribute_names.each do |name|
          if (column = column_for_attribute(name)) && (include_primary_key || !column.primary)
  
            if include_readonly_attributes || (!include_readonly_attributes && !self.class.readonly_attributes.include?(name))
              value = read_attribute(name)
  
              if value && self.class.serialized_attributes.has_key?(name) && (value.acts_like?(:date) || value.acts_like?(:time))
                value = value.to_yaml
              else
                value = self.class.connection.prepare_for_arel(value, column)
              end
              attrs[self.class.arel_table[name]] = value
            end
          end
        end
        attrs
      end    
    end
  end
end

module Arel
  module Attributes
    %w{Integer Float Decimal Boolean String Time}.each do |basetype|
      module_eval <<-"END"
        class #{basetype}Array < Attribute
        end
      END
    end
  end

  if Arel::VERSION < '2.0'
    module Sql
      module Attributes
        class << self
          def for_with_postgresql_arrays(column)
            if column.type.to_s =~ /^(.+)_array$/
              ('Arel::Sql::Attributes::' + for_without_postgresql_arrays(column.base_column).name.split('::').last + 'Array').constantize
            else
              for_without_postgresql_arrays(column)
            end
          end
          alias_method_chain :for, :postgresql_arrays
        end
        
        %w{Integer Float Decimal Boolean String Time}.each do |basetype|
          module_eval <<-"END"
            class #{basetype}Array < Arel::Attributes::#{basetype}Array
              include Attributes
            end
          END
        end
      end
    end
  else
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
    module Visitors
      class PostgreSQL
        def quote s, column = nil
          "E#{super}"
        end
      end
    end
  end
end

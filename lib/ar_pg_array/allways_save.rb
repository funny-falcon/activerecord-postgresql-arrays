module ActiveRecord
    module CheckArrayBeforeUpdate
      def mark_arrays_for_update
        @attributes_cache.each do |name, value|
          attribute_will_change!(name) if Array === value && _read_attribute(name) != value
        end
      end
    end
  if VERSION::MAJOR < 3
    module CheckArrayBeforeUpdate
      def self.included(base)
        base.alias_method_chain :update, :check_array
        base.send(:alias_method, :_read_attribute, :read_attribute)
      end

      def update_with_check_array
        mark_arrays_for_update
        update_without_check_array
      end
    end
  else
    module CheckArrayBeforeUpdate
      include ActiveSupport::Concern

      if VERSION::MAJOR == 3 && VERSION::MINOR >= 2
        def _read_attribute(attr_name)
          column_for_attribute(attr_name).type_cast(@attributes[attr_name])
        end
      end

      def update(*)
        mark_arrays_for_update
        super
      end
    end
  end
  Base.__send__ :include, CheckArrayBeforeUpdate
end

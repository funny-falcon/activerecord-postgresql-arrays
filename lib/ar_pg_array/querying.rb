module ActiveRecord
  class Base
    class << self
      if private_method_defined? :attribute_condition
        def attribute_condition_with_postgresql_arrays(quoted_column_name, argument)
          if ::PGArrays::PgArray === argument
            case argument
              when ::PGArrays::PgAny then      "#{quoted_column_name} && ?"
              when ::PGArrays::PgAll then      "#{quoted_column_name} @> ?"
              when ::PGArrays::PgIncludes then "#{quoted_column_name} <@ ?"
              else "#{quoted_column_name} = ?"
            end
          else
            attribute_condition_without_postgresql_arrays(quoted_column_name, argument)
          end
        end
        alias_method_chain :attribute_condition, :postgresql_arrays
      end
      
      def quote_bound_value_with_postgresql_arrays(value)
        if ::PGArrays::PgArray === value
          connection.quote_array_by_base_type(value, value.base_type)
        else
          quote_bound_value_without_postgresql_arrays(value)
        end
      end                                              
      alias_method_chain :quote_bound_value, :postgresql_arrays
    end
  end
end

module PGArrays
  class PgArray < Array
    attr_reader :base_type
    
    def initialize(array, type=nil)
      super(array)
      @base_type = type if type
    end
    
    def base_type
      @base_type || :other
    end
  end
  
  class PgAny < PgArray; end
  class PgAll < PgArray; end
  class PgIncludes < PgArray; end
  
  if defined? CanCan::Ability
    class PgAny
      def include?(v)
        Array === v && !( v & self ).empty?
      end
    end
  
    class PgAll
      def include?(v)
        Array === v && (self - v).empty?
      end
    end

    class PgIncludes < PgArray
      def include?(v)
        Array === v && (v - self).empty?
      end
    end
  end
end

class Array
  
  def pg(type=nil)
    ::PGArrays::PgArray.new(self, type)
  end
  
  def search_any(type=nil)
    ::PGArrays::PgAny.new(self, type)
  end
  
  def search_all(type=nil)
    ::PGArrays::PgAll.new(self, type)
  end
  
  def search_subarray(type=nil)
    ::PGArrays::PgIncludes.new(self, type)
  end
end

require 'pg_array_schema'

module ActiveRecord
  class Base
    class << self
      unless defined? ::Arel
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

if defined? ::Arel
  module Arel
    module Attributes
      class IntegerArray < Attribute
        def type_cast(value)
          i = Integer.allocate
          return unless value && !value.is_a?(Array)
          value.tr('{}','').split(',').map{|v| i.typecast(v)}
        end
      end
    end
  
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
        
        class IntegerArray < Arel::Attributes::IntegerArray
          include Attributes
        end
      end
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
    def to_sql
      ActiveRecord::Base.quote_bound_value(self)
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
      def include?
        Array === v && (self - v).empty?
      end
    end

    class PgIncludes < PgArray
      def include?
        Array === v && (v - self).empty?
      end
    end
  end
  
  if defined? ::Arel
    class PgArray
      Adapter = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      def to_sql( formatter = nil )
        formatter.engine.quote_array_for_arel_by_base_type(self, base_type)
      end
      
      def to_a
        self
      end
    end
  end
end

if defined? Arel
  module Arel
    module Predicates
      class ArrayAny < Binary
        def predicate_sql
          "&&"
        end
      end
      
      class ArrayAll < Binary
        def predicate_sql
          "@>"
        end
      end
      
      class ArrayIncludes < Binary
        def predicate_sql
          "<@"
        end
      end
    end
    
    class Attribute
      module Predications
        def ar_any(other)
          Predicates::ArrayAny.new(self, other)
        end
        def ar_all(other)
          Predicates::ArrayAll.new(self, other)
        end
        def ar_included(other)
          Predicates::ArrayIncludes.new(self, other)
        end
        
        def in(other)
          case other
          when ::PGArrays::PgAny
            ar_any(other)
          when ::PGArrays::PgAll
            ar_all(other)
          when ::PGArrays::PgIncludes
            ar_included(other)
          else
            Predicates::In.new(self, other)
          end
        end
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

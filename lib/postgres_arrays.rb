# PostgresArrays
require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLColumn < Column #:nodoc:
      BASE_TYPE_COLUMNS = Hash.new{|h, base_type| 
        base_column= new(nil, nil, base_type, true)
        h[base_type] = h[base_column.type]= base_column
      }
      attr_reader :base_type_column
    
      def initialize(name, default, sql_type = nil, null = true)
        if sql_type =~ /^(.+)\[\]$/
          @base_sql_type = $1
          @base_column = BASE_TYPE_COLUMNS[@base_sql_type]
        end
        super(name, self.class.extract_value_from_default(default), sql_type, null)
      end
      
      def simplified_type_with_postgresql_arrays(field_type)
        if field_type=~/^(.+)\[\]$/
          :"#{simplified_type_without_postgresql_arrays($1)}_array"
        else
          simplified_type_without_postgresql_arrays(field_type)
        end
      end
      alias_method_chain :simplified_type, :postgresql_arrays

      def klass
        if type.to_s =~ /_array$/
          Array
        else
          super
        end
      end

      def type_cast(value)
        return nil if value.nil?
        case type
          when :integer_array, :float_array then self.class.string_to_num_array(value)
          when :decimal_array, :date_array, :boolean_array
            safe_string_to_array(value)
          when :timestamp_array, :time_array, :datetime_array, :binary_array
            string_to_array(value)
          when :text_array, :string_array then self.class.string_to_text_array(value)
          else super
        end
      end
      
      def type_cast_code(var_name)
        case type
          when :integer_array, :float_array
            "#{self.class.name}.string_to_num_array(#{var_name})"
          when :decimal_array, :date_array, :boolean_array
            "#{self.class.name}.safe_string_to_array(#{var_name}, #{@base_sql_type.inspect})"
          when :timestamp_array, :time_array, :datetime_array, :binary_array
            "#{self.class.name}.string_to_array(#{var_name}, #{@base_sql_type.inspect})"
          when :text_array, :string_array
            "#{self.class.name}.string_to_text_array(#{var_name})"
          else super
        end
      end
      
      def safe_string_to_array(string)
        return string unless string.is_a? String
        return nil if string.empty?
        
        string[1...-1].split(',').map{|v| @base_column.type_cast(v)}
      end
      
      def string_to_array(string)
        return string unless string.is_a? String
        return nil if string.empty?
        
        self.class.string_to_text_array(string).map{|v| @base_column.type_cast(v)}
      end
      
      def self.safe_string_to_array(string, sql_type)
        return string unless string.is_a? String
        return nil if string.empty?
        
        base_column = BASE_TYPE_COLUMNS[sql_type]
        string[1...-1].split(',').map{|v| base_column.type_cast(v)}
      end
      
      def self.string_to_array(string, sql_type)
        return string unless string.is_a? String
        return nil if string.empty?

        base_column = BASE_TYPE_COLUMNS[sql_type]
        string_to_text_array( string ).map{|v| base_column.type_cast(v)}
      end
      
      def self.string_to_num_array(string)
        return string unless string.is_a? String
        return nil if string.empty?
        
        eval(string.tr('{}','[]'))
      end
      
      SARRAY_QUOTED = /^"(.*[^\\])?"$/m
      SARRAY_PARTIAL = /^".*(\\"|[^"])$/m
      def self.string_to_text_array(value)
        return value unless value.is_a? String
        return nil if value.empty?
        
        values = value[1...-1].split(',')
        partial = false
        values.inject([]) do |res, s|
          if partial
            s = res.pop << ",#{s}"
          elsif s=~ SARRAY_PARTIAL
            partial = true
          end
          if s =~ SARRAY_QUOTED
            s = eval(s)
            partial = false
          elsif s == 'NULL'
            s = nil
          end
          res << s
        end
      end
    end
    
    class PostgreSQLAdapter < AbstractAdapter
      def quote_with_postgresql_arrays(value, column = nil)
        if Array === value && column && "#{column.type}" =~ /^(.+)_array$/
          quote_array_by_base_type(value, $1)
        else
          quote_without_postgresql_arrays(value, column = nil)
        end
      end
      alias_method_chain :quote, :postgresql_arrays
      
      def quote_array_by_base_type(value, base_type, column = nil)
        case base_type.to_sym
          when :integer        then quote_pg_integer_array(value)
          when :float          then quote_pg_float_array(value)
          when :string, :text, :other then quote_pg_text_array(value)
          when :decimal, :boolean, :date, :safe then quote_pg_string_safe_array(value)
          else quote_pg_string_array(value, base_type, column)
        end
      end
      
      def quote_pg_integer_array(value)
        "'{#{ value.map{|v| v.nil? ? 'NULL' : v.to_i}.join(',')}}'"
      end
      
      def quote_pg_float_array(value)
        "'{#{ value.map{|v| v.nil? ? 'NULL' : v.to_f}.join(',')}}'"
      end
      
      def quote_pg_string_safe_array(value)
        "'{#{ value.map{|v| v.nil? ? 'NULL' : v.to_s}.join(',')}}'"
      end
      
      def quote_pg_string_array(value, base_type, column=nil)
        base_type_column= if column
                            column.base_type_column
                          else
                            PostgreSQLColumn::BASE_TYPE_COLUMNS[base_type.to_sym]
                          end
        value = value.map do|v| 
            v = quote_without_postgresql_arrays(v, base_type_column)
            if v=~/^E?'(.+)'$/ then v = $1 end
            "\"#{v.gsub('"','\"')}\""
        end
        "'{#{ value.join(',')}}'"
      end
      
      def quote_pg_text_array(value)
        value = value.map{|v|
             v ? (v = quote_string(v.to_s); v.gsub!('"','\"'); v) : 'NULL'
          }.inspect
        value.tr!('[]','{}')
        "E'#{value}'"
      end
      
      NATIVE_DATABASE_TYPES.keys.each do |key|
        unless key==:primary_key
          base = NATIVE_DATABASE_TYPES[key].dup
          base[:name] = base[:name]+'[]'
          NATIVE_DATABASE_TYPES[:"#{key}_array"]= base
          TableDefinition.class_eval <<-EOV
            def #{key}_array(*args)                                             # def string_array(*args)
              options = args.extract_options!                                   #   options = args.extract_options!
              column_names = args                                               #   column_names = args
                                                                                #
              column_names.each { |name| column(name, '#{key}_array', options) }#   column_names.each { |name| column(name, 'string_array', options) }
            end                                                                 # end
          EOV
        end
      end
      
      def type_to_sql_with_postgresql_arrays(type, limit = nil, precision = nil, scale = nil)
        if type.to_s =~ /^(.+)_array$/
          type_to_sql_without_postgresql_arrays($1, limit, precision, scale)+'[]'
        else
          type_to_sql_without_postgresql_arrays(type, limit, precision, scale)
        end
      end
      
      alias_method_chain :type_to_sql, :postgresql_arrays
    end
  end
  
  class Base
    class << self
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
  
  class PgAny < PgArray
    # this is for cancan
    if defined? CanCan::Ability
      def include?(v)
        Array === v && !( v & self ).empty?
      end
    end
  end
  
  class PgAll < PgArray
    if defined? CanCan::Ability
      def include?
        Array === v && (self - v).empty?
      end
    end
  end

  class PgIncludes < PgArray
    if defined? CanCan::Ability
      def include?
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


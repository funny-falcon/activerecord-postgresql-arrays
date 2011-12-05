if Arel::VERSION >= '2.0'
  module Arel
    module Nodes
      class ArrayAny < Arel::Nodes::Binary
      end

      class ArrayAll < Arel::Nodes::Binary
      end

      class ArrayIncluded < Arel::Nodes::Binary
      end
    end

    module Predications
      def ar_any other
        Nodes::ArrayAny.new self, other
      end

      def ar_all other
        Nodes::ArrayAll.new self, other
      end

      def ar_included other
        Nodes::ArrayIncluded.new self, other
      end
    end

    module Visitors
      class PostgreSQL
        def visit_Arel_Nodes_ArrayAny o
          "#{visit o.left} && #{visit o.right}"
        end

        def visit_Arel_Nodes_ArrayAll o
          "#{visit o.left} @> #{visit o.right}"
        end

        def visit_Arel_Nodes_ArrayIncluded o
          "#{visit o.left} <@ #{visit o.right}"
        end

        def visit_PGArrays_PgArray o
          @connection.quote_array_for_arel_by_base_type(o, o.base_type)
        end

        alias :visit_PGArrays_PgAny :visit_PGArrays_PgArray
        alias :visit_PGArrays_PgAll :visit_PGArrays_PgArray
        alias :visit_PGArrays_PgIncluded :visit_PGArrays_PgArray
      end
    end
  end
else
  module Arel
    module Predicates
      class ArrayAny < Binary
        def eval(row)
          !(operand1.eval(row) & operand2.eval(row)).empty?
        end
      
        def predicate_sql
          "&&"
        end
      end
      
      class ArrayAll < Binary
        def eval(row)
          (operand2.eval(row) - operand1.eval(row)).empty?
        end
        
        def predicate_sql
          "@>"
        end
      end
      
      class ArrayIncluded < Binary
        def eval(row)
          (operand1.eval(row) - operand2.eval(row)).empty?
        end
        
        def predicate_sql
          "<@"
        end
      end
    end
    
    class Attribute
      methods = lambda do
        def ar_any(other)
          Predicates::ArrayAny.new(self, other)
        end
        
        def ar_all(other)
          Predicates::ArrayAll.new(self, other)
        end
        
        def ar_included(other)
          Predicates::ArrayIncluded.new(self, other)
        end
      end
      if defined? PREDICATES
        PREDICATES.concat [:ar_any, :ar_all, :ar_included]
        class_exec &methods
      else
        Predications.class_exec &methods
      end
    end
  end

  module PGArrays
    class PgArray
      def to_sql( formatter = nil )
        formatter.engine.connection.quote_array_for_arel_by_base_type(self, base_type)
      end
      
      def to_a
        self
      end
    end
  end
end

if ActiveRecord::VERSION::STRING < '3.1'
  module ActiveRecord
    class PredicateBuilder
      def build_from_hash(attributes, default_table)
        predicates = attributes.map do |column, value|
          table = default_table

          if value.is_a?(Hash)
            table = Arel::Table.new(column, :engine => @engine)
            build_from_hash(value, table)
          else
            column = column.to_s

            if column.include?('.')
              table_name, column = column.split('.', 2)
              table = Arel::Table.new(table_name, :engine => @engine)
            end

            attribute = table[column] || Arel::Attribute.new(table, column)

            case value
            when PGArrays::PgAny
              attribute.ar_any(value)
            when PGArrays::PgAll
              attribute.ar_all(value)
            when PGArrays::PgIncludes
              attribute.ar_included(value)
            when Array, ActiveRecord::Associations::AssociationCollection, ActiveRecord::Relation
              values = value.to_a.map { |x|
                x.is_a?(ActiveRecord::Base) ? x.id : x
              }
              attribute.in(values)
            when Range, Arel::Relation
              attribute.in(value)
            when ActiveRecord::Base
              attribute.eq(value.id)
            when Class
              # FIXME: I think we need to deprecate this behavior
              attribute.eq(value.name)
            else
              attribute.eq(value)
            end
          end
        end

        predicates.flatten
      end
    end
  end
else
  module ActiveRecord
    class PredicateBuilder
      def self.build_from_hash(engine, attributes, default_table)
        predicates = attributes.map do |column, value|
          table = default_table

          if value.is_a?(Hash)
            table = Arel::Table.new(column, engine)
            build_from_hash(engine, value, table)
          else
            column = column.to_s

            if column.include?('.')
              table_name, column = column.split('.', 2)
              table = Arel::Table.new(table_name, engine)
            end

            attribute = table[column.to_sym]

            case value
            when PGArrays::PgAny
              attribute.ar_any(value)
            when PGArrays::PgAll
              attribute.ar_all(value)
            when PGArrays::PgIncludes
              attribute.ar_included(value)
            when ActiveRecord::Relation
              value = value.select(value.klass.arel_table[value.klass.primary_key]) if value.select_values.empty?
              attribute.in(value.arel.ast)
            when Array, ActiveRecord::Associations::CollectionProxy
              values = value.to_a.map { |x|
                x.is_a?(ActiveRecord::Base) ? x.id : x
              }

              if values.include?(nil)
                values = values.compact
                if values.empty?
                  attribute.eq nil
                else
                  attribute.in(values.compact).or attribute.eq(nil)
                end
              else
                attribute.in(values)
              end

            when Range, Arel::Relation
              attribute.in(value)
            when ActiveRecord::Base
              attribute.eq(value.id)
            when Class
              # FIXME: I think we need to deprecate this behavior
              attribute.eq(value.name)
            else
              attribute.eq(value)
            end
          end
        end

        predicates.flatten
      end
    end
  end
end

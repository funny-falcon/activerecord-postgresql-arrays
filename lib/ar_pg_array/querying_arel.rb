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
    module Predications
      def ar_any(other)
        Predicates::ArrayAny.new(self, other)
      end
      
      def ar_all(other)
        Predicates::ArrayAll.new(self, other)
      end
      
      def ar_included(other)
        Predicates::ArrayIncluded.new(self, other)
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

module PGArrays
  class PgArray
    def to_sql( formatter = nil )
      formatter.engine.quote_array_for_arel_by_base_type(self, base_type)
    end
    
    def to_a
      self
    end
  end
end

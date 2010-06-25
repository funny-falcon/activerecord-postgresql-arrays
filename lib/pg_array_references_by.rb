require 'pg_array_schema'
require 'pg_array_querying'

module PGArrays
  module ReferencesBy
  	class RelationHolder < Struct.new(:relation, :field, :klass)
  	  
  	  def referenced(obj)
  	  	ids = obj.read_attribute(field) || []
  	  	klass.find( ids.sort ).sort_by{|o| ids.index(o.id)}
  	  end
  	  
  	  def set_referenced(obj, value)
        value = value.map{|v| 
  	      case v
  	  	    when ActiveRecord::Base then v.id
  	  	    when nil then nil
  	  	    else v.to_i
  	  	  end
  	  	}.compact
  	  	obj.write_attribute( field, value )
  	  end
  	  
  	  def validate(obj)
  	  	has_ids = klass.find(:all, :select=>'id', :conditions=>{:id=>obj.read_attribute(field)}).map(&:id)
  	  	unless has_ids.sort == obj.read_attribute(field).sort
  	  	  obj.errors.add(relation, :wrong_array_reference)
  	  	end
  	  end
  	  
  	  def for_referenced(obj_klass)
  	  	condition = lambda do |obj| 
  	  	  { :conditions=>{field.to_sym => case obj when klass then obj.id else obj.to_i end} } 
  	  	end
  	  	obj_klass.send(:named_scope, "#{relation}_include", condition )
  	  end
  	  
  	end
  	
  	module ClassMethods
  	  def references_by_array( relation, options = {} )
  	  	unless ActiveSupport::Memoizable === self
  	  	  extend ActiveSupport::Memoizable
  	  	end

  	  	relation = relation.to_s.pluralize
  	  	field = "#{relation.singularize}_ids"
  	  	klass_name = (options[:class_name] || relation).to_s.singularize.camelize
  	    klass = klass_name.constantize
  	    holder = RelationHolder.new(relation, field, klass )
  	    
  	    define_method(relation) do
  	      holder.referenced(self)
  	    end
  	    memoize relation
  	    
  	    define_method("#{relation}=") do |value|
  	      flush_cache(relation)
  	      holder.set_referenced(self, value)
  	    end
  	    
  	    if options[:validate]
  	      validate {|o| holder.validate(o)}
  	    end
  	    
  	    holder.for_referenced(self)
  	  end
  	  
  	end
  end
end

ActiveRecord::Base.extend PGArrays::ReferencesBy::ClassMethods


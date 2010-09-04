module PGArrays
  module ReferencesBy
    begin
			gem 'arel'
			HAS_AREL=true
			NAMED_SCOPE='scope'
		rescue Gem::LoadError
		  NAMED_SCOPE='named_scope'
		  begin
		    gem 'fake_arel'
		    HAS_AREL= !ActiveRecord::Base.scopes[:where].nil?
		  rescue Gem::LoadError
		    HAS_AREL=false
		  end
    end

  	class RelationHolder < Struct.new(:relation, :field, :klass)
  	  
  	  def referenced(obj)
  	  	ids = obj.read_attribute(field) || []
  	  	objs = klass.find_all_by_id( ids.sort )
  	  	if ids.size < 20
					objs.sort_by{|o| ids.index(o.id)}
				else
				  to_ind = ids.each_with_index.inject({}){|h, (v,i)| h[v]=i; h}
				  objs.sort_by{|o| to_ind[o.id]}
				end
  	  end
  	  
  	  def set_referenced(obj, value)
  	  	obj.write_attribute( field, map_to_ids(value) )
  	  end
  	  
  	  if HAS_AREL
  	    def validate(obj)
  	      has_ids = klass.where(:id=>obj.read_attribute(field)).
										select('id').all.map(&:id)
  	      unless has_ids.sort == obj.read_attribute(field).sort
  	  	    obj.errors.add(relation, :wrong_array_reference)
  	  	  end
  	    end

				def for_referenced(obj_klass)
					define_scope obj_klass, "#{relation}_include", "#{relation}_has_all" do |*objs|
					  objs = map_to_ids objs.flatten
						where(field.to_sym => objs.search_all)
					end
					
					define_scope obj_klass, "#{relation}_has_any" do |*objs|
					  objs = map_to_ids objs.flatten
						where(field.to_sym => objs.search_any)
					end
					
					define_scope obj_klass, "#{relation}_included_into" do |*objs|
					  objs = map_to_ids objs.flatten
						where(field.to_sym => objs.search_subarray)
					end
				end
  	  else
				def validate(obj)
					has_ids = klass.find(:all, 
							:select=>'id',
							:conditions=>{:id=>obj.read_attribute(field)}
							).map(&:id)
					unless has_ids.sort == obj.read_attribute(field).sort
						obj.errors.add(relation, :wrong_array_reference)
					end
				end
				
				def for_referenced(obj_klass)
				  my_self = self
					define_scope obj_klass, "#{relation}_include", "#{relation}_has_all" do |*objs|
					  objs = my_self.map_to_ids objs.flatten
						{ :conditions=>{ field.to_sym => objs.search_all } }
					end
					
					define_scope obj_klass, "#{relation}_has_any" do |*objs|
					  objs = my_self.map_to_ids objs.flatten
						{ :conditions=>{ field.to_sym => objs.search_any } }
					end
					
					define_scope obj_klass, "#{relation}_included_into" do |*objs|
					  objs = my_self.map_to_ids objs.flatten
						{ :conditions=>{ field.to_sym => objs.search_subarray } }
					end
				end
		  end
		  
  	  def val_to_id(val)
  	    case val
  	    when ActiveRecord::Base then v.id
  	    when nil then nil
  	    else v.to_i
  	    end
  	  end
  	  
  	  def map_to_ids(vals)
  	    (r = vals.map{|v| val_to_id(v)}).compact!
  	    r
  	  end
  	  
  	  def define_scope(obj_klass, *names, &condition)
  	    names.each do |name|
					obj_klass.send(NAMED_SCOPE, name, condition)
				end
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
  	    
  	    meths =  Module.new do
					define_method(relation) do
						holder.referenced(self)
					end
					
					define_method("#{relation}=") do |value|
						flush_cache(relation)
						holder.set_referenced(self, value)
					end
			  end
			  include meths
  	    
				memoize relation
				
  	    if options[:validate]
  	      validate {|o| holder.validate(o)}
  	    end
  	    
  	    holder.for_referenced(self)
  	  end
  	  
  	end
  end
end

ActiveRecord::Base.extend PGArrays::ReferencesBy::ClassMethods


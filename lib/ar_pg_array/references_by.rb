module PGArrays
  module ReferencesBy
    if defined? ::Arel
      HAS_AREL=true
      NAMED_SCOPE='scope'
    else
      NAMED_SCOPE='named_scope'
      if defined? ::FakeArel
        HAS_AREL= true
      else
        HAS_AREL=false
      end
    end

    class RelationHolder < Struct.new(:relation, :field, :klass)
      
      def referenced(obj)
        ids = (obj[field] || []).map{|i| i.to_i}
        objs = klass.find_all_by_id( ids.sort )
        if ids.size < 20
          objs.sort_by{|o| ids.index(o.id)}
        else
          to_ind = ids.each_with_index.inject({}){|h, (v,i)| h[v]=i; h}
          objs.sort_by{|o| to_ind[o.id]}
        end
      end
      
      def set_referenced(obj, value)
        obj[field] = map_to_ids(value)
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
          myself = self
          obj_klass.class_exec do
            puts "named_scope #{NAMED_SCOPE} #{myself.relation}_include"
            self.send NAMED_SCOPE, "#{myself.relation}_include", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              where(myself.field.to_sym => objs.search_all)
            }
            
            self.send NAMED_SCOPE, "#{myself.relation}_have_all", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              where(myself.field.to_sym => objs.search_all)
            }

            self.send NAMED_SCOPE, "#{myself.relation}_have_any", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              where(myself.field.to_sym => objs.search_any)
            }
            
            self.send NAMED_SCOPE, "#{myself.relation}_included_into", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              where(myself.field.to_sym => objs.search_subarray)
            }
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
          myself = self
          obj_klass.class_exec do
            named_scope "#{myself.relation}_include", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              { :conditions=>{ myself.field.to_sym => objs.search_all } }
            }
            
            named_scope "#{myself.relation}_have_all", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              { :conditions=>{ myself.field.to_sym => objs.search_all } }
            }
            
            named_scope "#{myself.relation}_have_any", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              { :conditions=>{ myself.field.to_sym => objs.search_any } }
            }
            
            named_scope "#{myself.relation}_included_into", lambda{|*objs|
              objs = myself.map_to_ids objs.flatten
              { :conditions=>{ myself.field.to_sym => objs.search_subarray } }
            }
          end
        end
      end
      
      def val_to_id(val)
        case val
        when ActiveRecord::Base then val.id
        when nil then nil
        else val.to_i
        end
      end
      
      def map_to_ids(vals)
        (r = vals.map{|v| val_to_id(v)}).compact!
        r
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


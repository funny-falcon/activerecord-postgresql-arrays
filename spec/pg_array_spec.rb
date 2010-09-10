require File.dirname(__FILE__) + '/spec_helper.rb'

describe "PgArray" do
  context "Array" do
    before :all do
      @ability_class = Class.new do
        include CanCan::Ability
      end
      @acheck = Struct.new(:a)
    end
    
    before :each do
      @ability = @ability_class.new
    end
    
    it "should change type" do
      [].pg.should be_an_instance_of(PGArrays::PgArray)
      [].search_any.should be_an_instance_of(PGArrays::PgAny)
      [].search_all.should be_an_instance_of(PGArrays::PgAll)
      [].search_subarray.should be_an_instance_of(PGArrays::PgIncludes)
    end
    
    it "should provide search_any for cancan" do
      ab.can :boom, @acheck, :a => [1, 2].search_any
      ab.should be_able_to(:boom, the([1]))
      ab.should be_able_to(:boom, the([1, 3]))
      ab.should be_able_to(:boom, the([3, 1]))
      ab.should be_able_to(:boom, the([1, 2]))
      ab.should be_able_to(:boom, the([1, 2, 3]))
      ab.should_not be_able_to(:boom, the([3]))
      ab.should_not be_able_to(:boom, the([]))
    end
    
    it "should provide search_all for cancan" do
      ab.can :boom, @acheck, :a => [1, 2].search_all
      ab.should_not be_able_to(:boom, the([1]))
      ab.should_not be_able_to(:boom, the([1, 3]))
      ab.should_not be_able_to(:boom, the([3, 1]))
      ab.should be_able_to(:boom, the([1, 2]))
      ab.should be_able_to(:boom, the([1, 2, 3]))
      ab.should_not be_able_to(:boom, the([3]))
      ab.should_not be_able_to(:boom, the([]))
    end
    
    it "should provide search_subarray for cancan" do
      ab.can :boom, @acheck, :a => [1, 2].search_subarray
      ab.should be_able_to(:boom, the([1]))
      ab.should_not be_able_to(:boom, the([1, 3]))
      ab.should_not be_able_to(:boom, the([3, 1]))
      ab.should be_able_to(:boom, the([1, 2]))
      ab.should_not be_able_to(:boom, the([1, 2, 3]))
      ab.should_not be_able_to(:boom, the([3]))
      ab.should be_able_to(:boom, the([]))
    end
        
    def the(ar)
      @acheck.new(ar)
    end
    
    def ab
      @ability
    end
  end
  
  context "AR" do
    it "should adequatly insert fixtures" do
      bulk = Bulk.find(1)
      bulk.ints.should == [ 1 ]
      bulk.strings.should == %w{one}
      bulk.times.should == [Time.now.at_beginning_of_month, Time.now.at_beginning_of_day]
      bulk.floats.should == [1.0, 2.3]
      bulk.decimals.should == [1.0, 2.3]
    end
    
    it "should be created with defaults" do
      bulk = Bulk.new
      bulk.ints.should == [1, 2]
      bulk.strings.should == %w{as so}
      bulk.floats.should == [1.0, 1.2]
      bulk.decimals.should == [1.0, 1.2]
      map_times(bulk.times).should == 
          map_times(parse_times(%w{2010-01-01 2010-02-01}))
    end
    
    it "should save changes" do
      bulk = Bulk.find(3)
      for field in %w{ints strings floats decimals times}
        bulk.send(field+'=', bulk.send(field).reverse)
      end
      bulk.save!
      bulk = Bulk.find(:first, :conditions=>'3 = id')
      bulk.ints.should == [3, 2]
      bulk.strings.should == %w{three two}
      bulk.floats.should == [2.5, 2]
      bulk.decimals.should == [2.5, 2]
      map_times(bulk.times).should == map_times(parse_times(%w{2010-04-01 2010-03-01}))
    end
    
    it "should allow to use sql" do
      bulks_where(['ints && ?', [1,2].pg]).should == bulks_where(:id=>[1,2,3])
    end
    
    it "should allow to use finders" do
      bulks_where(:ints => [2].search_any).should == bulks_where(:id=>[2,3])
      bulks_where(:ints => [2,3].search_any).should == bulks_where(:id=>[2,3])
      bulks_where(:ints => [1,2].search_any).should == bulks_where(:id=>[1,2,3])
      
      bulks_where(:ints => [2].search_all).should == bulks_where(:id=>[2,3])
      bulks_where(:ints => [2,3].search_all).should == bulks_where(:id=>[3])
      bulks_where(:ints => [1,2].search_all).should == []
      
      bulks_where(:ints => [2].search_subarray).should == bulks_where(:id=>[2,4])
      bulks_where(:ints => [2,3].search_subarray).should == bulks_where(:id=>[2,3,4])
      bulks_where(:ints => [1,2].search_subarray).should == bulks_where(:id=>[1,2,4])
    end
    
    def map_times(times)
      times.map{|t| t.strftime("%F %T")}
    end
    
    def parse_times(times)
      times.map{|t| DateTime.parse(t)}
    end
    
    def bulks_where(cond)
      Bulk.where(cond).order('id').all
    end
  end
  
  context "CanCan" do
    before :all do
      @ability_class = Class.new do
        include CanCan::Ability
      end
      @all_items = Item.all
    end
    
    before :each do
      @ability = @ability_class.new
    end
    
    it "should provide search_any for cancan" do
      should_match_ids_with_ability [2, 3, 4, 6], :tag_ids => [3].search_any
      should_match_ids_with_ability [1, 3, 4, 5, 6], :tag_ids => [1, 2].search_any
    end
    
    it "should provide search_all for cancan" do
      should_match_ids_with_ability [2, 3, 4, 6], :tag_ids => [3].search_all
      should_match_ids_with_ability [5, 6], :tag_ids => [1, 2].search_all
    end
    
    it "should provide search_subarray for cancan" do
      should_match_ids_with_ability [2, 7], :tag_ids => [3].search_subarray
      should_match_ids_with_ability [1, 5, 7], :tag_ids => [1, 2].search_subarray
    end
    
    def should_match_ids_with_ability(ids, ability)
      act = (ability[:tag_ids].class.name + ids.join('_')).to_sym
      ab.can act, Item, ability
      items = accessible_items(act)
      items.should == items_where(:id=>ids)
      should_be_able_all        items, act
      should_not_be_able_except items, act
    end
    
    def ab
      @ability
    end
    
    def accessible_items(act)
      Item.accessible_by(ab, act).order('id').all
    end
    
    def items_where(cond)
      Item.where(cond).order('id').all
    end
    
    def should_be_able_all(items, act)
      items.each{|item| ab.should be_able_to(act, item)}
    end
    
    def should_not_be_able_except(items, act)
      (@all_items - items).each{|item| ab.should_not be_able_to(act, items)}
    end
  end
  
  context "references_by" do
    it "should fetch tags in saved order" do
      Item.find(3).tags.should == [Tag.find(1), Tag.find(3)]
      Item.find(4).tags.should == [Tag.find(3), Tag.find(1)]
    end
    
    it "should save tags references" do
      item = Item.find(3)
      item.tags= [Tag.find(1), '3', 2]
      item.tags.should == [Tag.find(1), Tag.find(3), Tag.find(2)]
      item.save!
      item.reload
      item.tags.should == [Tag.find(1), Tag.find(3), Tag.find(2)]
      item.tags= [1,3]
      item.save!
      item.reload
      item.tags.should == [Tag.find(1), Tag.find(3)]
    end
    
    it "should define named scopes for tags" do
      Item.tags_include(3).order('id').all.should == items_where(:id=>[2,3,4,6])
      Item.tags_include(1,3).order('id').all.should == items_where(:id=>[3,4,6])
      Item.tags_have_all(3).order('id').all.should == items_where(:id=>[2,3,4,6])
      Item.tags_have_all(1,3).order('id').all.should == items_where(:id=>[3,4,6])
      Item.tags_have_any(3).order('id').all.should == items_where(:id=>[2,3,4,6])
      Item.tags_have_any(1,3).order('id').all.should == items_where(:id=>[1,2,3,4,5,6])
      Item.tags_included_into(3).order('id').all.should == items_where(:id=>[2,7])
      Item.tags_included_into(1,3).order('id').all.should == items_where(:id=>[1,2,3,4,7])
    end
    
    def items_where(cond)
      Item.where(cond).order('id').all
    end
  end
  
  context "schema" do
    it "should allow to add column" do
      lambda do
        ActiveRecord::Schema.define do
          change_table :items do |t|
            t.integer_array :ints, :default=>[], :null=>false
          end
          add_column :items, :floats, :float_array, :default=>[0], :null=>false
        end
      end.should_not raise_error
    end
  end
end

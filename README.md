PostgresArrays
==============

This library adds ability to use PostgreSQL array types with ActiveRecord.

    > User.find(:all, :conditions=>['arr @> ?', [1,2,3].pg])
      SELECT * FROM "users" WHERE ('arr' @> E'{"1", "2", "3"}')
    > User.find(:all, :conditions=>['arr @> ?', [1,2,3].pg(:integer)])
      SELECT * FROM "users" WHERE (arr @> '{1,2,3}')
    > User.find(:all, :conditions=>['arr @> ?', [1,2,3].pg(:float)])
      SELECT * FROM "users" WHERE (arr @> '{1.0,2.0,3.0}')
    > u = User.find(1)
      SELECT * FROM "users" WHERE ("users"."id" = 1)
      => #<User id: 1, ..., arr: [1,2]>
    > u.arr = [3,4]
    > u.save
      UPDATE "users" SET "db_ar" = '{3.0,4.0}' WHERE "id" = 19
    > User.find(:all, :conditions=>{:arr=>[3,4].pg})
      SELECT * FROM "users" WHERE ("users"."arr" = E'{"3", "4"}')
    > User.find(:all, :conditions=>{:arr=>[3,4].search_any(:float)})
      SELECT * FROM "users" WHERE ("users"."arr" && '{3.0,4.0}')
    > User.find(:all, :conditions=>{:arr=>[3,4].search_all(:integer)})
      SELECT * FROM "users" WHERE ("users"."arr" @> '{3,4}')
    > User.find(:all, :conditions=>{:arr=>[3,4].search_subarray(:safe)})
      SELECT * FROM "users" WHERE ("users"."arr" <@ '{3,4}')
      
      class U < ActiveRecord::Migration
        def self.up
          create_table :users do |t|
            t.integer_array :int_ar
          end
          add_column :users, :fl_ar, :float_array
        end
      end
      
Installation
============

    gem install ar_pg_array

Changelog
=========

  0.9.13

    Since version 0.9.13 ar_pg_array will try to detect arrays changed inplace.
    And parsed arrays are now cached in @attributes_cache.
    Thanks to Romain Beauxis (https://github.com/toots ) for being insistent about this.

Copyright (c) 2010 Sokolov Yura aka funny_falcon, released under the MIT license

require 'rubygems'
gem 'rspec'
gem 'activerecord'

$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures')

require 'active_record'
require 'active_record/fixtures'
gem 'pg'
begin
  gem 'arel'
rescue Gem::LoadError
  require 'fake_arel'
  class ActiveRecord::Base
    named_scope :joins, lambda {|*join| {:joins => join } if join[0]}
  end
end
require 'cancan'
require 'cancan/matchers'
require 'ar_pg_array'


ActiveRecord::Base.establish_connection(
  :adapter => 'postgresql',
  :database => 'postgres',
  :encoding => 'utf8'
)
ActiveRecord::Base.connection.create_database('test_pg_array', :encoding=>'utf8') rescue nil

ActiveRecord::Base.establish_connection(
  :adapter => 'postgresql',
  :database => 'test_pg_array',
  :encoding => 'utf8'
)
ActiveRecord::Base.logger = Logger.new(STDOUT) #if $0 == 'irb'

require 'tag'
require 'item'
require 'bulk'
ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false

  # load schema
  load File.join('spec/fixtures/schema.rb')
  # load fixtures
  Fixtures.create_fixtures("spec/fixtures", ActiveRecord::Base.connection.tables)
end


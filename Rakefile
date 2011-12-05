require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the postgres_arrays plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the postgres_arrays plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'PostgresArrays'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "ar_pg_array"
    gemspec.summary = "Use power of PostgreSQL Arrays in ActiveRecord"
    gemspec.description = "ar_pg_array includes support of PostgreSQL's int[], float[], text[], timestamptz[] etc. into ActiveRecord. You could define migrations for array columns, query on array columns."
    gemspec.email = "funny.falcon@gmail.com"
    gemspec.homepage = "http://github.com/funny-falcon/activerecord-postgresql-arrays"
    gemspec.authors = ["Sokolov Yura aka funny_falcon"]
    gemspec.add_dependency('active_record', '>= 2.3.5')
    gemspec.rubyforge_project = 'ar-pg-array'
  end
  Jeweler::GemcutterTasks.new
  Jeweler::RubyforgeTasks.new do |rubyforge|
    
  end
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end


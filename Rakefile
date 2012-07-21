require 'rake'
require 'rdoc/task'

desc 'Test the postgres_arrays plugin.'
task :test do
  Dir.chdir(File.dirname(__FILE__)) do
    Process.wait2 spawn('rspec spec')
  end
end

task :default do
  # nothing
end

desc 'Generate documentation for the postgres_arrays plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'PostgresArrays'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

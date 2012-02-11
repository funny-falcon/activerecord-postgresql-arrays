require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

require 'ar_pg_array/schema'
require 'ar_pg_array/schema_cacheable'
require 'ar_pg_array/querying'
require 'ar_pg_array/allways_save'
require 'ar_pg_array/references_by'
if ActiveRecord::VERSION::MAJOR >= 3
  require 'ar_pg_array/schema_arel'
  require 'ar_pg_array/querying_arel'
else
  require 'ar_pg_array/schema_fix_will_change'
end

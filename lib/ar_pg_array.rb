require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

require 'ar_pg_array/schema'
require 'ar_pg_array/querying'
require 'ar_pg_array/references_by'
if defined? ::Arel
  require 'ar_pg_array/schema_arel'
  require 'ar_pg_array/querying_arel'  
end
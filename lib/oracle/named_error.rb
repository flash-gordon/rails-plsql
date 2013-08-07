module Oracle; end

if RUBY_ENGINE == 'ruby'
  require 'oci8/oci_named_error'
  Oracle::NamedError = OCI8::OCINamedError
elsif RUBY_ENGINE == 'jruby'
  require 'java/oracle_sql_named_error'
  Oracle::NamedError = Java::JavaSQL::OracleNamedError
end
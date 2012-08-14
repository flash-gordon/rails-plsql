require 'active_record/connection_adapters/oracle_enhanced_adapter'
require 'plsql/pipelined_function'

module ActiveRecord
  module ConnectionAdapters
    # interface independent methods
    class OracleEnhancedAdapter
      def columns_without_cache_with_pipelined(table, name)
        begin
          return columns_without_cache_without_pipelined(table, name)
        rescue OracleEnhancedConnectionException => error
          # Will try to find a pipelined function
        end

        table = table.to_s.upcase
        function_name, package_name = table.split('.').reverse

        if (function = ::PLSQL::PipelinedFunction.find(plsql, function_name, package_name))
          arguments_metadata = function.arguments[0].sort_by {|arg| arg[1][:position]}
          arguments = arguments_metadata.map do |(arg_name, argument)|
            OracleEnhancedColumn.new(arg_name.to_s, nil, argument[:data_type], table)
          end

          return_columns = function.return[:element][:fields].sort_by {|(col_name, col)| col[:position]}.map do |(col_name, metadata)|
            metadata.merge(name: col_name)
          end

          return_columns.map do |col|
            OracleEnhancedColumn.new(col[:name].to_s, nil, col[:data_type], table)
          end + arguments
        else
          raise error.class, error.message
        end
      end

      alias_method_chain :columns_without_cache, :pipelined
    end
  end
end
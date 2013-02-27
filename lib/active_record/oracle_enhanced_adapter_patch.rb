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

        function_name, package_name = parse_function_name(table)

        if package_name
          function = plsql.send(package_name.downcase.to_sym)[function_name.downcase]
        else
          raise error.class, error.message
        end

        if function
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

      def parse_function_name(name)
        name = name.to_s.upcase
        # We can get name of function with calling syntax
        # Just extract function name
        if name =~ /\ATABLE\((([^.]+\.)[^.]+)\([^)]+\)\)\z/
          name = $1
        end
        name.split('.').reverse
      end
    end
  end
end
require 'active_support/concern'

module ActiveRecord::PLSQL
  module Pipelined
    extend ActiveSupport::Concern

    class PipelinedFunctionError < ActiveRecord::ActiveRecordError; end

    class PipelinedFunctionTableName < Arel::Nodes::SqlLiteral
      def to_s;self end
    end

    included do
      self.pipelined_function = nil
    end

    module ClassMethods
      def pipelined_arguments
        raise PipelinedFunctionError, "Pipelined function didn't set" unless pipelined_function
        @pipelined_arguments ||= get_pipelined_arguments
      end

      def pipelined_arguments_names
        pipelined_arguments.map(&:name)
      end

      def pipelined_function
        @pipelined_function
      end

      alias pipelined? pipelined_function

      def pipelined_function=(function)
        case function
        when String, Symbol
          # Name without schema expected
          function_name = function.to_s.split('.').map(&:downcase).map(&:to_sym)
          case function_name.size
          when 2
            pipelined_function = plsql.send(function_name.first)[function_name.second]
          when 1
            pipelined_function = PLSQL::PipelinedFunction.find(plsql, function_name.first)
          else
            raise ArgumentError, 'Setting schema via string not supported yed'
          end
          raise ArgumentError, 'Pipelined function not found by string: %s' % function unless pipelined_function
        when ::PLSQL::PipelinedFunction, nil
          pipelined_function = function
        else
          raise ArgumentError, 'Unsupported type of pipelined function: %s' % function.inspect
        end

        if pipelined_function && pipelined_function.overloaded?
          raise ArgumentError, 'Overloaded functions are not supported yet'
        end

        @pipelined_function = pipelined_function
        @pipelined_arguments = nil
        @columns = nil

        if @pipelined_function
          set_pipelined_table_name
          set_function_type_as_columns
        end
      end

      def pipelined_function_name
        return @full_function_name if defined? @full_function_name
        package_name, function_name = @pipelined_function.package, @pipelined_function.procedure
        @full_function_name = [package_name, function_name].compact.join('.')
      end

      def arel_table
        if pipelined_function
          @arel_table ||= Arel::Table.new(table_name_with_arguments, engine: arel_engine, as: pipelined_function_alias)
        else
          super
        end
      end

      def pipelined_function_alias
        # GET_USER_BY_NAME => GUBN
        @pipelined_function.procedure.scan(/^\w|_\w/).join('').gsub('_', '')
      end

      def table_name_with_arguments
        @table_name_with_arguments ||= PipelinedFunctionTableName.new(
            "TABLE(%s(%s))" % [table_name, pipelined_arguments.map{|a| ":#{a.name}"}.join(',')]
        )
      end

      def table_exist?
        pipelined? || super
      end

      private

        def set_pipelined_table_name
          @table_name = pipelined_function_name
        end

        def get_pipelined_arguments
          # Always select arguments of first function (overloading not supported)
          arguments_metadata = pipelined_function.arguments[0].sort_by {|arg| arg[1][:position]}
          arguments_metadata.map do |(name, argument)|
            ActiveRecord::ConnectionAdapters::OracleEnhancedColumn.new(name.to_s, nil, argument[:data_type], pipelined_function_name)
          end
        end

        def set_function_type_as_columns
          return_columns = pipelined_function.return[:element][:fields].sort_by {|(name, col)| col[:position]}.map do |(name, metadata)|
            metadata.merge(name: name)
          end

          connection.schema_cache.columns[table_name] = return_columns.map do |col|
            ActiveRecord::ConnectionAdapters::OracleEnhancedColumn.new(col[:name].to_s, nil, col[:data_type], pipelined_function_name)
          end + pipelined_arguments
        end

        def relation
          return super unless pipelined?
          @relation ||= PipelinedRelation.new(self, arel_table)
        end
    end

    delegate :pipelined?, to: 'self.class'

    attr_accessor :found_by_arguments

    def reload(options = nil)
      return super unless pipelined? && (found_by_arguments.present? || options)

      clear_aggregation_cache
      clear_association_cache

      ActiveRecord::IdentityMap.without do
        fresh_object = self.class.unscoped do
          relation = self.class.where(self.class.primary_key => id)

          if found_by_arguments
            relation.bind_values += found_by_arguments
            relation.to_a.first
          else
            relation.where(options).to_a.first
          end
        end

        @attributes.update(fresh_object.instance_variable_get('@attributes'))
      end

      @attributes_cache = {}
      self
    end

  end
end
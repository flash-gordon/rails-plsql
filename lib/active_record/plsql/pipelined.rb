require 'active_support/concern'

module ActiveRecord::PLSQL
  module Pipelined
    extend ActiveSupport::Concern

    class PipelinedFunctionError < ActiveRecord::ActiveRecordError; end

    class PipelinedFunctionTableName < Arel::Nodes::SqlLiteral
      alias_method :to_s, :itself
    end

    included do
      self.pipelined_function = nil
    end

    module DisableBinding
      def can_be_bound?(*)
        false
      end
    end

    module ClassMethods
      def pipelined_arguments
        raise PipelinedFunctionError, "Pipelined function didn't set" unless pipelined?
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
        @table_name = pipelined_function_name if @pipelined_function
      end

      def pipelined_function_name
        [@pipelined_function.package, @pipelined_function.procedure].compact.join('.')
      end

      def arel_table
        if pipelined?
          @arel_table ||= Arel::Table.new(
            table_name_with_arguments,
            as: pipelined_function_alias
          )
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

      def predicate_builder
        @_predicate_builder ||= super.extend(DisableBinding)
      end

      private

      def get_pipelined_arguments
        # Always select arguments of first function (overloading not supported)
        arguments_metadata = pipelined_function.arguments[0].sort_by {|arg| arg[1][:position]}
        arguments_metadata.map do |name, argument|
          ActiveRecord::ConnectionAdapters::OracleEnhancedColumn.new(
            name.to_s, nil, connection.fetch_type_metadata(argument[:data_type]), pipelined_function_name
          )
        end
      end

      def relation
        return super unless pipelined?
        @relation ||= PipelinedRelation.new(self, arel_table, predicate_builder)
      end
    end

    delegate :pipelined?, to: 'self.class'

    attr_accessor :found_by_arguments

    def reload(options = nil)
      return super unless pipelined? && (found_by_arguments.present? || options)

      clear_aggregation_cache
      clear_association_cache

      fresh_object = self.class.unscoped do
        args = try_get_arguments(found_by_arguments).merge(options || {})
        relation = self.class.where(
          **args,
          self.class.primary_key => id,
        )

        relation.to_a[0]
      end

      @attributes = fresh_object.instance_variable_get("@attributes")
      @new_record = false

      @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      self
    end

    private

    def try_get_arguments(arguments)
      if arguments
        arguments.each_with_object({}) { |arg, hash| hash[arg.name.to_sym] = arg.value }
      else
        {}
      end
    end
  end
end

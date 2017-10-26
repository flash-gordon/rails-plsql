require 'active_support/concern'
require 'active_record/connection_adapters/oracle_enhanced/procedures'

module ActiveRecord::PLSQL
  module ProcedureMethods
    extend ActiveSupport::Concern

    class CannotFetchId < StandardError; end

    included do
      include ActiveRecord::OracleEnhancedProcedures

      class_attribute :plsql_package, :procedure_methods_cache, instance_writer: false
      self.plsql_package = nil
      self.procedure_methods_cache = Hash.new do |cache, klass|
        cache[klass] = Hash.new do |methods, method|
          # Inherits procedure methods from base class
          if klass.superclass.respond_to?(:procedure_methods)
            methods[method] = klass.superclass.procedure_methods[method]
          else
            nil
          end
        end
      end
    end

    module ClassMethods
      def set_create_procedure(procedure, options = {}, &reload_block)
        block ||= proc do |record, result|
          case result
          when Hash
            record.id = result.values.first
          when Numeric
            record.id = result
          else
            raise CannotFetchId, "Couldn't fetch primary key from create procedure (%s) result: %s" %
              [procedure, result.inspect]
          end

          reload_block ? reload_block.call(record) : record.reload

          record.instance_variable_set(:@new_record, true)
          record.id
        end

        procedure_method(:create, procedure, options, &block)
        set_create_method {call_procedure_method(:create)}
      end

      def set_update_procedure(procedure, options = {})
        procedure_method(:update, procedure, options) do |record|
          record.reload
          record.id
        end
        set_update_method {call_procedure_method(:update)}
      end

      def set_destroy_procedure(procedure, options = {})
        procedure_method(:destroy, procedure, options)
        set_delete_method {call_procedure_method(:destroy)}
      end

      def procedure_methods
        procedure_methods_cache[self]
      end

      def procedure_method(method, procedure_name = method, options = {}, &block)
        procedure = if PLSQL::Procedure === procedure_name
          procedure_name
        else
          find_procedure(procedure_name)
        end

        # Raise error if procedure not found
        raise ArgumentError, "Procedure (%s) not found for method (%s)" % [procedure_name, method] unless procedure

        procedure_methods[method] = {procedure: procedure, options: options, block: block}

        unless (instance_methods + private_instance_methods).find {|m| m == method}
          @generated_attribute_methods.class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
            def #{method}(arguments = {}, options = {})
              call_procedure_method(:#{method}, arguments, options)
            end
          RUBY
        end
      end

      def procedures_arguments
        @procedures_arguments ||= Hash.new do |cache, procedure|
          # Always select arguments of first function (overloading not supported)
          cache[procedure] = Hash[ procedure.arguments[0].sort_by {|arg| arg[1][:position]} ]
        end
      end

      private

        def find_procedure(procedure_name)
          procedure_name = procedure_name.to_s.split('.').compact

          case procedure_name.size
          when 2
            plsql.send(procedure_name[0].to_sym)[procedure_name[1]]
          when 1
            if plsql_package
              plsql_package[procedure_name[0]] || PLSQL::Procedure.find(plsql, procedure_name[0])
            else
              PLSQL::Procedure.find(plsql, procedure_name[0])
            end
          end
        end
    end

    delegate :procedures_arguments, :procedure_methods, to: 'self.class'

    private

      def call_procedure_method(method, arguments = {}, opts = {})
        procedure, options, block = procedure_methods[method].values_at(:procedure, :options, :block)
        options = options.merge(opts)

        if options[:arguments]
          if arguments.is_a?(Hash)
            arguments = arguments.merge(instance_exec(&options[:arguments]))
          else
            arguments += options[:arguments]
          end
        end

        options[:arguments] = arguments
        call_procedure(procedure, options, &block)
      end

      def call_procedure(procedure, options = {})
        result = procedure.exec(*get_procedure_arguments(procedure, options))
        if block_given?
          yield(self, result)
        else
          result
        end
      end

      def get_procedure_arguments(procedure, options)
        arguments = options[:arguments]
        arguments = arguments.dup if arguments.duplicable?

        if Hash === arguments
          arguments.symbolize_keys!
          arguments_metadata = procedures_arguments[procedure]
          # throw away unnecessary arguments
          [arguments.select {|k,_| arguments_metadata[k]}]
        else
          arguments
        end
      end
  end
end

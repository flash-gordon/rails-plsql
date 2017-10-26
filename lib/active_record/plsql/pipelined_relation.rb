module ActiveRecord::PLSQL
  class PipelinedRelation < ActiveRecord::Relation
    class FromClause < ActiveRecord::Relation::FromClause
      def initialize(value, name, binds = nil)
        super(value, name)

        @binds = binds
      end

      def binds
        @binds || super
      end

      def table_binds
        @binds || []
      end
    end

    attr_accessor :pipelined_arguments_values

    def where(opts, *rest)
      return super unless @klass.pipelined? && pipelined_arguments.any?

      pipelined_args = pipelined_arguments_names.map(&:to_sym)
      normalized_opts = normalize_arguments_conditions(opts, pipelined_args)
      return super if normalized_opts.empty?

      pipelined_binds = get_pipelined_arguments(table_binds, normalized_opts)
      where_opts = normalized_opts.reject { |k| pipelined_args.include?(k) }

      rel = spawn.from!(
        table_name_with_arguments,
        pipelined_function_alias.to_sym,
        pipelined_binds
      )

      if where_opts.empty? && rest.empty?
        rel
      elsif where_opts.empty?
        rel.where!(*rest)
      elsif where_opts.is_a?(Array)
        rel.where!(*where_opts, *rest)
      else
        rel.where!(where_opts, *rest)
      end
    end

    def where!(opts, *rest)
      return super unless @klass.pipelined? && pipelined_arguments.any?

      pipelined_args = pipelined_arguments_names.map(&:to_sym)
      normalized_opts = normalize_arguments_conditions(opts, pipelined_args)
      return super if normalized_opts.empty?

      pipelined_binds = get_pipelined_arguments(table_binds, normalized_opts)
      where_opts = normalized_opts.reject { |k| pipelined_args.include?(k) }

      from!(
        table_name_with_arguments,
        pipelined_function_alias.to_sym,
        pipelined_binds
      )

      if where_opts.empty? && rest.empty?
        self
      elsif where_opts.empty?
        super(*rest)
      else
        super(where_opts, *rest)
      end
    end

    def get_pipelined_arguments(current, values)
      if values.is_a?(Hash)
        pipelined_arguments_names.map do |name|
          ActiveRecord::Attribute.with_cast_value(
            name,
            values.fetch(name.to_sym) {
              cur = current.find { |arg| arg.name.to_sym == name.to_sym }
              cur ? cur.value : nil
            },
            ActiveRecord::Type.default_value
          )
        end
      else
        current
      end
    end

    def table_binds
      if from_clause.is_a?(FromClause)
        from_clause.table_binds
      else
        []
      end
    end

    def build_from
      if @klass.pipelined?
        @klass.arel_table
      else
        super
      end
    end

    def table
      if @klass.pipelined?
        @klass.arel_table
      else
        super
      end
    end

    def from!(value, subquery_name = nil, binds = nil) # :nodoc:
      self.from_clause = FromClause.new(value, subquery_name, binds)
      self
    end

    def exec_queries
      return super unless @klass.pipelined? && !pipelined_arguments.empty?
      return @records if loaded?
      super
      return @records if @records.empty?

      # save arguments for easy reloading
      @records.each { |record| record.found_by_arguments = table_binds }
      @records
    end

    protected

    def normalize_arguments_conditions(opts, args)
      case opts
      when Hash
        if opts.key?(klass.pipelined_function_name)
          opts[klass.pipelined_function_name].symbolize_keys
        else
          opts.symbolize_keys
        end
      when Arel::Nodes::Equality
        column = opts.left.name.to_sym

        # only simple types for now
        if args.include?(column) && !opts.right.is_a?(Arel::Attributes::Attribute)
          { column => opts.right }
        end
      else
        [opts]
      end
    end
  end
end

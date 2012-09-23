module ActiveRecord::PLSQL
  class PipelinedRelation < ActiveRecord::Relation
    attr_accessor :pipelined_arguments_values

    def where(opts, *rest)
      return super unless @klass.pipelined? && pipelined_arguments.any?

      pipelined_args = pipelined_arguments_names.map(&:to_sym)
      opts = normalize_arguments_conditions(opts, pipelined_args)
      return super if opts.blank?

      relation = bind_pipelined_arguments(opts)
      opts.reject! {|k| pipelined_args.include?(k)}
      # bind rest of arguments
      relation.where_values += build_where(opts, rest)
      relation
    end

    def bind_pipelined_arguments(values)
      relation = clone
      arguments_values = values.values_at(*pipelined_arguments_names.map(&:to_sym))
      relation.bind_values += pipelined_arguments.zip(arguments_values)
      relation
    end

    def merge_pipelined_arguments(pos, values)
      new_values_pos = pos + pipelined_arguments.size
      exist_args = values[pos...new_values_pos]
      new_values = values[new_values_pos..-1]
      new_args_pos = pipelined_arguments_binds_pos(new_values)
      # return if there are no new argument values
      return unless new_args_pos
      new_arguments = new_values[new_args_pos...(new_args_pos + pipelined_arguments.size)]
      # overriding nil arguments
      new_arguments.each_with_index {|val, idx| exist_args[idx][1] ||= val[1]}
      # exclude new arguments
      values[(new_values_pos + new_args_pos)...(new_values_pos + new_args_pos + pipelined_arguments.size)] = nil
      # drop nil
      values.compact!
    end

    def pipelined_arguments_binds_pos(binds = @bind_values)
      binds.index {|(col,_)| col.name == pipelined_arguments.first.name}
    end

    # Safe arguments binding
    def bind_values=(vals)
      if @klass.pipelined? && (pos = pipelined_arguments_binds_pos)
        merge_pipelined_arguments(pos, vals)
        super
      else
        super
      end
    end

    def exec_queries
      return super unless @klass.pipelined? && pipelined_arguments.any?
      return @records if loaded?
      super
      return @records if @records.empty?

      pos = pipelined_arguments_binds_pos
      found_by_arguments = @bind_values[pos...(pos + pipelined_arguments.size)]
      # save arguments for easy reloading
      @records.each {|record| record.found_by_arguments = found_by_arguments}
      @records
    end

    protected

      def normalize_arguments_conditions(opts, args)
        case opts
        when Hash
          opts.symbolize_keys
        when Arel::Nodes::Equality
          column = opts.left.name.to_sym

          # only simple types for a while
          if args.include?(column) && !opts.right.is_a?(Arel::Attributes::Attribute)
            {column => opts.right}
          end
        end
      end
  end
end
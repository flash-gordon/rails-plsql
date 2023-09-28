module ActiveRecord::PLSQL
  module PipelinedScope
    def last_chain_scope(scope, reflection, owner)
      join_keys = reflection.join_keys
      key = join_keys.key
      foreign_key = join_keys.foreign_key

      table = reflection.aliased_table
      value = scope.klass.pipelined? ? owner[foreign_key] : transform_value(owner[foreign_key])
      scope = apply_scope(scope, table, key, value)

      if reflection.type
        polymorphic_type = transform_value(owner.class.base_class.name)
        scope = apply_scope(scope, table, reflection.type, polymorphic_type)
      end

      scope
    end
  end
end

ActiveRecord::Associations::AssociationScope.prepend(ActiveRecord::PLSQL::PipelinedScope)

module ActiveRecord::PLSQL
  module AssociationRelation
    def build_from
      if klass.pipelined?
        klass.arel_table
      else
        super
      end
    end
  end
end

ActiveRecord::AssociationRelation.prepend(ActiveRecord::PLSQL::AssociationRelation)

require 'active_record/persistence'

module ActiveRecord::Persistence
  def create_with_procedure_calling
    return create_without_procedure_calling unless respond_to?(:procedure_methods) && procedure_methods[:create]
    call_procedure_method(:create)
  end

  alias_method_chain :create, :procedure_calling

  def update_with_procedure_calling(*args)
    return update_without_procedure_calling unless respond_to?(:procedure_methods) && procedure_methods[:update]
    call_procedure_method(:update)
  end

  alias_method_chain :update, :procedure_calling
end
class OracleNamedError < StandardError
  class_attribute :error_code, instance_writer: false

  UNHANDLED_ERROR = 6512

  class << self
    def ===(error)
      error = error.original_exception if error.respond_to?(:original_exception)
      error = error.cause if error.respond_to?(:cause) && error.cause

      Java::JavaSql::SQLException === error &&
          (error.get_error_code.in?([*error_code]) ||
           # ORA-06512: at line 1
           # ORA-20100: some exception description <--- real exception code in the second line
           error.get_error_code == UNHANDLED_ERROR &&
               error.message.split("\n")[1].try(:[], /\AORA-(\d+)/, 1).try(:to_i).in?([*error_code]))
    end

    def define_exception(class_name, error_code)
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        class ::#{class_name} < OracleNamedError
          self.error_code = #{error_code}
        end
      RUBY
    end
  end
end
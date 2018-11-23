class OCI8
  class OCINamedError < OCIError
    class_attribute :oci_error_code, instance_writer: false

    UNHANDLED_ERROR = 6512

    class << self
      alias error_code= oci_error_code=

      def error_code
        oci_error_code
      end

      def ===(error)
        error = error.original_exception if error.respond_to?(:original_exception)
        OCIError === error &&
            ([*error_code].include?(error.code) ||
             # ORA-06512: at line 1
             # ORA-20100: some exception description <--- real exception code in the second line
             error.code == UNHANDLED_ERROR &&
                 error.message.split("\n")[1].try(:[], /\AORA-(\d+)/, 1).try(:to_i).in?([*error_code]))
      end

      def define_exception(class_name, error_code)
        class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
          class ::#{class_name} < OCI8::OCINamedError
            self.error_code = #{error_code}
          end
        RUBY
      end
    end
  end
end

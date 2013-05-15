class OCI8
  class OCINamedError < OCIError
    class_attribute :oci_error_code, instance_writer: false

    UNHANDLED_ERROR = 6512

    def self.===(error)
      OCIError === error &&
          (error.code.in?([*oci_error_code]) ||
           # ORA-06512: at line 1
           # ORA-20100: some exception description <--- real excpetion code in the second line
           error.code == UNHANDLED_ERROR &&
               error.message.split("\n")[1].try(:[], /\AORA-(\d+)/, 1).try(:to_i).in?([*oci_error_code]))
    end

    def self.define_exception(class_name, error_code)
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        class ::#{class_name} < OCI8::OCINamedError
          self.oci_error_code = #{error_code}
        end
      RUBY
    end
  end
end
class OCI8
  class OCINamedError
    class_attribute :oci_error_code, instance_writer: false

    def self.===(error)
      OCIError === error && error.code == oci_error_code
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
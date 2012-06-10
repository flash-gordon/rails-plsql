module PLSQL
  class LogSubscriber < ActiveSupport::LogSubscriber
    def procedure_call(event)
      return unless logger && (logger.debug? || uncaught_exception?(event.payload[:error]))
      payload = event.payload
      name = 'PL/SQL Procedure call (%.1fms)' % event.duration
      sql = payload[:sql].strip

      if payload[:arguments].empty?
        arguments = nil
      elsif payload[:arguments].size == 1 && Hash === payload[:arguments].first
        arguments = '  ' + payload[:arguments].first.inspect
      else
        arguments = '  ' + payload[:arguments].inspect
      end

      if event.payload[:error]
        exception = "Error occurred: %s\n%s" %
          [event.payload[:error].class, event.payload[:error].message.split("\n").map{|l| "  #{l}"}.join("\n")]

        name = color(name, RED, true)
        exception = color(exception, RED, true)
        sql = color(sql, nil, true)

        error "  #{name}  #{sql}#{arguments}\n  #{exception}"
      else
        name = color(name, YELLOW, true)
        sql = color(sql, nil, true)

        debug "  #{name}  #{sql}#{arguments}"
      end
    end

    def uncaught_exception?(error)
      error && OCIError === error && !error.code.in?(-20999..-20000)
    end
  end
end

PLSQL::LogSubscriber.attach_to :plsql
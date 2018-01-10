module Courrier
  class Envelope
    attr_reader :email_name, :attributes

    delegate :recipient, :payload, to: :email

    def initialize(email_name, attributes = {})
      @email_name, @attributes = email_name, attributes
    end

    def deliver
      log "Delivering #{email_name} to #{recipient_email}"
      payload.tap do |args|

        case recipient
        when User
          Courrier.configuration.mailer.transactional_email_to_user(*args)
        else
          Courrier.configuration.mailer.transactional_email_to_address(*args)
        end
        log args.inspect
      end
    end

    def email
      @email ||= email_class.new(attributes)
    end

    private

    def mailer
      raise "No mailer configured" unless self.class.mailer

      self.class.mailer
    end

    def recipient_email
      case recipient
      when User
        recipient.email
      else
        recipient
      end
    end

    def email_class
      "notifier/#{email_name}_email".camelize.constantize
    end

    def log(info)
      Rails.logger.info "#{self.class.name} -- #{info}"
    end

  end
end

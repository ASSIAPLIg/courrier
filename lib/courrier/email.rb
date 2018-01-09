module Courrier
  class Email
    extend ActiveModel::Callbacks
    # include UrlGeneration
    # include SslHelper
    # include EmailUrlOptions

    define_model_callbacks :initialize, only: :after

    class_attribute :required_keys
    class_attribute :delivery_block
    class_attribute :delivery_keys
    class_attribute :default_delivery_keys
    class_attribute :recipient_method
    class_attribute :email_name
    class_attribute :email_template_name

    self.required_keys = []
    self.delivery_keys = []
    self.delivery_block = nil

    self.default_delivery_keys = [
      :show_call_to_action
    ]

    # delegate :localized_date_time, to: DateTimeFormatHelper

    # Public: Specify an instance method that returns a user
    # or email address to whom the email should be delivered.
    #
    def self.recipient(user_or_email_address)
      self.recipient_method = user_or_email_address
    end

    # Public: Shorthand for requiring a model id and method for
    # retrieving instance of model from db using that id. Though
    # activerecord-inspired, it doesn't support any fancy options.
    #
    def self.belongs_to(*attrs)
      attrs.each do |attribute|
        requires :"#{attribute}_id"

        define_method(attribute) do
          instance_variable_get("@#{attribute}") ||
            instance_variable_set("@#{attribute}",
              attribute.to_s.camelize.constantize.find(send(:"#{attribute}_id")))
        end
      end
    end

    # Public: Specify a required attribute for new instances.
    #
    def self.requires(*attrs)
      self.required_keys += attrs
      attr_reader *attrs
    end

    def self.deliver(*attrs, &block)
      if block_given?
        self.delivery_block = block
      end

      self.delivery_keys += attrs
    end

    def self.email_name
      (self.name || 'Generic').demodulize.underscore.gsub(/_email$/, '')
    end

    def self.email_template_name
      self.email_name
    end

    def self.subclass_by_email_name(email_name)
      "notifier/#{email_name}_email".camelize.constantize
    end

    def recipient
      return Settings.interceptor_emails.first if Settings.interceptor_emails.any?
      method = self.class.recipient_method
      raise Courrier::RecipientUndefinedError.new("Please declare a recipient in #{self.class.name}") if method.nil? || !self.respond_to?(method, true)
      send(method)
    end

    def delivery_attributes
      {}.tap do |attrs|
        if delivery_block
          instance_exec(attrs, &delivery_block)
        end

        delivery_keys.each do |attribute|
          begin
            attrs[attribute] = send(attribute)
          rescue NoMethodError => e
            if respond_to?(attribute)
              raise e
            else
              raise Courrier::DeliveredAttributeError.new("#{self.class.name} #{e}")
            end
          end
        end
      end
    end

    def initialize(attributes = {})
      attrs = attributes.with_indifferent_access
      begin
        required_keys.each do |attribute|
          instance_variable_set("@#{attribute}", attrs.fetch(attribute))
        end
      rescue KeyError => e
        raise Courrier::RequiredAttributeError.new("#{self.class.name} #{e}")
      end

      # Set optional attributes via attr_writer
      attrs.except(*required_keys).each do |key, value|
        self.send("#{key}=", value)
      end

      run_callbacks :initialize
    end

    def payload
      [email_template_name, recipient, delivery_attributes]
    end

    # attributes

    def show_call_to_action
      'false'
    end

    def support_email
      # EmailAddress[:support].to_s
    end

    def delivery_keys
      (default_delivery_keys + self.class.delivery_keys).uniq
    end

    def image_url(path)
      ActionController::Base.helpers.image_url(path, host: root_url)
    end

    private

    def localized_date_time(dtime, zone = nil)
      formatted_date_time localize_time(dtime, zone) if dtime
    end

    def localize_time(time, zone = nil)
      return time if time.nil? || zone.nil?

      time.in_time_zone(zone)
    end

    def formatted_date_time(datetime)
      "#{formatted_date datetime} #{formatted_time datetime}"
    end

    def formatted_date(date)
      date.strftime('%b %d, %Y')
    end

    def formatted_time(time, something = nil)
      offset = time.gmtoff / 3600

      if offset >= -8 && offset <= -4 # Show timezone name in US
        time.strftime('%I:%M %p %Z')
      else
        time.strftime('%H:%M') + " GMT" + (offset < 0 ? "-" : "+") + offset.abs.to_s + ":00"
      end
    end
  end

  class RequiredAttributeError < KeyError; end
  class RecipientUndefinedError < RuntimeError; end
  class DeliveredAttributeError < RuntimeError; end
end

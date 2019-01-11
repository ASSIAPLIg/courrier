module Courrier
  module Notifier
    extend self

    def deliver(*args)
      Courrier::Envelope.new(*args).deliver
    end

    # Plan to configure with an adapter and allow for async delivers

    # def deliver_async(email_name, attributes)
    # end
    #
    # def deliver_in(interval, email_name, attributes)
    # end

  end
end

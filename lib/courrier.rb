require "courrier/version"
require "courrier/envelope"
require "courrier/email"
require "courrier/configuration"

module Courrier
  class << self
    attr_accessor :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

  end
end

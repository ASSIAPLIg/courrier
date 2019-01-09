Dir.glob(File.join('courrier', '**', '*.rb'), &method(:require))

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

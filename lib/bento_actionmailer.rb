require 'bento_actionmailer/version'
require 'bento_actionmailer/railtie' if defined? Rails

module BentoActionMailer
  class DeliveryMethod
    class DeliveryError < StandardError; end

    DEFAULTS = {
      raise_delivery_errors: false
    }.freeze

    attr_accessor :settings, :options

    def initialize(params = {})
      self.settings = DEFAULTS.merge(params)
    end

    def deliver!(mail)
      puts "DELIVER!"
    end
  end
end

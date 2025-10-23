# frozen_string_literal: true

module Warning
  class << self
    alias_method :original_warn, :warn
    def warn(msg)
      return if msg =~ /assigned but unused variable - testEof/
      original_warn(msg)
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "bento_actionmailer"

require "minitest/autorun"
require_relative "bento/test_helper_extensions"

if Warning.respond_to?(:ignore)
  Warning.ignore(/assigned but unused variable - testEof/)
end

class Minitest::Test
  include Bento::TestHelperExtensions
end

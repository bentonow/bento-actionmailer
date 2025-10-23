# frozen_string_literal: true

module Warning
  class << self
    alias_method :original_warn, :warn
    def warn(msg)
      suppressed_patterns = [
        /assigned but unused variable - testEof/,
        /assigned but unused variable - append_qs/,
        /assigned but unused variable - style_url/,
        /assigned but unused variable - part/,
        %r{premailer/adapter/nokogiri\.rb:43: warning: character class has duplicated range},
        %r{premailer/adapter/nokogiri\.rb:66: warning: character class has duplicated range}
      ]
      return if suppressed_patterns.any? { |pattern| msg =~ pattern }
      original_warn(msg)
    end
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "bento_actionmailer"

require "minitest/autorun"
require_relative "bento/test_helper_extensions"

if Warning.respond_to?(:ignore)
  [
    /assigned but unused variable - testEof/,
    /assigned but unused variable - append_qs/,
    /assigned but unused variable - style_url/,
    /assigned but unused variable - part/,
    %r{premailer/adapter/nokogiri\.rb:43: warning: character class has duplicated range},
    %r{premailer/adapter/nokogiri\.rb:66: warning: character class has duplicated range}
  ].each { |pattern| Warning.ignore(pattern) }
end

class Minitest::Test
  include Bento::TestHelperExtensions
end

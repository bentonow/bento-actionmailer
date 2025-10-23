# frozen_string_literal: true

require "test_helper"

class RailsVersionSupportTest < Minitest::Test
  def test_current_returns_nil_when_rails_missing
    without_rails do
      assert_nil BentoActionMailer::Support::RailsVersion.current
      refute BentoActionMailer::Support::RailsVersion.rails_7_or_higher?
    end
  end

  def test_detects_version_from_gem_version
    with_stubbed_rails(version: "7.0.1") do
      assert_equal Gem::Version.new("7.0.1"), BentoActionMailer::Support::RailsVersion.current
      assert BentoActionMailer::Support::RailsVersion.rails_7_or_higher?
    end
  end

  def test_detects_version_below_threshold
    with_stubbed_rails(version: "6.1.4") do
      assert_equal Gem::Version.new("6.1.4"), BentoActionMailer::Support::RailsVersion.current
      refute BentoActionMailer::Support::RailsVersion.rails_7_or_higher?
    end
  end
end

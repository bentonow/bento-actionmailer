# frozen_string_literal: true

require "test_helper"

class BentoRailtieTest < Minitest::Test
  INITIALIZER_NAME = "bento_action_mailer.add_delivery_method"

  def setup
    stub_rails_constants
    reload_railtie
  end

  def teardown
    restore_constant(:ActionMailer, @original_action_mailer)
    restore_constant(:ActiveSupport, @original_active_support)
    restore_constant(:Rails, @original_rails)
    BentoActionMailer.send(:remove_const, :Railtie) if BentoActionMailer.const_defined?(:Railtie)
  end

  def test_railtie_inherits_from_rails_railtie
    assert_operator BentoActionMailer::Railtie, :<, Rails::Railtie
  end

  def test_initializer_registered_with_expected_name_and_timing
    initializer = BentoActionMailer::Railtie.initializers.find { |entry| entry[:name] == INITIALIZER_NAME }
    refute_nil initializer, "Expected initializer #{INITIALIZER_NAME} to be registered"
    assert_equal "action_mailer.set_configs", initializer[:options][:before]
  end

  def test_initializer_adds_delivery_method_on_action_mailer_load
    capture = ActionMailer::Base.registered_methods
    refute capture.key?(:bento_actionmailer)

    run_action_mailer_callbacks

    assert_equal BentoActionMailer::DeliveryMethod, capture[:bento_actionmailer]
  end

  def test_initializer_is_idempotent
    run_action_mailer_callbacks
    run_action_mailer_callbacks

    assert_equal 1, ActionMailer::Base.registered_methods.length
    assert_equal BentoActionMailer::DeliveryMethod, ActionMailer::Base.registered_methods[:bento_actionmailer]
  end

  private

  def stub_rails_constants
    @original_rails = fetch_constant(:Rails)
    @original_active_support = fetch_constant(:ActiveSupport)
    @original_action_mailer = fetch_constant(:ActionMailer)

    remove_constant(:Rails)
    remove_constant(:ActiveSupport)
    remove_constant(:ActionMailer)

    rails_railtie = Class.new do
      class << self
        def initializers
          @initializers ||= []
        end

        def initializer(name, **options, &block)
          initializers << { name: name, options: options, block: block }
        end
      end
    end

    rails_module = Module.new
    rails_module.const_set(:Railtie, rails_railtie)
    Object.const_set(:Rails, rails_module)

    active_support = Module.new do
      class << self
        def callbacks
          @callbacks ||= Hash.new { |hash, key| hash[key] = [] }
        end

        def on_load(target, &block)
          callbacks[target] << block
        end
      end
    end
    Object.const_set(:ActiveSupport, active_support)

    mailer_base = Class.new do
      class << self
        def registered_methods
          @registered_methods ||= {}
        end
        def add_delivery_method(name, klass)
          registered_methods[name] = klass
        end
      end
    end

    action_mailer = Module.new
    action_mailer.const_set(:Base, mailer_base)
    Object.const_set(:ActionMailer, action_mailer)
  end

  def reload_railtie
    BentoActionMailer.send(:remove_const, :Railtie) if BentoActionMailer.const_defined?(:Railtie)
    load File.expand_path("../../lib/bento_actionmailer/railtie.rb", __dir__)
    BentoActionMailer::Railtie.initializers.each { |entry| entry[:block].call }
  end

  def run_action_mailer_callbacks
    ActiveSupport.callbacks[:action_mailer].each { |callback| callback.call }
  end

  def fetch_constant(name)
    Object.const_get(name)
  rescue NameError
    nil
  end

  def remove_constant(name)
    Object.send(:remove_const, name) if Object.const_defined?(name)
  end

  def restore_constant(name, original)
    remove_constant(name)
    Object.const_set(name, original) if original
  end
end

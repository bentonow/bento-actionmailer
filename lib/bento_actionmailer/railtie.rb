module BentoActionMailer
  class Railtie < Rails::Railtie
    initializer "bento_action_mailer.add_delivery_method", before: "action_mailer.set_configs" do
      ActiveSupport.on_load(:action_mailer) do
        ActionMailer::Base.add_delivery_method(:bento_actionmailer, BentoActionMailer::DeliveryMethod)
      end
    end
  end
end

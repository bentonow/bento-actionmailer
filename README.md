# Bento Actionmailer
<img align="right" src="https://app.bentonow.com/brand/logoanim.gif">

> [!TIP]
> Need help? Join our [Discord](https://discord.gg/ssXXFRmt5F) or email jesse@bentonow.com for personalized support.

The Bento Action Mailer gem makes it quick and easy to send transactional emails in your Ruby on Rails applications using Bento's HTTPS API. We provide a simple Action Mailer adapter that integrates seamlessly with Rails 4.2+, and automatically enables CSS inlining and dual-format payloads when your app is running on Rails 7.0 or newer.

Get started with our [📚 integration guides](https://docs.bentonow.com), or [📘 browse the SDK reference](https://docs.bentonow.com/subscribers).

🐶 Battle-tested at Datadoor.io and some of Bento's microservices.

❤️ Thank you @SebastianSzturo from [DataDoor](https://datadoor.io) for your contribution. Want to contribute? PRs welcome!


Table of contents
=================

<!--ts-->
* [Features](#features)
* [Requirements](#requirements)
* [Getting started](#getting-started)
    * [Installation](#installation)
    * [Configuration](#configuration)
    * [Installation Notes](#installation-notes)
* [Usage](#usage)
* [CSS Inlining (Rails 7.0+)](#css-inlining-rails-70)
* [Dual Format Support](#dual-format-support)
* [Things to Know](#things-to-know)
* [Contributing](#contributing)
* [License](#license)
<!--te-->

## Features

* **Simple integration**: Easily integrate with Rails' Action Mailer for sending transactional emails.
* **Bento API support**: Leverage Bento's HTTPS API for reliable email delivery.
* **Rails compatibility**: Works with Rails 4.2+ (CSS inlining activates automatically on Rails 7.0+).
* **CSS inlining (Rails 7.0+)**: Uses `premailer-rails` to inline `<style>` rules so messages render consistently across email clients.
* **Dual format support**: Sends HTML and plain text bodies in the same request for maximum deliverability.
* **Simplified email stack**: Ideal for straightforward applications looking to streamline their email infrastructure.

## Requirements

- Ruby on Rails 4.2+ (CSS inlining requires Rails 7.0 or newer)
- Bento account with API credentials
- `premailer-rails` (~> 1.11) — automatically required when your app runs on Rails 7.0+

## Getting started

### Installation

Add the gem to your application's Gemfile:

```ruby
gem 'bento-actionmailer', github: 'bentonow/bento-actionmailer', branch: 'main'
gem 'premailer-rails' # Requirement for Rails 7.0 apps and beyond. `premailer-rails` will inline all your CSS and ensure there is both an HTML and text version for every email (Bento uses this). 
```

Then run:

```bash
bundle install
```

### Configuration

Add the following to your `config/application.rb` or environment-specific configuration file:

```ruby
config.action_mailer.delivery_method = :bento_actionmailer
config.action_mailer.bento_actionmailer_settings = {
    site_uuid: "your-site-uuid",
    publishable_key: "your-publishable-key",
    secret_key: "your-secret-key"
}
```

### Installation Notes

- **Rails 7.0+**: CSS inlining is automatically enabled through `premailer-rails`. No additional configuration is required.
- **Rails 6.x and earlier**: Emails are delivered without CSS inlining, preserving the existing behaviour.
- **Backward compatibility**: Upgrading the gem in older Rails applications does not require code changes.

## Usage

Use Action Mailer as you normally would in your Rails application. The gem will handle sending emails through Bento's API.

```ruby
class WelcomeMailer < ApplicationMailer
  def welcome_email
    mail(to: 'user@example.com', subject: 'Welcome to Our App!')
  end
end
```

## CSS Inlining (Rails 7.0+)

On Rails 7.0 and newer, the adapter automatically loads `premailer-rails` and inlines your email styles before sending them to Bento. Inline styles are generated from:

- `<style>` tags embedded in your email templates
- Stylesheets referenced from within the HTML body
- Any Action Mailer layout styles

### Example

```html
<html>
  <head>
    <style>
      .header { background-color: #f0f0f0; padding: 10px; }
      .content { color: #333333; }
    </style>
  </head>
  <body>
    <div class="header">Welcome!</div>
    <div class="content">Thanks for joining us.</div>
  </body>
</html>
```

Is delivered as:

```html
<html>
  <body>
    <div class="header" style="background-color: #f0f0f0; padding: 10px;">Welcome!</div>
    <div class="content" style="color: #333333;">Thanks for joining us.</div>
  </body>
</html>
```

If premailer encounters an error, Bento Action Mailer logs the warning (when a Rails logger is available) and falls back to sending the original HTML.

## Dual Format Support

The delivery pipeline automatically captures both HTML and plain text parts and forwards them to Bento's API. Using Rails' standard mailer format blocks will populate both bodies:

```ruby
class NotificationMailer < ApplicationMailer
  def notification_email
    mail(to: 'user@example.com', subject: 'Notification') do |format|
      format.html { render 'notification_email' }
      format.text { render 'notification_email' }
    end
  end
end
```

When only one format is present, the API payload omits the missing body. If your mailer only renders a text part, Bento Action Mailer now generates a sanitized HTML wrapper on your behalf (Bento requires HTML in every request). Supplying only HTML still works as before—we do not auto-generate a plain text fragment.

## Things to Know

1. **CSS inlining** is available automatically for Rails 7.0+ projects. If the inliner encounters an error, the original HTML is delivered unchanged.
2. **Dual format delivery** forwards both HTML and plain text bodies when your mailer renders them.
3. **Text-only fallback**: Supplying only a text body is allowed. The adapter escapes and wraps the text in minimal HTML so Bento accepts the payload. We do **not** generate text from HTML; include your own text variant if you want a multipart email.
4. **Rails 6.x and earlier** continue to work without CSS inlining or additional configuration.
5. **BCC** delivery is not available in the current release.
6. **Attachments** are not supported yet.
7. **Custom email headers** are not supported at the moment.
8. For complex email setups, consider reaching out to the Bento team for support or contributing to the project.

## Contributing

We welcome contributions! Please see our [contributing guidelines](CODE_OF_CONDUCT.md) for details on how to submit pull requests, report issues, and suggest improvements.

## License

The Bento Action Mailer gem is available as open source under the terms of the [MIT License](LICENSE.md).

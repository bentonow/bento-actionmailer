# Bento Actionmailer
<img align="right" src="https://app.bentonow.com/brand/logoanim.gif">

> [!TIP]
> Need help? Join our [Discord](https://discord.gg/ssXXFRmt5F) or email jesse@bentonow.com for personalized support.

The Bento Action Mailer gem makes it quick and easy to send transactional emails in your Ruby on Rails applications using Bento's HTTPS API. We provide a simple Action Mailer adapter that integrates seamlessly with Rails 6 and above, leveraging Bento's excellent deliverability and support for marketing emails.

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
* [Usage](#usage)
* [Things to Know](#things-to-know)
* [Contributing](#contributing)
* [License](#license)
<!--te-->

## Features

* **Simple integration**: Easily integrate with Rails' Action Mailer for sending transactional emails.
* **Bento API support**: Leverage Bento's HTTPS API for reliable email delivery.
* **Rails compatibility**: Works with Rails 6 and above.
* **Simplified email stack**: Ideal for straightforward applications looking to streamline their email infrastructure.

## Requirements

- Ruby on Rails 6.0+
- Bento account with API credentials

## Getting started

### Installation

Add the gem to your application's Gemfile:

```ruby
gem 'bento-actionmailer', github: 'bentonow/bento-actionmailer', branch: 'main'
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

## Usage

Use Action Mailer as you normally would in your Rails application. The gem will handle sending emails through Bento's API.

```ruby
class WelcomeMailer < ApplicationMailer
  def welcome_email
    mail(to: 'user@example.com', subject: 'Welcome to Our App!')
  end
end
```

## Things to Know

1. Currently, the gem only supports HTML emails. Text-only emails are not supported yet.
2. BCC functionality is not available in the current version.
3. Attachments are not supported in this version of the gem.
4. Custom email headers are not supported at the moment.
5. For complex email setups, consider reaching out to the Bento team for support or contributing to the project.

## Contributing

We welcome contributions! Please see our [contributing guidelines](CODE_OF_CONDUCT.md) for details on how to submit pull requests, report issues, and suggest improvements.

## License

The Bento Action Mailer gem is available as open source under the terms of the [MIT License](LICENSE.md).

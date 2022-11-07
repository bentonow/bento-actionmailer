# Bento Action Mailer
[![Build Status](https://travis-ci.org/bentonow/bento-ruby-sdk.svg?branch=master)](https://travis-ci.org/bentonow/bento-ruby-sdk)

🍱 Beautifully simple transactional email for Ruby on Rails!

An Action Mailer adapter to send email using Bento's HTTPS API. Compatible with Rails 6 and above. 

👋 To get personalized support, please tweet @bento or email jesse@bentonow.com!

🐶 Battle-tested at Datadoor.io and some of Bento's microservices. 

❤️ Thank you @SebastianSzturo from [DataDoor](https://datadoor.io) for your contribution. Want to contribute? PRs welcome!

--------

**NOTE: The Bento Action Mailer gem is great for simple apps where simplifying your email stack makes sense. It leverages all the amazing deliverability and support you get with Bento's marketing email product. For more complex setups, spin up a thread on Discord to chat about how we can support it (or submit a PR!).**

A few things that might be missing in the API to fully support ActionMailer:
- [ ] Support for text emails, currently only supports HTML
- [ ] BCC
- [ ] Attachments
- [ ] Custom email headers

PRs and discussions welcome!

--------

## Installation

Install the gem and add to the application's Gemfile:

```
gem 'bento-actionmailer', github: 'bentonow/bento-actionmailer', branch: 'main'
```

## Usage

1. Add `:bento_actionmailer` as your delivery method in `application.rb` or one of the enviroment files.
2. Configure with your `site_uuid`, `publishable_key` and `secret_key`.

```ruby
config.action_mailer.delivery_method = :bento_actionmailer
config.action_mailer.bento_actionmailer_settings = {
    site_uuid: "...",
    publishable_key: "...",
    secret_key: "..."
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/bento-actionmailer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/bento-actionmailer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Bento::Actionmailer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/bento-actionmailer/blob/main/CODE_OF_CONDUCT.md).

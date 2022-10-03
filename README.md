# ENVelope

> **Note:** This gem is a prototype spike. The API is not yet stable.

## Big Picture

Single source of truth for application-wide configuration and environment variables.

the [12 Factor](http://12factor.net/config) application style is a good start, but the downside to environment variables
is that they can be leaked to untrustable subprocesses or 3rd party logging services.

### Features

* File schema
* Location defaults based on the [XDG](https://en.wikipedia.org/wiki/Freedesktop.org#Base_Directory_Specification) file
  location standard
* Distinction between configurations and secrets
* Secrets encrypted using [Lockbox](https://github.com/ankane/lockbox)
* Immutable

### Anti-Features

Things that ENVelope intentionally does **not** support include:

* Multiple config files
    * No subtle overrides
    * No implicit priority-ordering knowledge
* Modes
    * A testing environment should control itself
    * No forgetting to set the mode before running rake, etc
* Config file code interpretation (eg. ERB in YAML)
    * Security implications
    * File structure complexity
    * Value ambiguity

### But That's Bonkers

It might be! Some situations may legitimately need extremely complex configuration setups. But sometimes a complex
configuration environment is a code smell indicating that life could be better by:

* Reducing your application into smaller parts (eg. microservices etc)
* Reducing the number of service providers
* Improving your deployment process

You know your situation better than this README can.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'procrastinator'
```

And then run in a terminal:

    bundle install

## Usage

### Code

Assuming this file in `~/.config/my-app/config.yml`:

```yml
---
database:
  name: 'my_app_development'
  host: 'localhost'
```

Then in `my-app.rb`

```ruby
require 'dirt/envelope'

envelope = Dirt::ENVelope.new 'my-app'

# Prints "my_app_devleopment" 
puts envelope / :database / :host
```

### Rake Tasks

#### Configs

To create the config file, run this in a terminal:

    bundle exec rake envelope:create:configs

If a config file already exists in any of the search path locations, it will yell at you.

To edit the config file, run this in a terminal:

    bundle exec rake envelope:edit:configs

#### Secrets

To create the config file, run this in a terminal:

    bundle exec rake envelope:create:secrets

To edit the secrets file, run this and provide the file's encryption key:

    bundle exec rake envelope:edit:secrets

It will then open the decrypted file your default editor (eg. nano). Once you have saved the file, it will be
re-encrypted.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/TenjinInc/dirt-envelope.

This project is intended to be a friendly space for collaboration, and contributors are expected to adhere to the
[Contributor Covenant](http://contributor-covenant.org) code of conduct.

### Core Developers

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You
can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


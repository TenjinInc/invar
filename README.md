# ENVelope

> **Note:** This gem is a prototype spike. The API is not yet stable.

## Big Picture

Single source of truth for environmental configuration.

A [12 Factor](http://12factor.net/config) application style is a good start, but there are downsides using environment
variables for config:

* They are not groupable / nestable
* Secrets might be leaked to untrustable subprocesses or 3rd party logging services (eg. an error dump including the
  whole ENV)
* Cannot be easily checked against a schema for early error detection
* Ruby's core ENV does not accept symbols as keys, which is a minor nuisance.

### Features

Here's what this project aims to do:

* [planned] File schema using dry-schema
* Search path defaults based on
  the [XDG Base Directory](https://en.wikipedia.org/wiki/Freedesktop.org#Base_Directory_Specification)
  file location standard
* Distinction between configurations and secrets
* Secrets encrypted using [Lockbox](https://github.com/ankane/lockbox)
* Access ENV variables using symbols or case-insensitive strings.
* Helpful Rake tasks
* Meaningful error messages
* Immutable

### Anti-Features

Things that ENVelope intentionally does **not** support:

* Multiple config files
    * No subtle overrides
    * No confusion about file changes being ignored because you're editing the wrong file
    * No implicit priority-ordering knowledge
* Modes
    * A testing environment should control itself
    * No forgetting to set the mode before running rake, etc
    * No proliferation of irrelevant files
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

## Concepts

### XDG Base Directory

This is a standard that defines where applications should store their files (config, data, etc). The relevant summary
for config files is:

1. Look in `XDG_CONFIG_HOME`
    - Will be ignored when `$HOME` directory is undefined, usually system daemons.
    - Default: `~/.config/`
2. Then look in `XDG_CONFIG_DIRS`
    - A colon-separated list in priority order left to right.
    - Default: `/etc/xdg/`

You can check your values by running `env | grep XDG` in a terminal.

### Namespace

This is the name of the subdirectory under the XDG Base Directory. By default you should expect:

`~/.config/name-of-app`

or

`/etc/xdg/name-of-app`

### Configurations

Configurations are values that change based on the *system* the app is installed on. Examples include:

* Database name
* API options

### Secrets

This is stuff you don't want to be read by anyone. Rails calls this concept "credentials." Examples include:

* Usernames and passwords
* API keys

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'procrastinator'
```

And then run in a terminal:

    bundle install

## Usage

### Code

Assuming file `~/.config/my-app/config.yml` with:

```yml
---
database:
  name: 'my_app_development'
  host: 'localhost'
```

And an encrypted file `~/.config/my-app/secrets.yml` with:

```yml
---
database:
  user: 'my_app'
  pass: 'sekret'
```

Then in `my-app.rb`, you can fetch those values:

```ruby
require 'dirt/envelope'

envelope = Dirt::Envelope.new 'my-app'

# Prints "my_app_development" 
puts envelope / :config / :database / :host

# Prints "my_app" 
puts envelope / :secret / :database / :username
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

## Alternatives

Some other gems with different approaches:

- [RubyConfig](https://github.com/rubyconfig/config)
- [Anyway Config](https://github.com/palkan/anyway_config)
- [AppConfig](https://github.com/Oshuma/app_config)
- [Fiagro](https://github.com/laserlemon/figaro)

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


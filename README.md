# ENVelope

Single source of truth for environmental configuration.

## Big Picture

A [12 Factor](http://12factor.net/config) application style is a good start, but simple environment variables have
downsides:

* They are not groupable / nestable
* Secrets might be leaked to untrustable subprocesses or 3rd party logging services (eg. an error dump including the
  whole ENV)
* Cannot be easily checked against a schema for early error detection
* Ruby's core ENV does not accept symbols as keys (a minor nuisance, but it counts)

Here's what using Envelope looks like after you use the Rake tasks to manage your files:

```ruby
envelope = Dirt::Envelope.new

db_host = envelope / :config / :database / :host
```

### Features

Here's what this Gem provides:

* *[planned] File schema using dry-schema*
* Search path defaults based on
  the [XDG Base Directory](https://en.wikipedia.org/wiki/Freedesktop.org#Base_Directory_Specification)
  file location standard
* Distinction between configurations and secrets
* Secrets encrypted using [Lockbox](https://github.com/ankane/lockbox)
* Access ENV variables using symbols or case-insensitive strings.
* Helpful Rake tasks
* Meaningful error messages with suggestions
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
    * No file structure complexity
    * No value ambiguity

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

Configurations are values that depend on the *local system environment*. They do not generally change depending on what
you're *doing*. Examples include:

* Database name
* API options
* Gem or library configurations

### Secrets

This is stuff you don't want to be read by anyone. Rails calls this concept "credentials." Examples include:

* Usernames and passwords
* API keys

**This is not a replacement for a password-manager**. Use a
proper [password sharing tool](https://en.wikipedia.org/wiki/List_of_password_managers) as the primary method for
sharing passwords within your team. This is especially true for the master encryption key used to secure the secrets
file.

Similarly, you should use a unique encryption key for each environment (eg. your development laptop vs a server).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'procrastinator'
```

And then run in a terminal:

    bundle install

## Usage

### Testing

If you are not using `Bundler.require`, you will need to add this in your test suite setup file (eg.
RSpec `spec_helper.rb` or Cucumber `support/env.rb`):

```ruby
require 'dirt/envelope/rake'
```

Envelope will load the config file created by the Rake tasks (details in next section), but that will be the normal
runtime configuration. To nudge those values for testing you can register a block with `Dirt::Envelope.after_init` to
modify values before they are frozen.

```ruby
# Put this in a Cucumber `BeforeAll` or RSpec `before(:all)` hook (or similar)
Envelope.after_load do |envelope|
   (envelope / :config / :database).override name: 'my_app_test'
end

# ... later, in your actual application:
envelope = Envelope.new(namespace: 'my-app')
```

### Rake Tasks

In your `Rakefile`, add:

```ruby
require 'dirt/envelope/rake'
```

Then you can use the rake tasks as reported by `rake -T`

#### Show Search Paths

This will show you the XDG search locations.

    bundle exec rake envelope:paths

#### Create Config File

    bundle exec rake envelope:create:configs

If a config file already exists in any of the search path locations, it will yell at you.

#### Edit Config File

    bundle exec rake envelope:edit:configs

#### Create Secrets File

To create the config file, run this in a terminal:

    bundle exec rake envelope:create:secrets

It will print out the generated master key. Save it to a password manager.

If you do not want it to be displayed (eg. you're in public), you can pipe it to a file:

    bundle exec rake envelope:create:secrets > master_key

Then handle the `master_key` file as needed.

#### Edit Secrets File

To edit the secrets file, run this and provide the file's encryption key:

    bundle exec rake envelope:edit:secrets

The file will be decrypted and opened in your default editor (eg. nano). Once you have exited the editor, it will be
re-encrypted (remember to save, too!).

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

# Use the slash operator to fetch values (sort of like Pathname)
puts envelope / :config / :database / :host

# String keys are okay, too. Also it's case-insensitive
puts envelope / 'config' / 'database' / 'host'

# Secrets are kept in a separate tree 
puts envelope / :secret / :database / :username

# And you can get ENV variables. This should print your HOME directory.
puts envelope / :config / :home

# You can also use [] notation, if you really insist
puts envelope[:config][:database][:host]
```

> **FAQ**: Why not support a dot syntax like `envelope.config.database.host`?
>
> Because key names could collide with method names, like `inspect`, `dup`, or `tap`.

### Custom Locations

You can customize the search paths by setting the environment variables `XDG_CONFIG_HOME` and/or `XDG_CONFIG_DIRS` any
time you run a Rake task or your application.

    # Looks in /tmp instead of ~/.config/ 
    XDG_CONFIG_HOME=/tmp bundle exec rake envelope:paths

## Alternatives

Some other gems with different approaches:

- [RubyConfig](https://github.com/rubyconfig/config)
- [Anyway Config](https://github.com/palkan/anyway_config)
- [AppConfig](https://github.com/Oshuma/app_config)
- [Fiagro](https://github.com/laserlemon/figaro)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/TenjinInc/dirt-envelope.

Valued topics:

* Error messages (clarity, hinting)
* Documentation
* API
* Security correctness

This project is intended to be a friendly space for collaboration, and contributors are expected to adhere to the
[Contributor Covenant](http://contributor-covenant.org) code of conduct. Play nice.

### Core Developers

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You
can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Documentation is produced by Yard. Run `bundle exec rake yard`. The goal is to have 100% documentation coverage and 100%
test coverage.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


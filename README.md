# Invar

Single source of immutable truth for managing application configs, secrets, and environment variable data.

## Big Picture

Invar's main purpose is to enhance and simplify how applications know about their system environment and config.

Using it in code looks like this:

```ruby
invar = Invar.new(namespace: 'my-app')

db_host = invar / :config / :database / :host
```

### Background

Managing application config in a [12 Factor](http://12factor.net/config) style is a good idea, but simple environment
variables have some downsides:

* They are not groupable / nestable
* Secrets might be leaked to untrustable subprocesses or 3rd party logging services (eg. an error dump including the
  whole ENV)
* Secrets might be stored in plaintext (eg. in cron or scripts). It's better to store secrets as encrypted.
* Cannot be easily checked against a schema for early error detection
* Ruby's core ENV does not accept symbols as keys (a minor nuisance, but it counts)

> **Fun Fact:** Invar is named for an [alloy used in clockmaking](https://en.wikipedia.org/wiki/Invar) - it's short for "**invar**iable".

### Features

Here's what this Gem provides:

* File location defaults from
  the [XDG Base Directory](https://en.wikipedia.org/wiki/Freedesktop.org#Base_Directory_Specification)
  file location standard
* File schema using [dry-schema](https://dry-rb.org/gems/dry-schema/main/)
* Distinction between configs and secrets
* Secrets encrypted using [Lockbox](https://github.com/ankane/lockbox)
* Access configs and ENV variables using symbols or case-insensitive strings.
* Enforced key uniqueness
* Helpful Rake tasks
* Meaningful error messages with suggestions
* Immutable

### Anti-Features

Things that Invar intentionally does **not** support:

* Multiple config sources
    * No subtle overrides
    * No frustration about file edits not working... because you're editing the wrong file
    * No remembering finicky precedence order
* Modes
    * No forgetting to set the mode before running rake, etc
    * No proliferation of files irrelevant to the current situation
* Config file code interpretation (eg. ERB in YAML)
    * Reduced security hazard
    * No value ambiguity

### But That's Bonkers

It might be! This is a bit of an experiment. Some things may appear undesirable at first glance, but it's usually for a
reason.

Some situations might legitimately need a more complex configuration setup. But perhaps reflect on whether it's a code
smell nudging you to:

* Reduce your application into smaller parts (eg. microservices etc)
* Reduce the number of service providers
* Improve your collaboration or deployment procedures and automation

You know your situation better than this README can.

## Concepts and Jargon

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

### XDG Base Directory

This is a standard that defines where applications should store their files (config, data, etc). The relevant part is
that it looks in a couple of places for config files, declared in a pair of environment variables:

1. `XDG_CONFIG_HOME`
    - Note: Ignored when `$HOME` directory is undefined. Often the case for system daemons.
    - Default: `~/.config/`
2. `XDG_CONFIG_DIRS`
    - Fallback locations, declared as a colon-separated list in priority order.
    - Default: `/etc/xdg/`

You can check your current values by running this in a terminal:

    env | grep XDG

### Namespace

The name of the app's subdirectory under the relevant XDG Base Directory.

eg:

`~/.config/name-of-app`

or

`/etc/xdg/name-of-app`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'invar'
```

And then run in a terminal:

    bundle install

## Usage

### Testing

Invar automatically loads the normal runtime configuration from the config files created by the Rake tasks (details in
next section), but tests may need to override some of those values.

Call `#pretend` on the relevant selector:

```ruby
# Your application require Invar as normal:
require 'invar'

invar = Invar.new(namespace: 'my-app')

# ... then, in your test suite:
require 'invar/test'

# Usually this would be in a test suite hook, 
# like Cucumber's `BeforeAll` or RSpec's `before(:all)`
invar[:config][:theme].pretend dark_mode: true
```

Calling `#pretend` without requiring `invar/test` will raise an `ImmutableRealityError`.

To override values immediately after the config files are read, use an `Invar.after_load` block:

```ruby
Invar.after_load do |invar|
   invar[:config][:database].pretend name: 'my_app_test'
end

# This Invar will return database name 'my_app_test'
invar = Invar.new(namespace: 'my-app')

puts invar / :config / :database
```

### Rake Tasks

In your `Rakefile`, add:

```ruby
require 'invar/rake/tasks'

Invar::Rake::Tasks.define namespace: 'app-name-here'
```

Then you can use the rake tasks as reported by `rake -T`

#### Show Search Paths

This will show you the XDG search locations.

    bundle exec rake invar:paths

#### Create Config File

    bundle exec rake invar:create:configs

If a config file already exists in any of the search path locations, it will yell at you.

#### Edit Config File

    bundle exec rake invar:edit:configs

#### Create Secrets File

To create the config file, run this in a terminal:

    bundle exec rake invar:create:secrets

It will print out the generated master key. Save it to a password manager.

If you do not want it to be displayed (eg. you're in public), you can pipe it to a file:

    bundle exec rake invar:create:secrets > master_key

Then handle the `master_key` file as needed.

#### Edit Secrets File

To edit the secrets file, run this and provide the file's encryption key:

    bundle exec rake invar:edit:secrets

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
require 'invar'

invar = Invar.new 'my-app'

# Use the slash operator to fetch values (sort of like Pathname)
puts invar / :config / :database / :host

# String keys are okay, too. Also it's case-insensitive
puts invar / 'config' / 'database' / 'host'

# Secrets are kept in a separate tree 
puts invar / :secret / :database / :username

# And you can get ENV variables. This should print your HOME directory.
puts invar / :config / :home

# You can also use [] notation, which may be nicer in some situations (like #pretend)
puts invar[:config][:database][:host]
```

> **FAQ**: Why not support a dot syntax like `invar.config.database.host`?
>
> **A**: Because key names could collide with method names, like `inspect`, `dup`, or `tap`.

### Custom Locations

You can customize the search paths by setting the environment variables `XDG_CONFIG_HOME` and/or `XDG_CONFIG_DIRS` any
time you run a Rake task or your application.

    # Looks in /tmp instead of ~/.config/ 
    XDG_CONFIG_HOME=/tmp bundle exec rake invar:paths

## Alternatives

Some other gems with different approaches:

- [RubyConfig](https://github.com/rubyconfig/config)
- [Anyway Config](https://github.com/palkan/anyway_config)
- [AppConfig](https://github.com/Oshuma/app_config)
- [Fiagro](https://github.com/laserlemon/figaro)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/TenjinInc/invar.

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

Release notes are provided in `RELEASE_NOTES.md`, and should vaguely
follow [Keep A Changelog](https://keepachangelog.com/en/1.0.0/) recommendations.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


# Dirt::Envelope

Details like database connections, passwords, or credentials to external services are different between various 
deployments and installations (eg. local testing, CI testing, development, demoing, production, staging, ...). As 
described in the [12 Factor Application](http://12factor.net/config), environment variables are an excellent, 
scalable way to control these fundamental details of how your app interacts with the outside world. 

Ruby's built-in `ENV` is the official way to access the environment. The goal of Envelope is to make it even easier to 
use the environment. Envelope provides these main features: 

* Verification - if your app cannot work without some information, you can make it mandatory. 
* Namespacing - `ENV` hashes are already pretty full. Organize yours to make it easier to find values while debugging. 
* Symbol key access - Ruby's symbols are fantastic keys, so why not accept them?

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dirt-envelope'
```

And then execute:

    $ bundle

Or install it manually with:

    $ gem install dirt-envelope

## Usage
Envelope provides a `ENVELOPE` constant that wraps Ruby's basic `ENV` and adds these features: 
  
### Symbol Lookup
Works just like regular lookup, but with a symbol instead. Be aware that this does restrict your variable keys
to the legal symbol characters `[A-Za-z_]` ... but you should be using only those characters 
[anyway](http://stackoverflow.com/questions/2821043/allowed-characters-in-linux-environment-variable-names). 

```ruby
# These two lookups are identical
ENVELOPE['db_name']
ENVELOPE[:db_password']
```
  
### Declaring Mandatory Variables
Some information is just critical to your application doing anything at all. Call `#expect` with the list of mandatory 
variables. A good place for this is just under the `require` statements in a main config file. 

```ruby
ENVELOPE.expect :db_user, :db_name
```

If any of the listed variables are `nil` or empty, a `Dirt::Envelope::MissingEnvError` will be raised. 

### Declaring Expected Variables
Other information isn't mandatory in all situations, but should be checked for. Any variable listed with `#desire` will 
cause a warning to be issued to stderr.   

```ruby
ENVELOPE.desire :db_host,
                :db_password,
                :email_smtp_type,
                :email_smtp_user,
                :email_smtp_password,
                :email_smtp_port,
                :email_smtp_address
```


## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/TenjinInc/dirt-envelope.

This project is intended to be a friendly space for collaboration, and contributors are expected to adhere to the 
[Contributor Covenant](http://contributor-covenant.org) code of conduct.

### Core Developers
After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. 
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the 
version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, 
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


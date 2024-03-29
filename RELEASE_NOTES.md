# Release Notes

All notable changes to this project will be documented below.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project loosely follows
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Major Changes

* none

### Minor Changes

* none

### Bugfixes

* none

## [0.9.2] - 2024-03-03

### Major Changes

* none

### Minor Changes

* none

### Bugfixes

* Fixed load error in ruby 3.3 of not properly requiring Forwardable

## [0.9.1] - 2023-09-30

### Major Changes

* none

### Minor Changes

* none

### Bugfixes

* Improved handling of test-only methods when trying to access them via `#method`
* Fixed TTY detection

## [0.9.0] - 2023-09-24

### Major Changes

* none

### Minor Changes

* Added Rake task for secrets file key rotation
* Added ability for invar:config and invar:secrets to take replacement content over `STDIN` instead of live editing

### Bugfixes

* none

## [0.8.0] - 2023-09-13

### Major Changes

* none

### Minor Changes

* Increased minimum Ruby to 3.1

### Bugfixes

* none

## [0.7.0] - 2023-08-06

### Major Changes

* none

### Minor Changes

* Tweaked file missing error messages
* Extracted testing helper features into a separate module
* Added support for multiple after_load hooks

### Bugfixes

* No longer attempts to set secrets file permissions on every edit

## [0.6.1] - 2023-05-22

### Major Changes

* none

### Minor Changes

* none

### Bugfixes

* Fixed minor logic error in permissions checking, improved testing

## [0.6.0] - 2023-05-21

### Major Changes

* Simplified rake task syntax
    * Added `rake invar:init`
    * Now use `rake invar:config` and `rake invar:secrets`to edit

### Minor Changes

* Loosened file permission restrictions to allow group access as well
* Added file permissions checking to `config.yml` and `secrets.yml`

### Bugfixes

* none

## [0.5.1] - 2022-12-10

### Major Changes

*none

### Minor Changes

* none

### Bugfixes

* Fixed error message that showed blank filename when looking for lockbox master keyfile

## [0.5.0] - 2022-12-09

### Major Changes

* Renamed `Invar::Invar` to `Invar::Reality`
* Maintenance Rake task inclusion now requires explicit define call

### Minor Changes

* Expanded docs

### Bugfixes

* none

## [0.4.0] - 2022-12-08

### Major Changes

* Renamed project to Invar

### Minor Changes

* none

### Bugfixes

* `#pretend` symbolizes provided key(s)
* `Scope#to_h` recursively calls `.to_h` on subscopes

## [0.3.0] - Unreleased beta

### Major Changes

* none

### Minor Changes

* Added support for validation using dry-schema
* Added #key? to Scope

### Bugfixes

* none

## [0.2.0] - Unreleased Prototype

### Major Changes

* Overrides are now done with #pretend

### Minor Changes

* Master key is stripped of whitespace when read from file
* Added known keys to KeyError message
* Docs improvements

### Bugfixes

* none

## [0.1.0] - Unreleased Prototype

### Major Changes

* Initial prototype

### Minor Changes

* none

### Bugfixes

* none

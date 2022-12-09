# Release Notes

All notable changes to this project will be documented below.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project loosely follows
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Major Changes

* Renamed `Invar::Invar` to `Invar::Reality`

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

## [0.2.0] - Unreleased beta

### Major Changes

* Overrides are now done with #pretend

### Minor Changes

* Master key is stripped of whitespace when read from file
* Added known keys to KeyError message
* Docs improvements

### Bugfixes

* none

## [0.1.0] - Unreleased beta

### Major Changes

* Initial prototype

### Minor Changes

* none

### Bugfixes

* none

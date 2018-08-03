## [Unreleased]

## 1.1.0 - 2018-08-03
### Added
- StartOfAuthorityRecord type.
- Support for Swift 4.1.

### Changed
- All ResourceRecord fields are now modifable.

### Fixed
- Crash when encoding records with empty names.
- Crash when parsing invalid label sizes.

## 1.0.0 - 2017-10-07
### Added
- Support for Swift 4.
- Improved API documentation.
- Support for building on iOS.

### Changed
- Parser became more forgiving, replacing enums with integers where
  no all cases are known.

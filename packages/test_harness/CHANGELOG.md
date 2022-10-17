## 3.2.1

 - **FIX**: setup auto publishing pipeline format fixes. ([e94d6fb7](https://github.com/conduit-dart/conduit/commit/e94d6fb7f671c18ee347c851e62a85726db118ea))

## 3.2.1

 - **FIX**: setup auto publishing pipeline format fixes. ([b6124ee9](https://github.com/conduit-dart/conduit/commit/b6124ee9c9a578b5042e3c641373ddb45b1a5f17))

## 3.1.3

 - **REFACTOR**: use melos for mono-repo management. ([125099c5](https://github.com/conduit-dart/conduit/commit/125099c58e34e0e282c6fd0ec0cf0ec233bf92a1))

## 3.1.2

 - **REFACTOR**: use melos for mono-repo management. ([125099c5](https://github.com/conduit-dart/conduit/commit/125099c58e34e0e282c6fd0ec0cf0ec233bf92a1))

## 3.1.1

 - **REFACTOR**: use melos for mono-repo management.
 - **CHORE**: publish packages.

# 3.1.0

# 3.0.11

# 3.0.10

# 3.0.9

# 3.0.8

# 3.0.7
uptick version for multi release

# 3.0.5
Stable Conduit Release

# 2.0.0-b9
Fixed a bug with the conduit build command. We had left in dep overrides 
which should only be used for conduit internal dev.

# 2.0.0-b8
3rd attempt at first release.

# Conduit

# 2.0.0-b1

- Tooling works with conduit

# 2.0.0-a3
- broadened the version no. so works with any 2.0 version of conduit.
- Updated pubspec to pull conduit_test from pub.dev now that it is published.

## 2.0.0-a2

- Version bumps

## 2.0.0-a1

- Alpha release for Conduit NNBD included

# Conduit

## 1.0.1

- Fixes analysis warnings for Dart 2.1.1

## 1.0.0+1

- Bumps some dependency constraints to be more permissive

## 1.0.0

- Initial version from `package:conduit`.
- Adds `TestHarness` base class for test harnesses.
- Adds `TestHarnessORMMixin` for testing ORM applications.
- Adds `TestHarnessAuthMixin` for testing OAuth2 applications.
- Renames `TestClient` to `Agent` and adds methods for executing requests without constructing a `TestRequest`.
- Adds default parameters to `Agent` for its requests.

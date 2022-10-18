## 3.2.2

 - **FIX**: Improve CI all unit tests ([#119](https://github.com/conduit-dart/conduit/issues/119)). ([a80d3d22](https://github.com/conduit-dart/conduit/commit/a80d3d22e176aecd2433e20bda5aac1f209bd6f3))

## 3.2.1

 - **FIX**: setup auto publishing pipeline format fixes. ([e94d6fb7](https://github.com/conduit-dart/conduit/commit/e94d6fb7f671c18ee347c851e62a85726db118ea))

## 3.2.0

 - **REFACTOR**: use melos for mono-repo management. ([125099c5](https://github.com/conduit-dart/conduit/commit/125099c58e34e0e282c6fd0ec0cf0ec233bf92a1))
 - **FEAT**: Works with latest version of dart (2.19), CI works, websockets fixed, melos tasks added:wq. ([9e3d1a41](https://github.com/conduit-dart/conduit/commit/9e3d1a4146337a494ce34edca932aabb8506ccdb))

## 3.1.1

 - **REFACTOR**: use melos for mono-repo management.

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

# 2.0.0-b6
test_harness tests in parallel
fixed the dbname argument on psql command.
fixed the dependency overrides.
check if docker-composed is installed before trying to stop it.
corrected docker package name.
test to diagnose problems converting columns
Added check that we found conduit in the pub cache.
Fix: #44 Updated the message when a user trys to re-purpose an existing column as a inverse relationship.
Renamed cli_helper createProject to createTestProject to make its usage more obvious.
Switch to using the critical_test package to run unit tests.
used the paths package to simplify directory manipulation operations.
Fixed issues with create_test.dart not running under vs-code. Primary change was to move the test projects out of the conduit project structure into /tmp
Replaced all occurances of 'an conduit' with 'a conduit'
Fixed a bug in the orElse handling of decodeOptional and added a unit test to excersise the failing path.
Renamed private members to use _ prefix to facilitate human static analysis in serve.dart
Updated the decode command so it works correctly with nnbd. The conduit command are reliant on testing for null on an optional command. The decode method had been changed to never return null so the tests could no longer function. We now have two decode version, decode and decodeOptional. The decode version does not return null the docodeOptional will return null. This structure also has the advantage of not deplicating the default values of @options which was previously required. The changes also improve the exception handling. We now throw a singular CmdCIException rather than the two or three different exceptions that were previously been thrown. I also took the opportunity to improve the error messages for some of the common paths.
Updated to latest version of open_api and fixed nnbd issues as a result of changes in the open_api lib.

# Changelog

## 1.0.0-b1

- Initial release

# 2.0.0-b6
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
ignored .failed_tracker
Added logic to canced the signal stream otherwise the script would never shutdown.
test_harness tests in parallel
try without override
Merge branch 'develop' of github.com:conduit-dart/conduit into develop
change some specs
fixed the dbname argument on psql command.
fixed the dependency overrides.
check if docker-composed is installed before trying to stop it.
corrected docker package name.
Moved unit test script into ci project as it seemed like a more logical spot.
move imports
TODO: fix tooling tests
move common back
move common
should have branched, forgot to add
move directories into mono repo
unused imports.
test to diagnose problems converting columns
Added check that we found conduit in the pub cache.
Fix: #44 Updated the message when a user trys to re-purpose an existing column as a inverse relationship.
Renamed cli_helper createProject to createTestProject to make its usage more obvious.
Fixed unit tests which broke when we moved the test projects to /tmp as the conduit path was no longer relative. Now using Dcli's DartProject.fromPath to detect the correct path.
ingored stuff.
added fs-test-agent as a path based dependency.
Switch to using the critical_test package to run unit tests.
improved doco.
used the paths package to simplify directory manipulation operations.
Fixed issues with create_test.dart no running under vs-code. Primary change was to move the test projects out of the conduit project structure into /tmp
wip for fully automated unit tests from cli.
Replaced all occurances of 'an conduit' with 'a conduit'
Fixed a bug in the orElse handling of decodeOptional and added a unit test to excersise the failing path.
Renamed private members to use _ prefix to facilitate human static analysis in serve.dart
Merge branch 'develop' of github.com:conduit-dart/conduit into develop
Updated the decode command so it works correctly with nnbd. The conduit command are reliant on testing for null on an optional command. The decode method had been changed to never return null so the tests could no longer function. We now have two decode version, decode and decodeOptional. The decode version does not return null the docodeOptional will return null. This structure also has the advantage of not deplicating the default values of @options which was previously required. The changes also improve the exception handling. We now throw a singular CmdCIException rather than the two or three different exceptions that were previously been thrown. I also took the opportunity to improve the error messages for some of the common paths.
Updated to latest version of open_api and fixed nnbd issues as a result of changes in the open_api lib.
ignored .history

# Changelog

## 1.0.0-b1

- Initial release

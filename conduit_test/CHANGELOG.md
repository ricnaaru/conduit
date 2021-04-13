# 2.0.0-a3
broadened the version no. so works with any 2.0 version of conduit.
Updated pubspec to pull conduit_test from pub.dev now that it is published.
corrected indentation and removed bogus key from copy/paste fail.
manually merge from upstream.
Manually merged some changes from upstream.
Merge branch 'master' of https://github.com/conduit-dart/conduit
Moved the PostgresTestConfig into the package conduit_common_test and updated all unit tests to use the new configuration. Also updated ci to use the new default db settings.
ignored test generated code.
Attempts to fixe the can provide a single outage unit test. Still not working correctly.
All serve_test unit tests are passing after sorting out a few nnbd issues.
corrected the names of the certs to use conduit rather than aqueduct.
corrected the defaultTo of address to be explicitly 0.0.0.0
databaseType is optional.
Base map type takes a key? so had to mark as as covarient as tests wouldn't even start.
migrated to nnbd.
All compiler errors resulting from nnbd migration have now been resolved.
Now cleanly compiles with with all of the newly named packags.
Moved templates to their own repo conduit_templates
updated packages to a series of renames from aqueduct to conduit.
renamed referencese from Aqueduct to Conduit
change all reference to aqueduct to conduit.
renamed top level directories from aqueduct to conduit.
Merge open api and commons (#17)
Remove caching (#16)
Add workflow back (#15)
Nnbd ingegrate deps (#14)
Fixing the way aqueduct TestRequest serializes list query parameters (#4)
Merge pull request #1 from Reductions/insert-many-builder

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

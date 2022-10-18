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

# 1.0.0-b8
- Fix null-checking issue, tested against Conduit 

# 1.0.0-b7
upgraded to released version of dcli.
Moved back to resolveUri returning null to avoid breaking the existing api.

# 1.0.0-b6
patch changes for conduit beta

# 1.0.0-b5
simplify encoding

# 1.0.0-b4
fix empty v3 path

# 1.0.0-b3
Improved the readme.
Merge branch 'master' of https://github.com/noojee/open-api-dart-1
Merge remote-tracking branch 'upstream/master'
NNBD (#1)
replace travis with github actions
work on nndb migration and migration to conduit_codable (#1)

# 1.0.0-b2
restored the kubenetes test file as we found a v2 version. reverted some fields to be nullable as the document uses null to know that they were not present in the original document.
Remove the curl commands as the unit tests now fetch the required files themselves.
changed components so that they return a non-nullable list.

# 1.0.0-b1
Completed work on migrating to conduit_codable and nnbd migration.
Added lint package and resolved all automated fixes.
renamed project to conduit_open_api
nnbd migration
# Changelog

## 2.0.1

- Fix bug when merging APIResponse bodies

# 2.0.0

- Update for Dart 2

## 1.0.2

- Adds `APIResponse.addHeader` and `APIResponse.addContent`.
- Adds `APIOperation.addResponse`.

## 1.0.1 

- Adds `APISchemaObject.isFreeForm` and related support for free-form schema objects.

## 1.0.0

- Adds support for OpenAPI 3.0
- Splits Swagger (2.0) and OpenAPI (3.0) into 'package:conduit_open_api/v2.dart' and 'package:conduit_open_api/v3.dart'.

## 0.9.1

- Moves shared properties from `APISchema`, `APIHeader` and `APIParameter` into `APIProperty`.

## 0.9.0

- Initial data structures
- Parsing specifications
- Writing specifications to disk

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


# 1.0.0-b2
Invalided null check operator. extendedClause can be null. Changed to ? operator which will cause the comparison to fail which is what you would expect.
Was causing db migrations to fail.

Added repository to pubspec.yaml as pre publishing requirements.


# 1.0.0-b1
Initial release

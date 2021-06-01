#! /usr/bin/env dcli

import 'package:conduit_common/conduit_common.dart';
import 'package:dcli/dcli.dart';

/// This script will run the conduit unit tests
///
/// To run this script install dcli:
///
/// ```pub global activate dcli
/// ```
///
/// Then you can run:
///
/// ```
/// ./run_unit_tests.dart
/// ```
///
void main(List<String> args) {
  if (!whichEx('critical_test')) {
    print('Installing global package critical_test');
    DartSdk().globalActivate('critical_test');
  }
  if (!whichEx('pub_release')) {
    print('Installing global package pub_release');
    DartSdk().globalActivate('pub_release');
  }

  /// Required by conduit_config/test/config_test.dart
  env['TEST_VALUE'] = '1';
  env['TEST_BOOL'] = 'true';
  env['TEST_DB_ENV_VAR'] = 'postgres://user:password@host:5432/dbname';

  /// we use a fixed version no. for all of the projects.
  /// This avoid issues with pub publish bitching if some
  /// version no.s are beta releases and some not.
  var conduitProject = DartProject.fromPath(
      join(dirname(DartProject.fromPath('.').pathToProjectRoot), 'conduit'));
  final version = conduitProject.pubSpec.version;

  runEx('pub_release', args: 'multi --dry-run --no-git --setVersion=$version');
}

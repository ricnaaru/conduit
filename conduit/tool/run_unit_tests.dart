#! /usr/bin/env dcli

import 'dart:io';

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
  if (which('critical_test').notfound) {
    print('Installing global package critical_test');
    DartSdk().globalActivate('critical_test');
    exit(1);
  }
  'critical_test'.run;
}

#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

/// runs pub get on each project.
/// Use this method after cloning the repo to
/// ensure that all dependencies have been
/// downloaded
void main() {
  final project = DartProject.fromPath('.');

  find('pubspec.yaml', workingDirectory: dirname(project.pathToProjectRoot))
      .forEach((pubspec) {
    print('Running pub get for ${dirname(pubspec)}');
    DartSdk().runPubGet(dirname(pubspec), progress: Progress.printStdErr());
  });
}

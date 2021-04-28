#! /usr/bin/env dcli

import 'dart:io';

import 'package:dcli/dcli.dart';

import '../../db_settings.dart';
import '../../postgres_manager.dart';

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
  if (which('psql').notfound) {
    printerr(red(
        'Postgres not found. Have you run "install_unit_test_dependencies.dart".'));
    exit(1);
  }

  ProcessSignal.sigint.watch().listen((signal) {
    print('ctrl-caught');
    'docker-compose down'.run;
  });

  final projectRoot = DartProject.current.pathToProjectRoot;
  final pathToToolDir = join(projectRoot, 'tool');
  DartSdk().runPubGet(projectRoot);

  var dbSettings = DbSettings.load(pathToSettings: pathToToolDir);
  dbSettings.createEnvironmentVariables();

  var postgresManager = PostgresManager(dbSettings);

  if (dbSettings.useContainer) {
    print('Starting postgres docker image');
    postgresManager.startPostgresDaemon(pathToToolDir);
  }

  postgresManager.waitForPostgresToStart();

  print('recreating database');
  postgresManager.dropPostgresDb();
  postgresManager.dropUser();

  postgresManager.createPostgresDb();

  print(red('Activating local copy of conduit.'));
  // print(orange('You may want to revert this after the unit tests finish!'));

  // activate conduit from local sources
  DartSdk().globalActivateFromPath(projectRoot);

  print('Stopping posgress docker image');
  postgresManager.stopPostgresDaemon(pathToToolDir);
}

// void activate(String projectRoot,  package) {
//   'pub global activate $package --source=path'.start(
//       workingDirectory: truepath(projectRoot, '..'));
// }

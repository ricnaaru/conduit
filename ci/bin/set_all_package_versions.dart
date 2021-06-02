#! /usr/bin/env dcli

import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:pub_semver/pub_semver.dart';

/// Updates the version no.s of all top level packages.
///

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('version',
        abbr: 'v', help: 'The version no. to set all packages to.')
    ..addFlag('help', abbr: 'h', help: 'Shows this help message');

  final parsed = parser.parse(args);

  if (!parsed.wasParsed('version')) {
    printerr(red('You must pass a version.'));
    showUseage(parser);
  }

  final version = parsed['version'] as String;

  final rootOfMonoRepo =
      truepath(DartProject.fromPath('.').pathToProjectRoot, '..');
  final projects = find('*',
          types: [Find.directory],
          recursive: false,
          workingDirectory: rootOfMonoRepo)
      .toList();

  final knownProjects = <PubSpec>[];
  for (final project in projects) {
    final pubspecPath = join(project, 'pubspec.yaml');
    if (exists(pubspecPath)) {
      final pubspec = PubSpec.fromFile(pubspecPath);
      pubspec.version = Version.parse(version);
      pubspec.saveToFile(pubspecPath);
      knownProjects.add(pubspec);
    }
  }

  final hatVersion = '^$version';

  // now update dependencies for the 'known' project
  // which we have changed.
  // We add a hat ^ to the start of the version no
  // to make pub publish happy (it doesn't like overly constrained version numbers)
  for (final project in projects) {
    final pubspecPath = join(project, 'pubspec.yaml');
    if (exists(pubspecPath)) {
      final pubspec = PubSpec.fromFile(pubspecPath);

      var replacementDependencies = <String, Dependency>{};

      /// Update the version no. for any known dependency whos version
      /// we have just changed.
      for (var dependency in pubspec.dependencies.values) {
        final known = findKnown(knownProjects, dependency);
        if (known != null) {
          replacementDependencies[dependency.name] =
              (Dependency.fromHosted(dependency.name, hatVersion));
        } else {
          replacementDependencies[dependency.name] = dependency;
        }
      }
      pubspec.dependencies = replacementDependencies;
      pubspec.saveToFile(pubspecPath);
      knownProjects.add(pubspec);
    }
  }
  print(orange('Done.'));
}

PubSpec? findKnown(List<PubSpec> knownProjects, Dependency dependency) {
  for (var known in knownProjects) {
    if (known.name == dependency.name) {
      return known;
    }
  }
  return null;
}

void showUseage(ArgParser parser) {
  print(blue('Usage: ${DartScript.self.basename} --version=x.x.x'));
  print('');
  print('''
Sets the version no. of every top level pubspec.yaml to the same version no.
We then update all of the dependency constraints setting the entered version as the minimum value''');
  print(parser.usage);
  exit(1);
}

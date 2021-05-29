import 'dart:io';

import 'package:dcli/dcli.dart';

/// Docker functions
void installDocker() {
  if (which('docker').found) {
    print('Using an existing docker install.');
    return;
  }

  if (isAptInstalled()) {
    print('Installing docker daemon');
    'apt --assume-yes install dockerd'.start(privileged: true);
  } else {
    printerr(
        red('Docker is not installed. Please install docker and start again.'));
    exit(1);
  }
}

/// Docker-Compose functions
void installDockerCompose() {
  if (which('docker-compose').found) {
    print('Using an existing docker-compose install.');
    return;
  }

  if (isAptInstalled()) {
    print('Installing docker-compose');
    'apt --assume-yes install docker-compose'.start(privileged: true);
  } else {
    printerr(red(
        'Docker-Compose is not installed. Please install docker-compose and start again.'));
    exit(1);
  }
}

bool isAptInstalled() => which('apt').notfound;

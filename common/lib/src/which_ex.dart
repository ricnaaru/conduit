import 'dart:io';

import 'package:dcli/dcli.dart';

bool whichEx(String exeName) {
  return which(exeName).found ||
      (Platform.isWindows &&
          (which('$exeName.exe').found || which('$exeName.bat').found));
}

void runEx(String exeName,
    {required String args, required String workingDirectory}) {
  if (Platform.isWindows) {
    if (which('$exeName.exe').found) {
      '$exeName.exe $args'.start(
          workingDirectory: workingDirectory, progress: Progress.print());
      return;
    }
    if (which('$exeName.bat').found) {
      '$exeName.bat $args'.start(
          workingDirectory: workingDirectory, progress: Progress.print());
      return;
    }
  }
  '$exeName $args'
      .start(workingDirectory: workingDirectory, progress: Progress.print());
}

import 'dart:io';

import 'package:dcli/dcli.dart';

bool whichEx(String exeName) {
  return which(exeName).found ||
      (Platform.isWindows &&
          (which('$exeName.exe').found || which('$exeName.exe').found));
}

void runEx(String exeName, {required String args}) {
  if (Platform.isWindows) {
    if (which('$exeName.exe').found) {
      '$exeName.exe $args'.run;
      return;
    }
    if (which('$exeName.bat').found) {
      '$exeName.bat $args'.run;
      return;
    }
  }
  '$exeName $args'.run;
}

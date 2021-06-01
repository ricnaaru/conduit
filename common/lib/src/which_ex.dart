import 'dart:io';

import 'package:dcli/dcli.dart';

bool whichEx(String exeName) {
  return which('psql').found ||
      (Platform.isWindows &&
          (which('psql.exe').found || which('psql.exe').found));
}

void runEx(String exeName, {required String args}) {
  if (Platform.isWindows) {
    if (which('$exeName.exe').found) {
      '$exeName.exe $args'.run;
      return;
    }
    if (which('$exeName.bat $args').found) {
      '$exeName.bat'.run;
      return;
    }

    '$exeName $args'.run;
  }
}

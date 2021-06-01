import 'dart:io';

import 'package:dcli/dcli.dart';

bool whichEx(String exeName) {
  return which('psql').found ||
      (Platform.isWindows &&
          (which('psql.exe').found || which('psql.exe').found));
}

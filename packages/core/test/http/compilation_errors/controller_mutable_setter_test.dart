import 'dart:async';

import 'package:conduit_core/conduit_core.dart';
import 'package:conduit_runtime/runtime.dart';
import 'package:test/test.dart';

void main() {
  test(
    "A controller that is not Recyclable, but declares a setter throws a runtime error",
    () {
      try {
        // ignore: unnecessary_statements
        RuntimeContext.current;
        fail('unreachable');
      } on StateError catch (e) {
        expect(e.toString(), contains("MutableSetterController"));
      }
    },
  );
}

class MutableSetterController extends Controller {
  set mutableSetter(String s) {}

  @override
  FutureOr<RequestOrResponse> handle(Request request) {
    return request;
  }
}

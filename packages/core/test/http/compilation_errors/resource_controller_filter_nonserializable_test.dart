import 'dart:async';

import 'package:conduit_core/conduit_core.dart';
import 'package:conduit_runtime/runtime.dart';
import "package:test/test.dart";

void main() {
  test("Cannot bind invalid type to default implementation", () {
    try {
      // ignore: unnecessary_statements
      RuntimeContext.current;
      fail('unreachable');
    } on StateError catch (e) {
      expect(
        e.toString(),
        // ignore: missing_whitespace_between_adjacent_strings
        "Bad state: Invalid binding 'a' on 'FilterNonSerializable.get1':"
        "Filters can only be used on Serializable or List<Serializable>.",
      );
    }
  });
}

class FilterNonSerializable extends ResourceController {
  @Operation.post()
  Future<Response> get1(
    @Bind.body(ignore: ["id"]) Map<String, dynamic> a,
  ) async {
    return Response.ok(null);
  }
}

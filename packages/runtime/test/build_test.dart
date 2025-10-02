import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conduit_runtime/runtime.dart';
import 'package:test/test.dart';

/*
need test with normal package, relative package, git package
need to test for local (relative), in pub cache (absolute)
*/

void main() {
  final tmp = Directory.current.uri.resolve("../tmp/");

  group("No environment variables injected", () {
    setUpAll(() async {
      final testPackagesUri = Directory.current.uri
          .resolve("../")
          .resolve("runtime_test_packages/");

      final appDir = testPackagesUri.resolve("application/");
      final appLib = appDir.resolve("lib/").resolve("application.dart");
      final ctx = BuildContext(
        appLib,
        tmp,
        tmp.resolve("app.aot"),
        File.fromUri(appDir.resolve("bin/").resolve("main.dart"))
            .readAsStringSync(),
      );
      final bm = BuildManager(ctx);
      await bm.build();
    });

    tearDownAll(() {
      Directory.fromUri(tmp).deleteSync(recursive: true);
    });

    test("Non-compiled version returns mirror runtimes", () async {
      final output = await dart(
        Directory.current.uri
            .resolve("../")
            .resolve("runtime_test_packages/")
            .resolve("application/"),
      );
      expect(json.decode(output), {
        "Consumer": "mirrored",
        "ConsumerSubclass": "mirrored",
        "ConsumerScript": "mirrored",
      });
    });

    test(
        "Compiled version of application returns source generated runtimes and can be AOT compiled",
        () async {
      final output = await runExecutable(
        tmp.resolve("app.aot"),
        Directory.current.uri
            .resolve("../")
            .resolve("runtime_test_packages/")
            .resolve("application/"),
      );
      expect(json.decode(output), {
        "Consumer": "generated",
        "ConsumerSubclass": "generated",
        "ConsumerScript": "generated",
      });
    });
  });

  group("Environment variables injected", () {
    setUpAll(() async {
      final testPackagesUri = Directory.current.uri
          .resolve("../")
          .resolve("runtime_test_packages/");

      final appDir = testPackagesUri.resolve("application/");
      final appLib = appDir.resolve("lib/").resolve("application.dart");
      final ctx = BuildContext(
        appLib,
        tmp,
        tmp.resolve("app.aot"),
        File.fromUri(appDir.resolve("bin/").resolve("main.dart"))
            .readAsStringSync(),
        environment: {"FOO": "BAR"},
      );
      final bm = BuildManager(ctx);
      await bm.build();
    });

    tearDownAll(() {
      Directory.fromUri(tmp).deleteSync(recursive: true);
    });
    test("Compiled version of application can access environment variables",
        () async {
      final output = await runExecutable(
        tmp.resolve("app.aot"),
        Directory.current.uri
            .resolve("../")
            .resolve("runtime_test_packages/")
            .resolve("application/"),
      );
      expect(json.decode(output), {
        "Consumer": "generated",
        "ConsumerSubclass": "generated",
        "ConsumerScript": "generated",
        "FOO": "BAR",
      });
    });
  });
}

Future<String> dart(Uri workingDir) async {
  final result = await Process.run(
    "dart",
    ["bin/main.dart"],
    workingDirectory: workingDir.toFilePath(windows: Platform.isWindows),
    runInShell: true,
  );
  return result.stdout.toString();
}

Future<String> runExecutable(Uri buildUri, Uri workingDir) async {
  final result = await Process.run(
    buildUri.toFilePath(windows: Platform.isWindows),
    [],
    workingDirectory: workingDir.toFilePath(windows: Platform.isWindows),
    runInShell: true,
  );
  return result.stdout.toString();
}

import 'dart:io';

import 'package:fs_test_agent/dart_project_agent.dart';
import 'package:fs_test_agent/working_directory_agent.dart';
import 'package:test/test.dart';

import 'not_tests/cli_helpers.dart';

void main() {
  late CLIClient templateCli;
  late CLIClient projectUnderTestCli;

  setUpAll(() async {
    templateCli = await CLIClient(
      WorkingDirectoryAgent(DartProjectAgent.projectsDirectory),
    ).createTestProject();

    await templateCli.agent.getDependencies();
  });

  tearDownAll(DartProjectAgent.tearDownAll);

  setUp(() async {
    projectUnderTestCli = templateCli.replicate(Uri.parse("replica/"));
    projectUnderTestCli.projectAgent.addLibraryFile("application_test", """
import 'package:conduit_core/conduit_core.dart';
import 'package:conduit_postgresql/conduit_postgresql.dart';

class TestObject extends ManagedObject<_TestObject> {}

class _TestObject {
  @primaryKey
  int? id;

  String? foo;
}
      """);
  });

  tearDown(() {
    projectUnderTestCli.delete();
  });

  test("If validating with no migration dir, get error", () async {
    final res = await projectUnderTestCli.run("db", ["validate"]);

    expect(res, isNot(0));
    expect(projectUnderTestCli.output, contains("No migration files found"));
  });

  test("Validating two equal schemas succeeds", () async {
    var res = await projectUnderTestCli.run("db", ["generate"]);
    expect(res, 0);

    res = await projectUnderTestCli.run("db", ["validate"]);
    expect(res, 0);
    expect(projectUnderTestCli.output, contains("Validation OK"));
    expect(projectUnderTestCli.output, contains("version is 1"));
  });

  test("Validating different schemas fails", () async {
    var res = await projectUnderTestCli.run("db", ["generate"]);
    expect(res, 0);

    projectUnderTestCli.agent
        .modifyFile("migrations/00000001_initial.migration.dart", (contents) {
      const upgradeLocation = "upgrade()";
      final nextLine =
          contents.indexOf("\n", contents.indexOf(upgradeLocation));
      return contents.replaceRange(nextLine, nextLine + 1, """
        database.createTable(SchemaTable("foo", []));
        """);
    });

    res = await projectUnderTestCli.run("db", ["validate"]);
    expect(res, isNot(0));
    expect(projectUnderTestCli.output, contains("Validation failed"));
  });

  test(
    "Validating runs all migrations in directory and checks the total product",
    () async {
      var res = await projectUnderTestCli.run("db", ["generate"]);
      expect(res, 0);

      projectUnderTestCli.agent.modifyFile(
        "migrations/00000001_initial.migration.dart",
        (contents) {
          const upgradeLocation = "upgrade()";
          final nextLine =
              contents.indexOf("\n", contents.indexOf(upgradeLocation));
          return contents.replaceRange(
            nextLine,
            nextLine + 1,
            'database.createTable(SchemaTable("foo", []));\n',
          );
        },
      );

      res = await projectUnderTestCli.run("db", ["validate"]);
      expect(res, isNot(0));
      expect(projectUnderTestCli.output, contains("Validation failed"));

      res = await projectUnderTestCli.run("db", ["generate"]);
      expect(res, 0);

      final secondMigrationFile = File.fromUri(
        projectUnderTestCli.defaultMigrationDirectory.uri
            .resolve("00000002_unnamed.migration.dart"),
      );
      expect(
        secondMigrationFile.readAsStringSync(),
        contains('database.deleteTable("foo")'),
      );

      res = await projectUnderTestCli.run("db", ["validate"]);
      expect(res, 0);
    },
  );
}

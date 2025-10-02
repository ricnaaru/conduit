import 'dart:async';

import 'package:conduit/src/command.dart';
import 'package:conduit/src/migration_source.dart';
import 'package:conduit/src/mixins/database_connecting.dart';
import 'package:conduit/src/mixins/database_managing.dart';
import 'package:conduit/src/mixins/project.dart';
import 'package:conduit/src/scripts/run_upgrade.dart';
import 'package:conduit_core/conduit_core.dart';
import 'package:conduit_isolate_exec/conduit_isolate_exec.dart';
import 'package:conduit_postgresql/conduit_postgresql.dart';

/// Used internally.
class CLIDatabaseUpgrade extends CLICommand
    with CLIDatabaseConnectingCommand, CLIDatabaseManagingCommand, CLIProject {
  @override
  Future<int> handle() async {
    final migrations = projectMigrations;

    if (migrations.isEmpty) {
      displayInfo("No migration files.");
      displayProgress("Run 'conduit db generate' first.");
      return 0;
    }

    try {
      final currentVersion = await persistentStore.schemaVersion;
      final appliedMigrations = migrations
          .where((mig) => mig.versionNumber <= currentVersion)
          .toList();
      final migrationsToExecute = migrations
          .where((mig) => mig.versionNumber > currentVersion)
          .toList();
      if (migrationsToExecute.isEmpty) {
        displayInfo(
          "Database version is already current (version: $currentVersion).",
        );
        return 0;
      }

      if (currentVersion == 0) {
        displayInfo(
          "Updating to version ${migrationsToExecute.last.versionNumber} on new database...",
        );
      } else {
        displayInfo(
          "Updating to version ${migrationsToExecute.last.versionNumber} from version $currentVersion...",
        );
      }

      final currentSchema =
          await schemaByApplyingMigrationSources(appliedMigrations);

      await executeMigrations(
        migrationsToExecute,
        currentSchema,
        currentVersion,
      );
    } on QueryException catch (e) {
      if (e.event == QueryExceptionEvent.transport) {
        final databaseUrl =
            "${connectedDatabase.username}:${connectedDatabase.password}@${connectedDatabase.host}:${connectedDatabase.port}/${connectedDatabase.databaseName}";
        throw CLIException(
          "There was an error connecting to the database '$databaseUrl'. Reason: ${e.message}.",
        );
      }

      rethrow;
    }
    return 0;
  }

  @override
  String get name {
    return "upgrade";
  }

  @override
  String get description {
    return "Executes migration files against a database.";
  }

  Future<Schema> executeMigrations(
    List<MigrationSource> migrations,
    Schema fromSchema,
    int fromVersion,
  ) async {
    final schemaMap = await IsolateExecutor.run(
      RunUpgradeExecutable.input(
        fromSchema,
        _storeConnectionInfo!,
        migrations,
        fromVersion,
      ),
      packageConfigURI: packageConfigUri,
      imports: RunUpgradeExecutable.imports,
      additionalContents: MigrationSource.combine(migrations),
      additionalTypes: [DBInfo],
      logHandler: displayProgress,
    );

    if (schemaMap.containsKey("error")) {
      throw CLIException(schemaMap["error"] as String?);
    }

    return Schema.fromMap(schemaMap);
  }

  DBInfo? get _storeConnectionInfo {
    final s = persistentStore;
    if (s is PostgreSQLPersistentStore) {
      return DBInfo(
        "postgres",
        s.username,
        s.password,
        s.host,
        s.port,
        s.databaseName,
        s.timeZone,
        sslMode: s.sslMode,
      );
    }

    return null;
  }
}

import 'dart:async';

import 'package:conduit_core/conduit_core.dart';
import 'postgresql_query.dart';
import 'postgresql_schema_generator.dart';
import 'package:postgres/postgres.dart';

extension ToSslMode on String? {
  SslMode toSslMode() {
    switch (this) {
      case "disable":
        return SslMode.disable;
      case "require":
        return SslMode.require;
      case "verifyFull":
        return SslMode.verifyFull;
    }
    return SslMode.disable;
  }
}

/// The database layer responsible for carrying out [Query]s against PostgreSQL databases.
///
/// To interact with a PostgreSQL database, a [ManagedContext] must have an instance of this class.
/// Instances of this class are configured to connect to a particular PostgreSQL database.
class PostgreSQLPersistentStore extends PersistentStore
    with PostgreSQLSchemaGenerator {
  /// Creates an instance of this type from connection info.
  PostgreSQLPersistentStore(
    this.username,
    this.password,
    this.host,
    this.port,
    this.databaseName, {
    this.timeZone = "UTC",
    this.sslMode,
    @Deprecated('Use sslMode instead') bool useSSL = false,
  }) : isSSLConnection = useSSL || sslMode.toSslMode() != SslMode.disable;

  /// Same constructor as default constructor.
  ///
  /// Kept for backwards compatability.
  PostgreSQLPersistentStore.fromConnectionInfo(
    this.username,
    this.password,
    this.host,
    this.port,
    this.databaseName, {
    this.timeZone = "UTC",
    this.sslMode,
    @Deprecated('Use sslMode instead') bool useSSL = false,
  }) : isSSLConnection = useSSL || sslMode.toSslMode() != SslMode.disable;

  PostgreSQLPersistentStore._from(PostgreSQLPersistentStore from)
      : isSSLConnection =
            from.isSSLConnection || from.sslMode.toSslMode() != SslMode.disable,
        username = from.username,
        password = from.password,
        host = from.host,
        port = from.port,
        databaseName = from.databaseName,
        timeZone = from.timeZone,
        sslMode = from.sslMode;

  factory PostgreSQLPersistentStore._transactionProxy(
    PostgreSQLPersistentStore parent,
    TxSession ctx,
  ) {
    return _TransactionProxy(parent, ctx);
  }

  /// The logger used by instances of this class.
  static Logger logger = Logger("conduit");

  /// The username of the database user for the database this instance connects to.
  final String? username;

  /// The password of the database user for the database this instance connects to.
  final String? password;

  /// The host of the database this instance connects to.
  final String? host;

  /// The port of the database this instance connects to.
  final int? port;

  /// The name of the database this instance connects to.
  final String? databaseName;

  /// The time zone of the connection to the database this instance connects to.
  final String? timeZone;

  /// Whether this connection is established over SSL.
  final bool isSSLConnection;

  /// The SSL mode of the connection to the database.
  final String? sslMode;

  /// Whether or not the underlying database connection is open.
  ///
  /// Connections are automatically opened when a query is executed, so this property should not be used
  /// under normal operation. See [getDatabaseConnection].
  bool get isConnected {
    if (_databaseConnection == null) {
      return false;
    }

    return _databaseConnection!.isOpen;
  }

  /// Amount of time to wait before connection fails to open.
  ///
  /// Defaults to 30 seconds.
  final Duration connectTimeout = const Duration(seconds: 30);

  static final Finalizer<Connection> _finalizer =
      Finalizer((connection) => connection.close());

  Connection? _databaseConnection;
  Completer<Connection>? _pendingConnectionCompleter;

  /// Retrieves the query execution context of this store.
  ///
  /// Use this property to execute raw queries on the underlying database connection.
  /// If running a transaction, this context is the transaction context.
  Future<Session> get executionContext => getDatabaseConnection();

  /// Retrieves a connection to the database this instance connects to.
  ///
  /// If no connection exists, one will be created. A store will have no more than one connection at a time.
  ///
  /// When executing queries, prefer to use [executionContext] instead. Failure to do so might result
  /// in issues when executing queries during a transaction.
  Future<Connection> getDatabaseConnection() async {
    if (_databaseConnection == null || !_databaseConnection!.isOpen) {
      if (_pendingConnectionCompleter == null) {
        _pendingConnectionCompleter = Completer<Connection>();

        _connect().timeout(connectTimeout).then((conn) {
          _databaseConnection = conn;
          _pendingConnectionCompleter!.complete(_databaseConnection);
          _pendingConnectionCompleter = null;
          _finalizer.attach(this, _databaseConnection!, detach: this);
        }).catchError((e) {
          _pendingConnectionCompleter!.completeError(
            QueryException.transport(
              "unable to connect to database",
              underlyingException: e,
            ),
          );
          _pendingConnectionCompleter = null;
        });
      }

      return _pendingConnectionCompleter!.future;
    }

    return _databaseConnection!;
  }

  @override
  Query<T> newQuery<T extends ManagedObject>(
    ManagedContext context,
    ManagedEntity entity, {
    T? values,
  }) {
    final query = PostgresQuery<T>.withEntity(context, entity);
    if (values != null) {
      query.values = values;
    }
    return query;
  }

  @override
  Future<dynamic> execute(
    String sql, {
    Map<String, dynamic>? substitutionValues,
    Duration? timeout,
  }) async {
    timeout ??= const Duration(seconds: 30);
    final now = DateTime.now().toUtc();
    final dbConnection = await executionContext;
    try {
      final rows = await dbConnection.execute(
        Sql.named(sql),
        parameters: substitutionValues,
        timeout: timeout,
        queryMode: QueryMode.extended,
      );

      final mappedRows = rows.map((row) => row.toList()).toList();
      logger.finest(
        () =>
            "Query:execute (${DateTime.now().toUtc().difference(now).inMilliseconds}ms) $sql -> $mappedRows",
      );
      return mappedRows;
    } on ServerException catch (e) {
      final interpreted = _interpretException(e);
      if (interpreted != null) {
        throw interpreted;
      }

      rethrow;
    }
  }

  @override
  Future close() async {
    await _databaseConnection?.close();
    _finalizer.detach(this);
    _databaseConnection = null;
  }

  @override
  Future<T> transaction<T>(
    ManagedContext transactionContext,
    Future<T> Function(ManagedContext transaction) transactionBlock,
  ) async {
    final Connection dbConnection = await getDatabaseConnection();

    try {
      return await dbConnection.runTx((dbTransactionContext) async {
        transactionContext.persistentStore =
            PostgreSQLPersistentStore._transactionProxy(
          this,
          dbTransactionContext,
        );

        try {
          return await transactionBlock(transactionContext);
        } on Rollback {
          /// user triggered a manual rollback.
          /// TODO: there is currently no reliable way for a user to detect
          /// that a manual rollback occured.
          /// The documented method of checking the return value from this method
          /// does not work.
          await dbTransactionContext.rollback();
          rethrow;
        }
      });
    } on ServerException catch (e) {
      final interpreted = _interpretException(e);
      if (interpreted != null) {
        throw interpreted;
      }

      rethrow;
    }
  }

  @override
  Future<int> get schemaVersion async {
    try {
      final values = await execute(
        "SELECT versionNumber, dateOfUpgrade FROM $versionTableName ORDER BY dateOfUpgrade ASC",
      ) as List<List<dynamic>>;
      if (values.isEmpty) {
        return 0;
      }

      final version = await values.last.first;
      return version as int;
    } on ServerException catch (e) {
      if (e.code == PostgreSQLErrorCode.undefinedTable) {
        return 0;
      }
      rethrow;
    }
  }

  @override
  Future<Schema> upgrade(
    Schema fromSchema,
    List<Migration> withMigrations, {
    bool temporary = false,
  }) async {
    final Connection connection = await getDatabaseConnection();

    Schema schema = fromSchema;

    await connection.runTx((ctx) async {
      final transactionStore =
          PostgreSQLPersistentStore._transactionProxy(this, ctx);
      await _createVersionTableIfNecessary(ctx, temporary);

      withMigrations.sort((m1, m2) => m1.version!.compareTo(m2.version!));

      for (final migration in withMigrations) {
        migration.database =
            SchemaBuilder(transactionStore, schema, isTemporary: temporary);
        migration.database.store = transactionStore;

        final existingVersionRows = await ctx.execute(
          Sql.named(
              "SELECT versionNumber, dateOfUpgrade FROM $versionTableName WHERE versionNumber >= @v:int4"),
          parameters: {"v": migration.version},
          queryMode: QueryMode.extended,
        );
        if (existingVersionRows.isNotEmpty) {
          final date = existingVersionRows.first.last;
          throw MigrationException(
            "Trying to upgrade database to version ${migration.version}, but that migration has already been performed on $date.",
          );
        }

        logger.info("Applying migration version ${migration.version}...");
        await migration.upgrade();

        for (final cmd in migration.database.commands) {
          logger.info("\t$cmd");
          await ctx.execute(cmd);
        }

        logger.info(
          "Seeding data from migration version ${migration.version}...",
        );
        await migration.seed();

        await ctx.execute(
          "INSERT INTO $versionTableName (versionNumber, dateOfUpgrade) VALUES (${migration.version}, '${DateTime.now().toUtc().toIso8601String()}')",
        );

        logger
            .info("Applied schema version ${migration.version} successfully.");

        schema = migration.currentSchema;
      }
    });

    return schema;
  }

  @override
  Future<dynamic> executeQuery(
    String formatString,
    Map<String, dynamic>? values,
    int timeoutInSeconds, {
    PersistentStoreQueryReturnType? returnType =
        PersistentStoreQueryReturnType.rows,
  }) async {
    final now = DateTime.now().toUtc();
    try {
      final dbConnection = await executionContext;
      final Result results = await dbConnection.execute(
        Sql.named(formatString),
        parameters: values,
        timeout: Duration(seconds: timeoutInSeconds),
        queryMode: QueryMode.extended,
      );

      logger.fine(
        () =>
            "Query (${DateTime.now().toUtc().difference(now).inMilliseconds}ms) $formatString Substitutes: ${values ?? "{}"} -> $results",
      );

      return returnType == PersistentStoreQueryReturnType.rows
          ? results
          : results.affectedRows;
    } on TimeoutException catch (e) {
      throw QueryException.transport(
        "timed out connection to database",
        underlyingException: e,
      );
    } on ServerException catch (e) {
      logger.fine(
        () =>
            "Query (${DateTime.now().toUtc().difference(now).inMilliseconds}ms) $formatString $values",
      );
      logger.warning(e.toString);
      final interpreted = _interpretException(e);
      if (interpreted != null) {
        throw interpreted;
      }
      rethrow;
    } on PgException catch (e) {
      throw QueryException.transport(
        e.message,
        underlyingException: e,
      );
    }
  }

  QueryException<ServerException>? _interpretException(
    ServerException exception,
  ) {
    switch (exception.code) {
      case PostgreSQLErrorCode.uniqueViolation:
        return QueryException.conflict(
          "entity_already_exists",
          ["${exception.tableName}.${exception.columnName}"],
          underlyingException: exception,
        );
      case PostgreSQLErrorCode.notNullViolation:
        return QueryException.input(
          "non_null_violation",
          ["${exception.tableName}.${exception.columnName}"],
          underlyingException: exception,
        );
      case PostgreSQLErrorCode.foreignKeyViolation:
        return QueryException.input(
          "foreign_key_violation",
          ["${exception.tableName}.${exception.columnName}"],
          underlyingException: exception,
        );
    }

    return null;
  }

  Future _createVersionTableIfNecessary(
    TxSession context,
    bool temporary,
  ) async {
    final table = versionTable;
    final commands = createTable(table, isTemporary: temporary);
    final exists = await context.execute(
      Sql.named("SELECT to_regclass(@tableName:text)"),
      parameters: {"tableName": table.name},
      queryMode: QueryMode.extended,
    );

    if (exists.first.first != null) {
      return;
    }

    logger.info("Initializating database...");
    for (final cmd in commands) {
      logger.info("\t$cmd");
      await context.execute(cmd);
    }
  }

  Future<Connection> _connect() {
    logger.info("PostgreSQL connecting, $username@$host:$port/$databaseName.");
    return Connection.open(
      Endpoint(
        host: host!,
        database: databaseName!,
        port: port!,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(
        timeZone: timeZone!,
        sslMode: sslMode.toSslMode(),
        ignoreSuperfluousParameters: true,
      ),
    );
  }
}

/// Commonly used error codes from PostgreSQL.
///
/// When a [QueryException.underlyingException] is a [PostgreSQLException], this [PostgreSQLException.code]
/// value may be one of the static properties declared in this class.
class PostgreSQLErrorCode {
  static const String duplicateTable = "42P07";
  static const String undefinedTable = "42P01";
  static const String undefinedColumn = "42703";
  static const String uniqueViolation = "23505";
  static const String notNullViolation = "23502";
  static const String foreignKeyViolation = "23503";
}

class _TransactionProxy extends PostgreSQLPersistentStore {
  _TransactionProxy(this.parent, this.context) : super._from(parent);

  final PostgreSQLPersistentStore parent;
  final TxSession context;

  @override
  Future<Session> get executionContext async => context;
}

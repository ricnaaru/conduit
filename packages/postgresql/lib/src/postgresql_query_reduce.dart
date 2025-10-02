import 'dart:async';
import 'package:conduit_core/conduit_core.dart';
import 'package:postgres/postgres.dart';
import 'builders/column.dart';
import 'postgresql_persistent_store.dart';
import 'postgresql_query.dart';
import 'query_builder.dart';

enum _Reducer {
  avg,
  count,
  max,
  min,
  sum,
}

class PostgresQueryReduce<T extends ManagedObject>
    extends QueryReduceOperation<T> {
  PostgresQueryReduce(this.query) : builder = PostgresQueryBuilder(query);

  final PostgresQuery<T> query;
  final PostgresQueryBuilder builder;

  @override
  Future<double?> average(num? Function(T object) selector) {
    return _execute<double?>(
      _Reducer.avg,
      query.entity.identifyAttribute(selector),
    );
  }

  @override
  Future<int> count() {
    return _execute<int>(_Reducer.count);
  }

  @override
  Future<U?> maximum<U>(U? Function(T object) selector) {
    return _execute<U?>(_Reducer.max, query.entity.identifyAttribute(selector));
  }

  @override
  Future<U?> minimum<U>(U? Function(T object) selector) {
    return _execute<U?>(_Reducer.min, query.entity.identifyAttribute(selector));
  }

  @override
  Future<U?> sum<U extends num>(U? Function(T object) selector) {
    return _execute<U?>(_Reducer.sum, query.entity.identifyAttribute(selector));
  }

  String _columnName(ManagedAttributeDescription? property) {
    if (property == null) {
      // This should happen only in count
      return "1";
    }
    final columnBuilder = ColumnBuilder(builder, property);
    return columnBuilder.sqlColumnName(withTableNamespace: true);
  }

  String _function(_Reducer reducer, ManagedAttributeDescription? property) {
    return "${reducer.toString().split('.').last}" // The aggregation function
        "(${_columnName(property)})" // The Column for the aggregation
        "${reducer == _Reducer.avg ? '::float' : ''}"; // Optional cast to float for AVG
  }

  Future<U> _execute<U>(
    _Reducer reducer, [
    ManagedAttributeDescription? property,
  ]) async {
    if (builder.containsSetJoins) {
      throw StateError(
        "Invalid query. Cannot use 'join(set: ...)' with 'reduce' query.",
      );
    }
    final buffer = StringBuffer();
    buffer.write("SELECT ${_function(reducer, property)} ");
    buffer.write("FROM ${builder.sqlTableName} ");

    if (builder.containsJoins) {
      buffer.write("${builder.sqlJoin} ");
    }

    if (builder.sqlWhereClause != null) {
      buffer.write("WHERE ${builder.sqlWhereClause} ");
    }

    final store = query.context.persistentStore as PostgreSQLPersistentStore;
    final connection = await store.executionContext;
    try {
      final result = await connection.execute(
        Sql.named(buffer.toString()),
        parameters: builder.variables,
        queryMode: QueryMode.extended,
        timeout: Duration(seconds: query.timeoutInSeconds),
      );
      return result.first.first as U;
    } on TimeoutException catch (e) {
      throw QueryException.transport(
        "timed out connecting to database",
        underlyingException: e,
      );
    }
  }
}

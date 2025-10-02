import 'package:collection/collection.dart' show IterableExtension;
import 'package:conduit_core/conduit_core.dart';

import '../postgresql_query.dart';
import 'column.dart';
import 'expression.dart';
import 'sort.dart';

class TableBuilder implements Returnable {
  TableBuilder(PostgresQuery query, {this.parent, this.joinedBy})
      : entity = query.entity,
        _manualPredicate = query.predicate {
    if (parent != null) {
      tableAlias = createTableAlias();
    }
    returning = ColumnBuilder.fromKeys(this, query.propertiesToFetch);

    columnSortBuilders = query.sortDescriptors
        .map((s) => ColumnSortBuilder(this, s.key, s.order))
        .toList();
    if (query.sortPredicate != null) {
      columnSortBuilders.add(
        ColumnSortPredicateBuilder(
          this,
          query.sortPredicate!.predicate,
          query.sortPredicate!.order,
        ),
      );
    }

    if (query.pageDescriptor != null) {
      columnSortBuilders.add(
        ColumnSortBuilder(
          this,
          query.pageDescriptor!.propertyName,
          query.pageDescriptor!.order,
        ),
      );

      if (query.pageDescriptor!.boundingValue != null) {
        final prop = entity.properties[query.pageDescriptor!.propertyName];
        final operator = query.pageDescriptor!.order == QuerySortOrder.ascending
            ? PredicateOperator.greaterThan
            : PredicateOperator.lessThan;
        final expr = ColumnExpressionBuilder(
          this,
          prop,
          ComparisonExpression(
            query.pageDescriptor!.boundingValue,
            operator,
          ),
        );
        expressionBuilders.add(expr);
      }
    }

    query.subQueries.forEach((relationshipDesc, subQuery) {
      addJoinTableBuilder(
        TableBuilder(
          subQuery as PostgresQuery,
          parent: this,
          joinedBy: relationshipDesc,
        ),
      );
    });

    addColumnExpressions(query.expressions);
  }

  TableBuilder.implicit(
    this.parent,
    ManagedRelationshipDescription this.joinedBy,
  )   : entity = joinedBy.inverse!.entity,
        _manualPredicate = QueryPredicate.empty() {
    tableAlias = createTableAlias();
    returning = <Returnable>[];
    columnSortBuilders = [];
  }

  final ManagedEntity entity;
  final TableBuilder? parent;
  final ManagedRelationshipDescription? joinedBy;
  final List<ColumnExpressionBuilder> expressionBuilders = [];
  String? tableAlias;
  QueryPredicate? predicate;
  late List<ColumnSortBuilder> columnSortBuilders;
  late List<Returnable> returning;
  int aliasCounter = 0;

  final QueryPredicate? _manualPredicate;

  bool get containsJoins => returning.any((p) => p is TableBuilder);

  bool get containsSetJoins => returning
      .whereType<TableBuilder>()
      .any((tb) => tb.isSetJoin || tb.containsSetJoins);

  bool get isSetJoin =>
      joinedBy?.relationshipType == ManagedRelationshipType.hasMany;

  ManagedRelationshipDescription? get foreignKeyProperty =>
      joinedBy!.relationshipType == ManagedRelationshipType.belongsTo
          ? joinedBy
          : joinedBy!.inverse;

  bool isJoinOnProperty(ManagedRelationshipDescription relationship) {
    return joinedBy!.destinationEntity == relationship.destinationEntity &&
        joinedBy!.entity == relationship.entity &&
        joinedBy!.name == relationship.name;
  }

  List<ColumnBuilder> get flattenedColumnsToReturn {
    return returning.fold(<ColumnBuilder>[], (prev, c) {
      if (c is TableBuilder) {
        prev.addAll(c.flattenedColumnsToReturn);
      } else if (c is ColumnBuilder) {
        prev.add(c);
      }
      return prev;
    });
  }

  QueryPredicate get joiningPredicate {
    ColumnBuilder left;
    ColumnBuilder right;
    if (identical(foreignKeyProperty, joinedBy)) {
      left = ColumnBuilder(parent, joinedBy);
      right = ColumnBuilder(this, entity.primaryKeyAttribute);
    } else {
      left = ColumnBuilder(parent, parent!.entity.primaryKeyAttribute);
      right = ColumnBuilder(this, joinedBy!.inverse);
    }

    final leftColumn = left.sqlColumnName(withTableNamespace: true);
    final rightColumn = right.sqlColumnName(withTableNamespace: true);
    return QueryPredicate("$leftColumn=$rightColumn");
  }

  String createTableAlias() {
    if (parent != null) {
      return parent!.createTableAlias();
    }

    tableAlias ??= "t0";
    aliasCounter++;
    return "t$aliasCounter";
  }

  void finalize(Map<String, dynamic> variables) {
    final allExpressions = [
      if (_manualPredicate != null) _manualPredicate,
      ...expressionBuilders.map((c) => c.predicate)
    ];
    predicate = QueryPredicate.and(allExpressions);
    variables.addAll(predicate!.parameters);
    returning.whereType<TableBuilder>().forEach((r) {
      r.finalize(variables);
    });
  }

  void addColumnExpressions(
    List<QueryExpression<dynamic, dynamic>> expressions,
  ) {
    for (final expression in expressions) {
      final firstElement = expression.keyPath.path.first;
      final lastElement = expression.keyPath.path.last;

      final bool isPropertyOnThisEntity = expression.keyPath.length == 1;
      final bool isForeignKey = expression.keyPath.length == 2 &&
          lastElement is ManagedAttributeDescription &&
          lastElement.isPrimaryKey &&
          firstElement is ManagedRelationshipDescription &&
          firstElement.isBelongsTo;

      if (isPropertyOnThisEntity) {
        final bool isBelongsTo =
            lastElement is ManagedRelationshipDescription &&
                lastElement.isBelongsTo;
        final bool isColumn =
            lastElement is ManagedAttributeDescription || isBelongsTo;

        if (isColumn) {
          // This will occur if we selected a column.
          final expr =
              ColumnExpressionBuilder(this, lastElement, expression.expression);
          expressionBuilders.add(expr);
          continue;
        }
      } else if (isForeignKey) {
        // This will occur if we selected a belongs to relationship or a belongs to relationship's
        // primary key. In either case, this is a column in this table (a foreign key column).
        final expr = ColumnExpressionBuilder(
          this,
          expression.keyPath.path.first,
          expression.expression,
        );
        expressionBuilders.add(expr);
        continue;
      }

      addColumnExpressionToJoinedTable(expression);
    }
  }

  void addColumnExpressionToJoinedTable(
    QueryExpression<dynamic, dynamic> expression,
  ) {
    final TableBuilder joinedTable = _findJoinedTable(expression.keyPath);
    final lastElement = expression.keyPath.path.last;
    if (lastElement is ManagedRelationshipDescription) {
      final inversePrimaryKey = lastElement.inverse!.entity.primaryKeyAttribute;
      final expr = ColumnExpressionBuilder(
        joinedTable,
        inversePrimaryKey,
        expression.expression,
        prefix: tableAlias!,
      );
      expressionBuilders.add(expr);
    } else {
      final expr = ColumnExpressionBuilder(
        joinedTable,
        lastElement,
        expression.expression,
        prefix: tableAlias!,
      );
      expressionBuilders.add(expr);
    }
  }

  TableBuilder _findJoinedTable(KeyPath keyPath) {
    // creates & joins a TableBuilder for any relationship in keyPath
    // if it doesn't exist.
    if (keyPath.length == 0) {
      return this;
    } else if (keyPath.length == 1 &&
        keyPath[0] is! ManagedRelationshipDescription) {
      return this;
    } else {
      final head = keyPath[0] as ManagedRelationshipDescription?;
      TableBuilder? join = returning
          .whereType<TableBuilder>()
          .firstWhereOrNull((m) => m.isJoinOnProperty(head!));
      if (join == null) {
        join = TableBuilder.implicit(this, head!);
        addJoinTableBuilder(join);
      }
      return join._findJoinedTable(KeyPath.byRemovingFirstNKeys(keyPath, 1));
    }
  }

  void addJoinTableBuilder(TableBuilder r) {
    returning.add(r);

    // If we're fetching the primary key of the joined table, remove
    // the foreign key from the columns returning from this table.
    // They are the same value, but this guarantees the row instantiator
    // that it only sees the value once and makes its logic more straightforward.
    if (r.returning.isNotEmpty) {
      returning.removeWhere((m) {
        if (m is ColumnBuilder) {
          return identical(m.property, r.joinedBy);
        }

        return false;
      });
    }

    columnSortBuilders.addAll(r.columnSortBuilders);
  }

  /*
      Methods that return portions of a SQL statement for this object
   */

  String get sqlTableName {
    if (tableAlias == null) {
      return entity.tableName;
    }

    return "${entity.tableName} $tableAlias";
  }

  String get sqlTableReference => tableAlias ?? entity.tableName;

  String get sqlInnerSelect {
    final nestedJoins =
        returning.whereType<TableBuilder>().map((t) => t.sqlJoin).join(" ");

    final flattenedColumns = flattenedColumnsToReturn;

    final columnsWithNamespace = flattenedColumns
        .map((p) => p.sqlColumnName(withTableNamespace: true))
        .join(",");
    final columnsWithoutNamespace =
        flattenedColumns.map((p) => p.sqlColumnName()).join(",");

    final outerWhereString = " WHERE ${predicate!.format}";
    final selectString =
        "SELECT $columnsWithNamespace FROM $sqlTableName $nestedJoins";
    final alias = "$sqlTableReference($columnsWithoutNamespace)";
    return "LEFT OUTER JOIN ($selectString$outerWhereString) $alias ON ${joiningPredicate.format}";
  }

  String get sqlJoin {
    if (parent == null) {
      return returning
          .whereType<TableBuilder>()
          .map((e) => e.sqlJoin)
          .join(" ");
    }

    // At this point, we know that this table is being joined.
    // If we have a predicate that references a column in a joined table,
    // then we can't use a simple join, we have to use an inner select.
    final joinedTables = returning.whereType<TableBuilder>().toList();
    if (expressionBuilders.any((e) => joinedTables.contains(e.table))) {
      return sqlInnerSelect;
    }

    final totalJoinPredicate = QueryPredicate.and(
        [joiningPredicate, if (predicate != null) predicate!]);
    final thisJoin =
        "LEFT OUTER JOIN $sqlTableName ON ${totalJoinPredicate.format}";

    if (returning.any((p) => p is TableBuilder)) {
      final nestedJoins = returning.whereType<TableBuilder>().map((p) {
        return p.sqlJoin;
      }).toList();
      nestedJoins.insert(0, thisJoin);
      return nestedJoins.join(" ");
    }

    return thisJoin;
  }
}

import 'package:postgres/postgres.dart';

import 'column.dart';
import 'table.dart';
import 'package:conduit_core/conduit_core.dart';

class ColumnExpressionBuilder extends ColumnBuilder {
  ColumnExpressionBuilder(
    TableBuilder super.table,
    super.property,
    this.expression, {
    this.prefix = "",
  });

  final String prefix;
  PredicateExpression? expression;

  String get defaultPrefix => "$prefix${table!.sqlTableReference}_";

  QueryPredicate get predicate {
    final expr = expression;
    if (expr is ComparisonExpression) {
      return comparisonPredicate(expr.operator, expr.value);
    } else if (expr is RangeExpression) {
      return rangePredicate(expr.lhs, expr.rhs, insideRange: expr.within);
    } else if (expr is NullCheckExpression) {
      return nullPredicate(isNull: expr.shouldBeNull);
    } else if (expr is SetMembershipExpression) {
      return containsPredicate(expr.values, within: expr.within);
    } else if (expr is StringExpression) {
      return stringPredicate(
        expr.operator,
        expr.value,
        caseSensitive: expr.caseSensitive,
        invertOperator: expr.invertOperator,
        allowSpecialCharacters: expr.allowSpecialCharacters,
      );
    }

    throw UnsupportedError(
      "Unknown expression applied to 'Query'. '${expr.runtimeType}' is not supported by 'PostgreSQL'.",
    );
  }

  QueryPredicate comparisonPredicate(
    PredicateOperator? operator,
    dynamic value,
  ) {
    final name = sqlColumnName(withTableNamespace: true);
    final variableName = sqlColumnName(withPrefix: defaultPrefix);

    return QueryPredicate(
      "$name ${ColumnBuilder.symbolTable[operator!]} @$variableName",
      {
        variableName: TypedValue(ColumnBuilder.typeMap[property!.type!.kind]!,
            convertValueForStorage(value)),
      },
    );
  }

  QueryPredicate containsPredicate(
    Iterable<dynamic> values, {
    bool within = true,
  }) {
    final tokenList = [];
    final pairedMap = <String, TypedValue>{};

    var counter = 0;
    for (final value in values) {
      final prefix = "$defaultPrefix${counter}_";

      final variableName = sqlColumnName(withPrefix: prefix);
      tokenList.add("@$variableName");
      pairedMap[variableName] = TypedValue(
          ColumnBuilder.typeMap[property!.type!.kind]!,
          convertValueForStorage(value));

      counter++;
    }

    final name = sqlColumnName(withTableNamespace: true);
    final keyword = within ? "IN" : "NOT IN";
    return QueryPredicate("$name $keyword (${tokenList.join(",")})", pairedMap);
  }

  QueryPredicate nullPredicate({bool isNull = true}) {
    final name = sqlColumnName(withTableNamespace: true);
    return QueryPredicate("$name ${isNull ? "ISNULL" : "NOTNULL"}", {});
  }

  QueryPredicate rangePredicate(
    dynamic lhsValue,
    dynamic rhsValue, {
    bool insideRange = true,
  }) {
    final name = sqlColumnName(withTableNamespace: true);
    final lhsName = sqlColumnName(withPrefix: "${defaultPrefix}lhs_");
    final rhsName = sqlColumnName(withPrefix: "${defaultPrefix}rhs_");
    final operation = insideRange ? "BETWEEN" : "NOT BETWEEN";

    return QueryPredicate("$name $operation @$lhsName AND @$rhsName", {
      lhsName: TypedValue(ColumnBuilder.typeMap[property!.type!.kind]!,
          convertValueForStorage(lhsValue)),
      rhsName: TypedValue(ColumnBuilder.typeMap[property!.type!.kind]!,
          convertValueForStorage(rhsValue)),
    });
  }

  QueryPredicate stringPredicate(
    PredicateStringOperator operator,
    String value, {
    bool caseSensitive = true,
    bool invertOperator = false,
    bool allowSpecialCharacters = true,
  }) {
    final n = sqlColumnName(withTableNamespace: true);
    final variableName = sqlColumnName(withPrefix: defaultPrefix);

    var matchValue = allowSpecialCharacters ? value : escapeLikeString(value);

    var operation = caseSensitive ? "LIKE" : "ILIKE";
    if (invertOperator) {
      operation = "NOT $operation";
    }
    switch (operator) {
      case PredicateStringOperator.beginsWith:
        matchValue = "$matchValue%";
        break;
      case PredicateStringOperator.endsWith:
        matchValue = "%$matchValue";
        break;
      case PredicateStringOperator.contains:
        matchValue = "%$matchValue%";
        break;
      default:
        break;
    }

    return QueryPredicate(
      "$n $operation @$variableName",
      {variableName: TypedValue(Type.text, matchValue)},
    );
  }

  String escapeLikeString(String input) {
    return input.replaceAllMapped(
      RegExp(r"(\\|%|_)"),
      (Match m) => "\\${m[0]}",
    );
  }
}

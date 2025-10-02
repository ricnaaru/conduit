import 'dart:async';

import 'package:conduit_core/conduit_core.dart';
import 'package:test/test.dart';

import '../not_tests/postgres_test_config.dart';

void main() {
  group("Multiple contexts, same data model", () {
    final dm = ManagedDataModel([T, U]);

    ManagedContext? ctx1;
    late ManagedContext ctx2;

    setUp(() async {
      ctx1 = await contextWithDataModel(dm);
      ctx2 = await contextWithDataModel(dm);
    });

    tearDown(() async {
      await ctx1?.close();
      await ctx2.close();
    });

    test("Queries are sent to the correct database", () async {
      final q = Query<T>(ctx1!)..values.name = "bob";
      await q.insert();

      final t1 = await Query<T>(ctx1!).fetch();
      final t2 = await Query<T>(ctx2).fetch();

      expect(t1.length, 1);
      expect(t1.first.name, "bob");
      expect(t2.length, 0);
    });

    test("If one context is released, other context's is OK", () async {
      var q = Query<T>(ctx1!)..values.name = "bob";
      await q.insert();

      await ctx1!.close();
      ctx1 = null;

      q = Query<T>(ctx2)..values.name = "fred";
      await q.insert();

      final t2 = await Query<T>(ctx2).fetch();

      expect(t2.length, 1);
      expect(t2.first.name, "fred");
    });
  });

  group("Multiple contexts, different data model", () {
    late ManagedContext ctx1;
    late ManagedContext ctx2;

    setUp(() async {
      ctx1 = await contextWithDataModel(ManagedDataModel([T]));
      ctx2 = await contextWithDataModel(ManagedDataModel([U]));
    });

    tearDown(() async {
      await ctx1.close();
      await ctx2.close();
    });

    test("Queries are sent to the appropriate database", () async {
      final t1 = await Query<T>(ctx1).fetch();
      final t2 = await Query<U>(ctx2).fetch();

      expect(t1.length, 0);
      expect(t2.length, 0);
    });

    test(
        "Cannot create query on context whose data model doesn't contain query type",
        () async {
      try {
        Query<T>(ctx2);
        fail('unreachable');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains("Invalid context"));
      }

      try {
        Query<U>(ctx1);
        fail('unreachable');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains("Invalid context"));
      }
    });
  });
}

class _T {
  @primaryKey
  int? id;

  String? name;
}

class T extends ManagedObject<_T> implements _T {}

class _U {
  @primaryKey
  int? id;
  String? name;
}

class U extends ManagedObject<_U> implements _U {}

Future<ManagedContext> contextWithDataModel(ManagedDataModel dataModel) async {
  final persistentStore = PostgresTestConfig().persistentStore();

  final commands =
      PostgresTestConfig().commandsFromDataModel(dataModel, temporary: true);
  final context = ManagedContext(dataModel, persistentStore);

  for (final cmd in commands) {
    await persistentStore.execute(cmd);
  }

  return context;
}

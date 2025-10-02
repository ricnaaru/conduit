import 'dart:async';

import 'package:conduit_core/conduit_core.dart';

class RootObject extends ManagedObject<_RootObject> implements _RootObject {
  RootObject();
  RootObject.withCounter() {
    value1 = counter;
    value2 = counter;
    counter++;
  }

  static int counter = 1;

  @override
  bool operator ==(Object other) => other is RootObject && rid == other.rid;

  @override
  int get hashCode => rid!;
}

class _RootObject {
  @primaryKey
  int? rid;

  int? value1;
  int? value2;

  ManagedSet<ChildObject>? children;
  ChildObject? child;

  ManagedSet<RootJoinObject>? join;
}

class ChildObject extends ManagedObject<_ChildObject> implements _ChildObject {
  ChildObject();
  ChildObject.withCounter() {
    value1 = counter;
    value2 = counter;
    counter++;
  }
  static int counter = 1;

  @override
  bool operator ==(Object other) => other is ChildObject && cid == other.cid;

  @override
  int get hashCode => cid!;
}

class _ChildObject {
  @primaryKey
  int? cid;

  int? value1;
  int? value2;

  ManagedSet<GrandChildObject>? grandChildren;
  GrandChildObject? grandChild;

  @Relate(Symbol('children'))
  RootObject? parents;

  @Relate(Symbol('child'))
  RootObject? parent;
}

class GrandChildObject extends ManagedObject<_GrandChildObject>
    implements _GrandChildObject {
  GrandChildObject();
  GrandChildObject.withCounter() {
    value1 = counter;
    value2 = counter;
    counter++;
  }
  static int counter = 1;

  @override
  bool operator ==(Object other) =>
      other is GrandChildObject && gid == other.gid;

  @override
  int get hashCode => gid!;
}

class _GrandChildObject {
  @primaryKey
  int? gid;

  int? value1;
  int? value2;

  @Relate(Symbol('grandChildren'))
  ChildObject? parents;

  @Relate(Symbol('grandChild'))
  ChildObject? parent;
}

class OtherRootObject extends ManagedObject<_OtherRootObject>
    implements _OtherRootObject {
  OtherRootObject();
  OtherRootObject.withCounter() {
    value1 = counter;
    value2 = counter;
    counter++;
  }
  static int counter = 1;

  @override
  bool operator ==(Object other) => other is OtherRootObject && id == other.id;

  @override
  int get hashCode => id!;
}

class _OtherRootObject {
  @primaryKey
  int? id;

  int? value1;
  int? value2;

  ManagedSet<RootJoinObject>? join;
}

class RootJoinObject extends ManagedObject<_RootJoinObject>
    implements _RootJoinObject {
  @override
  bool operator ==(Object other) => other is RootJoinObject && id == other.id;

  @override
  int get hashCode => id!;
}

class _RootJoinObject {
  @primaryKey
  int? id;

  @Relate(Symbol('join'))
  OtherRootObject? other;

  @Relate(Symbol('join'))
  RootObject? root;
}

/*
[
  {"id": 1, "value1": 1, "value2": 1,
    "join": [{
        other: {"id": 1, "value1": 1, "value2": 1}
      }, {
        other: {"id": 2, "value1": 2, "value2": 2}
      }],
    child: {"id": 1, "value1": 1, "value2": 1,
      "grandChild": {"id": 1, "value1": 1, "value2": 1},
      "grandChildren": [
        {"id": 2, "value1": 2, "value2": 2}, {"id": 3, "value1": 3, "value2": 3}
      ]},
    "children": [
      {"id": 2, "value1": 2, "value2": 2,
        "grandChild": {"id": 4, "value1": 4, "value2": 4},
        "grandChildren": [
          {"id": 5, "value1": 5, "value2": 5}, {"id": 6, "value1": 6, "value2": 6}
      ]},
      {"id": 3, "value1": 3, "value2": 3,
        "grandChild": {"id": 7, "value1": 7, "value2": 7}
      },
      {"id": 4, "value1": 4, "value2": 4,
        "grandChildren": [{"id": 8, "value1": 8, "value2": 8}]},
      {"id": 5, "value1": 5, "value2": 5}
    ]},
  {"id": 2, "value1": 2, "value2": 2,
    "join": [{
      other: {"id": 3, "value1": 3, "value2": 3}
    }],
    child: {"id": 6, "value1": 6, "value2": 6},
    "children": [{"id": 7, "value1": 7, "value2": 7}]},
  {"id": 3, "value1": 3, "value2": 3,
    child: {"id": 8, "value1": 8, "value2": 8}},
  {"id": 4, "value1": 4, "value2": 4,
    "children": [{"id": 9, "value1": 9, "value2": 9}]},
  {"id": 5, "value1": 5, "value2": 5}
]
 */

Future<List<RootObject>> populateModelGraph(ManagedContext? ctx) async {
  final rootObjects = <RootObject>[
    RootObject.withCounter() // 1
      ..join = ManagedSet.from([
        RootJoinObject() // 1
          ..other = OtherRootObject.withCounter(), // 1
        RootJoinObject() // 2
          ..other = OtherRootObject.withCounter() // 2
      ])
      ..child = (ChildObject.withCounter() // 1
        ..grandChild = GrandChildObject.withCounter() // 1
        ..grandChildren = ManagedSet.from([
          GrandChildObject.withCounter(), // 2
          GrandChildObject.withCounter() // 3
        ]))
      ..children = ManagedSet.from([
        (ChildObject.withCounter() // 2
          ..grandChild = GrandChildObject.withCounter() // 4
          ..grandChildren = ManagedSet.from([
            GrandChildObject.withCounter(), // 5
            GrandChildObject.withCounter() // 6
          ])),
        (ChildObject.withCounter() // 3
          ..grandChild = GrandChildObject.withCounter() // 7
        ),
        (ChildObject.withCounter() // 4
          ..grandChildren = ManagedSet.from([
            GrandChildObject.withCounter() // 8
          ])),
        ChildObject.withCounter() // 5
      ]),
    RootObject.withCounter() // 2
      ..join = ManagedSet.from([
        RootJoinObject() // 3
          ..other = OtherRootObject.withCounter(), // 3
      ])
      ..child = ChildObject.withCounter() // 6
      ..children = ManagedSet.from([
        ChildObject.withCounter() // 7
      ]),
    RootObject.withCounter() // 3
      ..child = ChildObject.withCounter(), // 8
    RootObject.withCounter() // 4
      ..children = ManagedSet.from([
        ChildObject.withCounter() // 9
      ]),
    RootObject.withCounter() // 5
  ];

  for (final root in rootObjects) {
    final q = Query<RootObject>(ctx!)..values = root;
    final r = await q.insert();
    root.rid = r.rid;

    if (root.child != null) {
      final child = root.child!;
      child.parent = root;
      final cQ = Query<ChildObject>(ctx)..values = child;
      child.cid = (await cQ.insert()).cid;

      if (child.grandChild != null) {
        final gc = child.grandChild!;
        gc.parent = child;
        final gq = Query<GrandChildObject>(ctx)..values = gc;
        gc.gid = (await gq.insert()).gid;
      }

      if (child.grandChildren != null) {
        for (final gc in child.grandChildren!) {
          gc.parents = child;
          final gq = Query<GrandChildObject>(ctx)..values = gc;
          gc.gid = (await gq.insert()).gid;
        }
      }
    }

    if (root.children != null) {
      for (final child in root.children!) {
        child.parents = root;
        final cQ = Query<ChildObject>(ctx)..values = child;
        child.cid = (await cQ.insert()).cid;

        if (child.grandChild != null) {
          final gc = child.grandChild!;
          gc.parent = child;
          final gq = Query<GrandChildObject>(ctx)..values = gc;
          gc.gid = (await gq.insert()).gid;
        }

        if (child.grandChildren != null) {
          for (final gc in child.grandChildren!) {
            gc.parents = child;
            final gq = Query<GrandChildObject>(ctx)..values = gc;
            gc.gid = (await gq.insert()).gid;
          }
        }
      }
    }

    if (root.join != null) {
      for (final join in root.join!) {
        final otherQ = Query<OtherRootObject>(ctx)..values = join.other!;
        join.other!.id = (await otherQ.insert()).id;

        join.root = RootObject()..rid = root.rid;

        final joinQ = Query<RootJoinObject>(ctx)..values = join;
        await joinQ.insert();
      }
    }
  }

  return rootObjects;
}

Map fullObjectMap(Type t, dynamic v, {Map<String, dynamic>? and}) {
  var idName = "id";
  if (t == RootObject) {
    idName = "rid";
  } else if (t == ChildObject) {
    idName = "cid";
  } else if (t == GrandChildObject) {
    idName = "gid";
  }
  final m = {idName: v, "value1": v, "value2": v};
  if (and != null) {
    m.addAll(and);
  }
  return m;
}

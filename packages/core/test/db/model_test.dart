import 'dart:convert';

import '../not_tests/helpers.dart';
import 'package:conduit_core/conduit_core.dart';
import 'package:test/test.dart';

void main() {
  late ManagedContext context;

  setUpAll(() {
    final ps = DefaultPersistentStore();
    final ManagedDataModel dm = ManagedDataModel([
      TransientTest,
      TransientTypeTest,
      User,
      Post,
      PrivateField,
      EnumObject,
      TransientBelongsTo,
      TransientOwner,
      DocumentTest,
      ConstructorOverride,
      Top,
      Middle,
      Bottom,
      OverrideField
    ]);
    context = ManagedContext(dm, ps);
  });

  tearDownAll(() async {
    await context.close();
  });

  test("Can set properties in constructor", () {
    final obj = ConstructorOverride();
    expect(obj.value, "foo");
  });

  test("Model object construction", () {
    final user = User();
    user.name = "Joe";
    user.id = 1;

    expect(user.name, "Joe");
    expect(user.id, 1);
  });

  test("Mismatched type throws exception", () {
    final user = User();
    try {
      user["name"] = 1;

      expect(true, false);
    } on ValidationException catch (e) {
      expectError(e, contains("invalid input value for 'name'"));
    }

    try {
      user["id"] = "foo";
    } on ValidationException catch (e) {
      expectError(e, contains("invalid input value for 'id'"));
    }
  });

  test("Accessing model object without field should return null", () {
    final user = User();
    expect(user.name, isNull);
  });

  test("Can assign and read embedded objects", () {
    final user = User();
    user.id = 1;
    user.name = "Bob";
    final List<Post> posts = <Post>[
      Post()
        ..text = "A"
        ..id = 1
        ..owner = user,
      Post()
        ..text = "B"
        ..id = 2
        ..owner = user,
      Post()
        ..text = "C"
        ..id = 3
        ..owner = user,
    ];

    user.posts = ManagedSet<Post>.from(posts);

    expect(user.posts!.length, 3);
    expect(user.posts!.first.owner, user);
    expect(user.posts!.first.text, "A");

    expect(posts.first.owner, user);
    expect(posts.first.owner!.name, "Bob");
  });

  test("Can assign null to relationships", () {
    final u = User();
    u.posts = null;

    final p = Post();
    p.owner = null;
  });

  test("Can convert object to map", () {
    final user = User();
    user.id = 1;
    user.name = "Bob";
    final posts = [
      Post()
        ..text = "A"
        ..id = 1,
      Post()
        ..text = "B"
        ..id = 2,
      Post()
        ..text = "C"
        ..id = 3,
    ];
    user.posts = ManagedSet<Post>.from(posts);

    final m = user.asMap();
    expect(m["id"], 1);
    expect(m["name"], "Bob");
    final mPosts = m["posts"];
    expect(mPosts.length, 3);
    expect(mPosts.first["id"], 1);
    expect(mPosts.first["text"], "A");
    expect(mPosts.first["owner"], null);
  });

  test("Can read from map", () {
    final map = {"id": 1, "name": "Bob"};

    final postMap = [
      {"text": "hey", "id": 1},
      {"text": "ho", "id": 2}
    ];

    final user = User();
    user.readFromMap(washMap(map));

    expect(user.id, 1);
    expect(user.name, "Bob");

    final posts = postMap.map((e) => Post()..readFromMap(washMap(e))).toList();
    expect(posts[0].id, 1);
    expect(posts[1].id, 2);
    expect(posts[0].text, "hey");
    expect(posts[1].text, "ho");
  });

  test("Reading from map with bad key fails", () {
    final map = {"id": 1, "name": "Bob", "bad_key": "value"};

    final user = User();
    try {
      user.readFromMap(washMap(map));
      expect(true, false);
    } on ValidationException catch (e) {
      expectError(e, contains("invalid input key 'bad_key'"));
    }
  });

  test("Reading from map with non-assignable type fails", () {
    try {
      User().readFromMap(washMap({"id": "foo"}));
      expect(true, false);
    } on ValidationException catch (e) {
      expectError(e, contains("invalid input value for 'id'"));
    }
  });

  test("Handles DateTime conversion", () {
    const dateString = "2000-01-01T05:05:05.010Z";
    var map = {"id": 1, "name": "Bob", "dateCreated": dateString};
    var user = User();
    user.readFromMap(washMap(map));

    expect(
      user.dateCreated!.difference(DateTime.parse(dateString)),
      Duration.zero,
    );

    final remap = user.asMap();
    expect(remap["dateCreated"], dateString);

    map = {"id": 1, "name": "Bob", "dateCreated": 123};
    user = User();
    try {
      user.readFromMap(washMap(map));
      expect(true, false);
    } on ValidationException catch (e) {
      expectError(e, contains("invalid input value for 'dateCreated'"));
    }
  });

  test(
      "Handles input of type num for double precision float properties of the model",
      () {
    final m = TransientTypeTest()
      ..readFromMap(
        washMap({
          "transientDouble": 30,
        }),
      );

    expect(m.transientDouble, 30.0);
  });

  test("Reads embedded object", () {
    final postMap = {
      "text": "hey",
      "id": 1,
      "owner": {"name": "Alex", "id": 18}
    };

    final post = Post()..readFromMap(washMap(postMap));
    expect(post.text, "hey");
    expect(post.id, 1);
    expect(post.owner!.id, 18);
    expect(post.owner!.name, "Alex");
  });

  test("Trying to read embedded object that isnt an object fails", () {
    final postMap = {"text": "hey", "id": 1, "owner": 12};
    final post = Post();
    var successful = false;
    try {
      post.readFromMap(washMap(postMap));
      successful = true;
    } on ValidationException catch (e) {
      expectError(e, contains("invalid input type for 'owner'"));
    }
    expect(successful, false);
  });

  test("Setting embeded object to null doesn't throw exception", () {
    final post = Post()
      ..id = 4
      ..owner = (User()
        ..id = 3
        ..name = "Alex");
    post.owner = null;
    expect(post.owner, isNull);
  });

  test("Setting properties to null is OK", () {
    final u = User();
    u.name = "Bob";
    u.dateCreated = null;
    u.name =
        null; // I previously set this to a value on purpose and then reset it to null

    expect(u.name, isNull);
    expect(u.dateCreated, isNull);
  });

  test("Primary key works", () {
    final u = User();
    expect(u.entity.primaryKey, "id");

    final p = Post();
    expect(p.entity.primaryKey, "id");
  });

  test("Transient properties aren't stored in backing", () {
    final t = TransientTest();
    t.readFromMap(washMap({"inOut": 2}));
    expect(t.inOut, 2);
    expect(t["inOut"], isNull);
  });

  test("mappableInput properties are read in readMap", () {
    var t = TransientTest()
      ..readFromMap(washMap({"id": 1, "defaultedText": "bar foo"}));
    expect(t.id, 1);
    expect(t.text, "foo");
    expect(t.inputInt, isNull);
    expect(t.inOut, isNull);

    t = TransientTest()..readFromMap(washMap({"inputOnly": "foo"}));
    expect(t.text, "foo");

    t = TransientTest()..readFromMap(washMap({"inputInt": 2}));
    expect(t.inputInt, 2);

    t = TransientTest()..readFromMap(washMap({"inOut": 2}));
    expect(t.inOut, 2);

    t = TransientTest()..readFromMap(washMap({"bothOverQualified": "foo"}));
    expect(t.text, "foo");
  });

  test("mappableOutput properties are emitted in asMap", () {
    var t = TransientTest()..text = "foo";
    final map = t.asMap();

    expect(map["defaultedText"], "Mr. foo");
    expect(map["outputOnly"], "foo");
    expect(map["bothButOnlyOnOne"], "foo");
    expect(map["bothOverQualified"], "foo");

    t = TransientTest()..outputInt = 2;
    expect(t.asMap()["outputInt"], 2);

    t = TransientTest()..inOut = 2;
    expect(t.asMap()["inOut"], 2);
  });

  test("Transient properties are type checked in readMap", () {
    try {
      TransientTest().readFromMap(washMap({"id": 1, "defaultedText": 2}));

      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTest().readFromMap(washMap({"id": 1, "inputInt": "foo"}));

      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}
  });

  test("Properties that aren't mappableInput are not read in readMap", () {
    try {
      TransientTest().readFromMap(washMap({"outputOnly": "foo"}));
      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTest().readFromMap(washMap({"invalidOutput": "foo"}));
      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTest().readFromMap(washMap({"invalidInput": "foo"}));
      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTest().readFromMap(washMap({"bothButOnlyOnOne": "foo"}));
      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTest().readFromMap(washMap({"outputInt": "foo"}));
      throw 'Unreachable';
      // ignore: empty_catches
    } on ValidationException {}
  });

  test("mappableOutput properties that are null are not emitted in asMap", () {
    final m = (TransientTest()
          ..id = 1
          ..text = null)
        .asMap();

    expect(m.length, 3);
    expect(m["id"], 1);
    expect(m["text"], null);
    expect(m["defaultedText"], "Mr. null");
  });

  test("Properties that aren't mappableOutput are not emitted in asMap", () {
    final m = (TransientTest()
          ..id = 1
          ..text = "foo"
          ..inputInt = 2)
        .asMap();

    expect(m.length, 6);
    expect(m["id"], 1);
    expect(m["text"], "foo");
    expect(m["defaultedText"], "Mr. foo");
    expect(m["outputOnly"], "foo");
    expect(m["bothButOnlyOnOne"], "foo");
    expect(m["bothOverQualified"], "foo");
  });

  test("Can remove single property from backing map", () {
    final u = (User()
      ..id = 1
      ..name = "Bob"
      ..dateCreated = DateTime(2018, 1, 30))
      ..removePropertyFromBackingMap("name");

    final m = u.asMap();

    expect(m.containsKey("id"), true);
    expect(m.containsKey("name"), false);
    expect(m.containsKey("dateCreated"), true);
  });

  test("Removing single non-existent property from backing map has no effect",
      () {
    final u = (User()
      ..id = 1
      ..name = "Bob"
      ..dateCreated = DateTime(2018, 1, 30))
      ..removePropertyFromBackingMap("dummy");

    final m = u.asMap();

    expect(m.containsKey("id"), true);
    expect(m.containsKey("name"), true);
    expect(m.containsKey("dateCreated"), true);
  });

  test("Can remove multiple properties from backing map", () {
    final u = (User()
      ..id = 1
      ..name = "Bob"
      ..dateCreated = DateTime(2018, 1, 30))
      ..removePropertiesFromBackingMap(["name", "dateCreated"]);

    final m = u.asMap();

    expect(m.containsKey("id"), true);
    expect(m.containsKey("name"), false);
    expect(m.containsKey("dateCreated"), false);
  });

  test("Can remove single property from backing map with multi-property method",
      () {
    final u = (User()
      ..id = 1
      ..name = "Bob"
      ..dateCreated = DateTime(2018, 1, 30))
      ..removePropertiesFromBackingMap(["name"]);

    final m = u.asMap();

    expect(m.containsKey("id"), true);
    expect(m.containsKey("name"), false);
    expect(m.containsKey("dateCreated"), true);
  });

  test(
      "Removing multiple non-existent properties from backing map has no effect",
      () {
    final u = (User()
      ..id = 1
      ..name = "Bob"
      ..dateCreated = DateTime(2018, 1, 30))
      ..removePropertiesFromBackingMap(["dummy1", "dummy2"]);

    final m = u.asMap();

    expect(m.containsKey("id"), true);
    expect(m.containsKey("name"), true);
    expect(m.containsKey("dateCreated"), true);
  });

  test(
    "DeepMap Transient Properties of all types can be read and returned",
    () {
      final m = (TransientTypeTest()
            ..readFromMap(
              washMap({
                "deepMap": {
                  "ok": {"ik1": 1, "ik2": 2}
                }
              }),
            ))
          .asMap();

      expect(m["deepMap"], {
        "ok": {"ik1": 1, "ik2": 2}
      });
    },
    skip: "NYI in AOT",
  );

  test("Transient Properties of all types can be read and returned", () {
    const dateString = "2016-10-31T15:40:45+00:00";
    final m = (TransientTypeTest()
          ..readFromMap(
            washMap({
              "transientInt": 5,
              "transientBigInt": 123456789,
              "transientString": "lowercase string",
              "transientDate": dateString,
              "transientBool": true,
              "transientDouble": 30.5,
              "transientMap": {"key": "value", "anotherKey": "anotherValue"},
              "transientList": [1, 2, 3, 4, 5],
              "defaultList": [1, "foo"],
              "defaultMap": {"key": "value"},
              "deepList": [
                {"str": "val"},
                {"other": "otherval"}
              ]
            }),
          ))
        .asMap();

    expect(m["transientInt"], 5);
    expect(m["transientBigInt"], 123456789);
    expect(m["transientString"], "lowercase string");
    expect(
      m["transientDate"].difference(DateTime.parse(dateString)),
      Duration.zero,
    );
    expect(m["transientBool"], true);
    expect(m["transientDouble"], 30.5);
    expect(m["transientList"], [1, 2, 3, 4, 5]);
    expect(m["defaultMap"], {"key": "value"});
    expect(m["defaultList"], [1, "foo"]);
    expect(m["deepList"], [
      {"str": "val"},
      {"other": "otherval"}
    ]);

    final tm = m["transientMap"];
    expect(tm is Map, true);
    expect(tm["key"], "value");
    expect(tm["anotherKey"], "anotherValue");
  });

  test(
      "If primitive type cannot be parsed into correct type, it fails with validation exception",
      () {
    try {
      TransientTypeTest().readFromMap({"transientInt": "a string"});
      fail('unreachable');
      // ignore: empty_catches
    } on ValidationException {}
  });

  test(
      "If map type cannot be parsed into exact type, it fails with validation exception",
      () {
    try {
      TransientTypeTest().readFromMap({
        "deepMap": wash({"str": 1})
      });
      fail('unreachable');
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTypeTest().readFromMap({
        "deepMap": wash({
          "key": {"str": "val", "int": 2}
        })
      });
      fail('unreachable');
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTypeTest().readFromMap({"deepMap": wash("str")});
      fail('unreachable');
      // ignore: empty_catches
    } on ValidationException {}
  });

  test(
      "If complex type cannot be parsed into exact type, it fails with validation exception",
      () {
    try {
      TransientTypeTest().readFromMap({
        "deepList": wash(["string"])
      });
      fail('unreachable');
      // ignore: empty_catches
    } on ValidationException {}

    try {
      TransientTypeTest().readFromMap({
        "deepList": wash([
          {"str": "val"},
          "string"
        ])
      });
      fail('unreachable');
      // ignore: empty_catches
    } on ValidationException {}
  });

  test("Reading hasMany relationship from JSON succeeds", () {
    final u = User();
    u.readFromMap(
      washMap({
        "name": "Bob",
        "id": 1,
        "posts": [
          {"text": "Hi", "id": 1}
        ]
      }),
    );
    expect(u.posts!.length, 1);
    expect(u.posts![0].id, 1);
    expect(u.posts![0].text, "Hi");
  });

  test(
      "Reading/writing instance property that isn't marked as transient shows up nowhere",
      () {
    final t = TransientTest();
    try {
      t.readFromMap(washMap({"notAnAttribute": true}));
      expect(true, false);
      // ignore: empty_catches
    } on ValidationException {}

    t.notAnAttribute = "foo";
    expect(t.asMap().containsKey("notAnAttribute"), false);
  });

  test(
      "Omit transient properties in asMap when object is a foreign key reference",
      () {
    final b = TransientBelongsTo()
      ..id = 1
      ..owner = (TransientOwner()..id = 1);
    expect(b.asMap(), {
      "id": 1,
      "owner": {"id": 1}
    });
  });

  test("readFromMap correctly invoked for relationships of relationships", () {
    final t = Top()
      ..readFromMap(
        washMap({
          "id": 1,
          "middles": [
            {
              "id": 2,
              "bottom": {"id": 3},
              "bottoms": [
                {"id": 4},
                {"id": 5}
              ]
            }
          ]
        }),
      );

    expect(t.id, 1);
    expect(t.middles.first.id, 2);
    expect(t.middles.first.bottom.id, 3);
    expect(t.middles.first.bottoms.first.id, 4);
    expect(t.middles.first.bottoms.last.id, 5);
  });

  group("Persistent enum fields", () {
    test("Can assign/read enum value to persistent property", () {
      final e = EnumObject();
      e.enumValues = EnumValues.abcd;
      expect(e.enumValues, EnumValues.abcd);
    });

    test("Enum value in readMap is a matching string", () {
      final e = EnumObject()..readFromMap(washMap({"enumValues": "efgh"}));
      expect(e.enumValues, EnumValues.efgh);
    });

    test("Enum value in asMap is a matching string", () {
      final e = EnumObject()..enumValues = EnumValues.other18;
      expect(e.asMap()["enumValues"], "other18");
    });

    test(
        "Cannot assign value via backingMap or readMap that isn't a valid enum case",
        () {
      final e = EnumObject();
      try {
        e.readFromMap(washMap({"enumValues": "foobar"}));
        expect(true, false);
      } on ValidationException catch (e) {
        expectError(e, contains("invalid option for key 'enumValues'"));
      }

      try {
        e["enumValues"] = "foobar";
        expect(true, false);
      } on ValidationException catch (e) {
        expectError(e, contains("invalid input value for 'enumValues'"));
      }
    });
  });

  group("Private fields", () {
    test("Private fields on entity", () {
      final entity = context.dataModel!.entityForType(PrivateField);
      expect(entity.attributes["_private"], isNotNull);
    });

    test("Can get/set value of private field", () {
      final p = PrivateField();
      p._private = "x";
      expect(p._private, "x");
    });

    test("Can get/set value of private field thru public accessor", () {
      final p = PrivateField()..public = "x";
      expect(p.public, "x");
      expect(p._private, "x");
    });

    test("Private fields are omitted from asMap()", () {
      var p = PrivateField()..public = "x";
      expect(p.asMap(), {"public": "x"});

      p = PrivateField().._private = "x";
      expect(p.asMap(), {"public": "x"});
    });

    test("Private fields cannot be set in readFromMap()", () {
      final p = PrivateField();
      try {
        p.readFromMap(washMap({"_private": "x"}));
        fail('unreachable');
      } on ValidationException catch (e) {
        expect(e.toString(), contains("invalid input"));
      }
      expect(p.public, isNull);
      expect(p._private, isNull);
    });
  });

  group("Document data type", () {
    test("Can read object into document data type from map", () {
      final o = DocumentTest();
      o.readFromMap(
        washMap({
          "document": {"key": "value"}
        }),
      );

      expect(o.document.data, {"key": "value"});
    });

    test("Can read array into document data type from list", () {
      final o = DocumentTest();
      o.readFromMap(
        washMap({
          "document": [
            {"key": "value"},
            1
          ]
        }),
      );

      expect(o.document.data, [
        {"key": "value"},
        1
      ]);
    });

    test("Can emit object into map from object document data type", () {
      final o = DocumentTest()..document = Document({"key": "value"});
      expect(o.asMap(), {
        "document": {"key": "value"}
      });
    });

    test("Can emit array into map from array document data type", () {
      final o = DocumentTest()
        ..document = Document([
          {"key": "value"},
          1
        ]);
      expect(o.asMap(), {
        "document": [
          {"key": "value"},
          1
        ]
      });
    });
  });

  test("Can have constructor with only optional args", () {
    final dm = ManagedDataModel([DefaultConstructorHasOptionalArgs]);
    final _ = ManagedContext(dm, DefaultPersistentStore());
    final instance =
        dm.entityForType(DefaultConstructorHasOptionalArgs).instanceOf();
    expect(instance is DefaultConstructorHasOptionalArgs, true);
  });
}

class User extends ManagedObject<_User> implements _User {
  @Serialize()
  String? value;
}

class _User {
  @Column(nullable: true)
  String? name;

  @Column(primaryKey: true)
  int? id;

  DateTime? dateCreated;

  ManagedSet<Post>? posts;
}

class Post extends ManagedObject<_Post> implements _Post {}

class _Post {
  @primaryKey
  int? id;

  String? text;

  @Relate(Symbol('posts'))
  User? owner;
}

class TransientTest extends ManagedObject<_TransientTest>
    implements _TransientTest {
  String? notAnAttribute;

  @Serialize(input: false, output: true)
  String get defaultedText => "Mr. $text";

  @Serialize(input: true, output: false)
  set defaultedText(String str) {
    text = str.split(" ").last;
  }

  @Serialize(input: true, output: false)
  set inputOnly(String s) {
    text = s;
  }

  @Serialize(input: false, output: true)
  String? get outputOnly => text;

  set outputOnly(String? s) {
    text = s;
  }

  // This is intentionally invalid
  @Serialize(input: true, output: false)
  String? get invalidInput => text;

  // This is intentionally invalid
  @Serialize(input: false, output: true)
  set invalidOutput(String s) {
    text = s;
  }

  @Serialize()
  String? get bothButOnlyOnOne => text;

  set bothButOnlyOnOne(String? s) {
    text = s;
  }

  @Serialize(input: true, output: false)
  int? inputInt;

  @Serialize(input: false, output: true)
  int? outputInt;

  @Serialize()
  int? inOut;

  @Serialize()
  String? get bothOverQualified => text;

  @Serialize()
  set bothOverQualified(String? s) {
    text = s;
  }
}

class _TransientTest {
  @primaryKey
  int? id;

  String? text;
}

class TransientTypeTest extends ManagedObject<_TransientTypeTest>
    implements _TransientTypeTest {
  @Serialize(input: false, output: true)
  int get transientInt => backingInt + 1;

  @Serialize(input: true, output: false)
  set transientInt(int i) {
    backingInt = i - 1;
  }

  @Serialize(input: false, output: true)
  int get transientBigInt => backingBigInt ~/ 2;

  @Serialize(input: true, output: false)
  set transientBigInt(int i) {
    backingBigInt = i * 2;
  }

  @Serialize(input: false, output: true)
  String get transientString => backingString.toLowerCase();

  @Serialize(input: true, output: false)
  set transientString(String s) {
    backingString = s.toUpperCase();
  }

  @Serialize(input: false, output: true)
  DateTime get transientDate => backingDateTime.add(const Duration(days: 1));

  @Serialize(input: true, output: false)
  set transientDate(DateTime d) {
    backingDateTime = d.subtract(const Duration(days: 1));
  }

  @Serialize(input: false, output: true)
  bool get transientBool => !backingBool;

  @Serialize(input: true, output: false)
  set transientBool(bool b) {
    backingBool = !b;
  }

  @Serialize(input: false, output: true)
  double get transientDouble => backingDouble / 5;

  @Serialize(input: true, output: false)
  set transientDouble(double d) {
    backingDouble = d * 5;
  }

  @Serialize(input: false, output: true)
  Map<String, String> get transientMap {
    final List<String> pairs = backingMapString.split(",");

    final returnMap = <String, String>{};

    for (final pair in pairs) {
      final List<String> pairList = pair.split(":");
      returnMap[pairList[0]] = pairList[1];
    }

    return returnMap;
  }

  @Serialize(input: true, output: false)
  set transientMap(Map<String, String> m) {
    final pairStrings = m.keys.map((key) {
      final String? value = m[key];
      return "$key:$value";
    });

    backingMapString = pairStrings.join(",");
  }

  @Serialize(input: false, output: true)
  List<int> get transientList {
    return backingListString.split(",").map(int.parse).toList();
  }

  @Serialize(input: true, output: false)
  set transientList(List<int> l) {
    backingListString = l.map((i) => i.toString()).join(",");
  }

  @Serialize()
  List<Map<String, dynamic>>? deepList;

  @Serialize()
  Map<String, Map<String, int>>? deepMap;

  @Serialize()
  Map<String, dynamic>? defaultMap;

  @Serialize()
  List<dynamic>? defaultList;
}

class _TransientTypeTest {
  // All of the types - ManagedPropertyType
  @primaryKey
  int? id;

  late int backingInt;

  @Column(databaseType: ManagedPropertyType.bigInteger)
  late int backingBigInt;

  late String backingString;

  late DateTime backingDateTime;

  late bool backingBool;

  late double backingDouble;

  late String backingMapString;

  late String backingListString;
}

class PrivateField extends ManagedObject<_PrivateField>
    implements _PrivateField {
  @Serialize(input: true, output: false)
  set public(String? p) {
    _private = p;
  }

  @Serialize(input: false, output: true)
  String? get public => _private;
}

class _PrivateField {
  @primaryKey
  int? id;

  String? _private;
}

class EnumObject extends ManagedObject<_EnumObject> implements _EnumObject {}

class _EnumObject {
  @primaryKey
  int? id;

  EnumValues? enumValues;
}

enum EnumValues { abcd, efgh, other18 }

class TransientOwner extends ManagedObject<_TransientOwner>
    implements _TransientOwner {
  @Serialize(input: false, output: true)
  int v = 2;
}

class _TransientOwner {
  @primaryKey
  int? id;

  TransientBelongsTo? t;
}

class TransientBelongsTo extends ManagedObject<_TransientBelongsTo>
    implements _TransientBelongsTo {}

class _TransientBelongsTo {
  @primaryKey
  int? id;

  @Relate(Symbol('t'))
  TransientOwner? owner;
}

void expectError(ValidationException exception, Matcher matcher) {
  expect(exception.toString(), matcher);
}

class DocumentTest extends ManagedObject<_DocumentTest>
    implements _DocumentTest {}

class _DocumentTest {
  @primaryKey
  int? id;

  late Document document;
}

class ConstructorOverride extends ManagedObject<_ConstructorOverride>
    implements _ConstructorOverride {
  ConstructorOverride() {
    value = "foo";
  }
}

class _ConstructorOverride {
  @primaryKey
  int? id;

  String? value;
}

class DefaultConstructorHasOptionalArgs
    extends ManagedObject<_ConstructorTableDef> {
  DefaultConstructorHasOptionalArgs({int? foo});
}

class _ConstructorTableDef {
  @primaryKey
  int? id;
}

class Top extends ManagedObject<_Top> implements _Top {}

class _Top {
  @Column(primaryKey: true)
  int? id;

  late ManagedSet<Middle> middles;
}

class Middle extends ManagedObject<_Middle> implements _Middle {}

class _Middle {
  @Column(primaryKey: true)
  int? id;

  @Relate(#middles)
  Top? top;

  late Bottom bottom;
  late ManagedSet<Bottom> bottoms;
}

class Bottom extends ManagedObject<_Bottom> implements _Bottom {}

class _Bottom {
  @Column(primaryKey: true)
  int? id;

  @Relate(#bottom)
  Middle? middle;

  @Relate(#bottoms)
  Middle? middles;
}

class OverrideField extends ManagedObject<_OverrideField>
    implements _OverrideField {
  @override
  String? field;
}

class _OverrideField {
  @primaryKey
  int? id;

  String? field;
}

T? wash<T>(dynamic data) {
  return json.decode(json.encode(data)) as T?;
}

Map<String, dynamic> washMap(dynamic data) {
  return json.decode(json.encode(data)) as Map<String, dynamic>;
}

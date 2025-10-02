import 'dart:async';

import 'package:conduit_core/conduit_core.dart';
import 'package:conduit_core/managed_auth.dart';
import 'package:test/test.dart';

import '../not_tests/postgres_test_config.dart';

// These tests are similar to managed_auth_storage_test, but handle the cases where authenticatables
// have scope rules.
void main() {
  RoleBasedAuthStorage storage;
  late ManagedContext context;
  late AuthServer auth;
  late List<User> createdUsers;

  setUpAll(() async {
    context = await PostgresTestConfig()
        .contextWithModels([User, ManagedAuthClient, ManagedAuthToken]);
    storage = RoleBasedAuthStorage(context);
    auth = AuthServer(storage);
    createdUsers = await createUsers(context, 5);

    const salt = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345";

    final clients = [
      AuthClient.withRedirectURI(
        "redirect",
        generatePasswordHash("a", salt),
        salt,
        "http://a.com",
        allowedScopes: [AuthScope("user"), AuthScope("location:add")],
      ),
    ];

    await Future.wait(
      clients
          .map(
        (ac) => ManagedAuthClient()
          ..id = ac.id
          ..salt = ac.salt
          ..allowedScope = ac.allowedScopes!.map((a) => a.toString()).join(" ")
          ..hashedSecret = ac.hashedSecret
          ..redirectURI = ac.redirectURI,
      )
          .map((mc) {
        final q = Query<ManagedAuthClient>(context)..values = mc;
        return q.insert();
      }),
    );
  });

  tearDownAll(() async {
    await context.close();
  });

  group("Resource owner", () {
    test("AuthScope.Any allows all client scopes", () async {
      final t = await auth.authenticate(
        createdUsers.firstWhere((u) => u.role == "admin").username,
        User.defaultPassword,
        "redirect",
        "a",
        requestedScopes: [AuthScope("user"), AuthScope("location:add")],
      );

      expect(t.scopes!.length, 2);
      expect(t.scopes!.any((s) => s.isExactly("user")), true);
      expect(t.scopes!.any((s) => s.isExactly("location:add")), true);
    });

    test("Restricted role scopes prevents allowed client scopes", () async {
      final t = await auth.authenticate(
        createdUsers.firstWhere((u) => u.role == "user").username,
        User.defaultPassword,
        "redirect",
        "a",
        requestedScopes: [AuthScope("user"), AuthScope("location:add")],
      );

      expect(t.scopes!.length, 1);
      expect(t.scopes!.any((s) => s.isExactly("user")), true);
    });

    test(
        "Role that allows scope but not requested, netting no scope, prevents access token from being granted",
        () async {
      try {
        await auth.authenticate(
          createdUsers.firstWhere((u) => u.role == "user").username,
          User.defaultPassword,
          "redirect",
          "a",
          requestedScopes: [AuthScope("location:add")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });

    test("Role that allows no scope prevents access token from being granted",
        () async {
      try {
        await auth.authenticate(
          createdUsers.firstWhere((u) => u.role == null).username,
          User.defaultPassword,
          "redirect",
          "a",
          requestedScopes: [AuthScope("location:add")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });

    test(
        "Client allows full scope, role restricts it to a subset, can only grant subset",
        () async {
      final t = await auth.authenticate(
        createdUsers.firstWhere((u) => u.role == "viewer").username,
        User.defaultPassword,
        "redirect",
        "a",
        requestedScopes: [
          AuthScope("user.readonly"),
          AuthScope("location:add:xyz")
        ],
      );

      expect(t.scopes!.length, 2);
      expect(t.scopes!.any((s) => s.isExactly("user.readonly")), true);
      expect(t.scopes!.any((s) => s.isExactly("location:add:xyz")), true);
    });

    test("User allowed scopes can't grant higher privileges than client",
        () async {
      try {
        await auth.authenticate(
          createdUsers.firstWhere((u) => u.role == "invalid").username,
          User.defaultPassword,
          "redirect",
          "a",
          requestedScopes: [AuthScope("location")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });
  });

  group("Refresh", () {
    test("Can't upgrade scope if it allowed by client, but restricted by role",
        () async {
      final t = await auth.authenticate(
        createdUsers.firstWhere((u) => u.role == "viewer").username,
        User.defaultPassword,
        "redirect",
        "a",
        requestedScopes: [AuthScope("user.readonly")],
      );

      try {
        await auth.refresh(
          t.refreshToken,
          "redirect",
          "a",
          requestedScopes: [AuthScope("user")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });

    test("Can't upgrade scope even if client/user allow it", () async {
      final t = await auth.authenticate(
        createdUsers.firstWhere((u) => u.role == "viewer").username,
        User.defaultPassword,
        "redirect",
        "a",
        requestedScopes: [AuthScope("user.readonly")],
      );

      try {
        await auth.refresh(
          t.refreshToken,
          "redirect",
          "a",
          requestedScopes: [
            AuthScope("user.readonly"),
            AuthScope("location:add:xyz")
          ],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });

    test("Not specifying scope returns same scope", () async {
      var t = await auth.authenticate(
        createdUsers.firstWhere((u) => u.role == "viewer").username,
        User.defaultPassword,
        "redirect",
        "a",
        requestedScopes: [
          AuthScope("user.readonly"),
          AuthScope("location:add:xyz")
        ],
      );

      t = await auth.refresh(t.refreshToken, t.clientID, "a");
      expect(t.scopes!.length, 2);
      expect(t.scopes!.any((s) => s.isExactly("user.readonly")), true);
      expect(t.scopes!.any((s) => s.isExactly("location:add:xyz")), true);
    });
  });

  group("Auth code", () {
    test("AuthScope.Any allows all client scopes", () async {
      final code = await auth.authenticateForCode(
        createdUsers.firstWhere((u) => u.role == "admin").username,
        User.defaultPassword,
        "redirect",
        requestedScopes: [AuthScope("user"), AuthScope("location:add")],
      );
      final t = await auth.exchange(code.code, "redirect", "a");

      expect(t.scopes!.length, 2);
      expect(t.scopes!.any((s) => s.isExactly("user")), true);
      expect(t.scopes!.any((s) => s.isExactly("location:add")), true);
    });

    test("Restricted role scopes prevents allowed client scopes", () async {
      final code = await auth.authenticateForCode(
        createdUsers.firstWhere((u) => u.role == "user").username,
        User.defaultPassword,
        "redirect",
        requestedScopes: [AuthScope("user"), AuthScope("location:add")],
      );
      final t = await auth.exchange(code.code, "redirect", "a");

      expect(t.scopes!.length, 1);
      expect(t.scopes!.any((s) => s.isExactly("user")), true);
    });

    test(
        "Role that allows scope but not requested, netting no scope, prevents access token from being granted",
        () async {
      try {
        await auth.authenticateForCode(
          createdUsers.firstWhere((u) => u.role == "user").username,
          User.defaultPassword,
          "redirect",
          requestedScopes: [AuthScope("location:add")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });

    test("Role that allows no scope prevents access token from being granted",
        () async {
      try {
        await auth.authenticateForCode(
          createdUsers.firstWhere((u) => u.role == null).username,
          User.defaultPassword,
          "redirect",
          requestedScopes: [AuthScope("location:add")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });

    test(
        "Client allows full scope, role restricts it to a subset, can only grant subset",
        () async {
      final code = await auth.authenticateForCode(
        createdUsers.firstWhere((u) => u.role == "viewer").username,
        User.defaultPassword,
        "redirect",
        requestedScopes: [
          AuthScope("user.readonly"),
          AuthScope("location:add:xyz")
        ],
      );
      final t = await auth.exchange(code.code, "redirect", "a");

      expect(t.scopes!.length, 2);
      expect(t.scopes!.any((s) => s.isExactly("user.readonly")), true);
      expect(t.scopes!.any((s) => s.isExactly("location:add:xyz")), true);
    });

    test("User allowed scopes can't grant higher privileges than client",
        () async {
      try {
        await auth.authenticateForCode(
          createdUsers.firstWhere((u) => u.role == "invalid").username,
          User.defaultPassword,
          "redirect",
          requestedScopes: [AuthScope("location")],
        );
        expect(true, false);
      } on AuthServerException catch (e) {
        expect(e.reason, AuthRequestError.invalidScope);
      }
    });
  });
}

class User extends ManagedObject<_User>
    implements _User, ManagedAuthResourceOwner<_User> {
  static const String defaultPassword = "foobaraxegrind!%12";
}

class _User extends ResourceOwnerTableDefinition {
  @Column(nullable: true)
  String? role;
}

Future<List<User>> createUsers(ManagedContext? ctx, int count) async {
  final list = <User>[];
  for (int i = 0; i < count; i++) {
    final salt = generateRandomSalt();
    final u = User()
      ..username = "bob+$i@stablekernel.com"
      ..salt = salt
      ..hashedPassword = generatePasswordHash(User.defaultPassword, salt);

    if (u.username!.startsWith("bob+0")) {
      u.role = "admin";
    } else if (u.username!.startsWith("bob+1")) {
      u.role = "user";
    } else if (u.username!.startsWith("bob+2")) {
      u.role = "viewer";
    } else if (u.username!.startsWith("bob+3")) {
      u.role = null;
    } else if (u.username!.startsWith("bob+4")) {
      u.role = "invalid";
    }

    final q = Query<User>(ctx!)..values = u;

    list.add(await q.insert());
  }
  return list;
}

class RoleBasedAuthStorage extends ManagedAuthDelegate<User> {
  RoleBasedAuthStorage(super.context, {super.tokenLimit});

  @override
  Future<User?> getResourceOwner(AuthServer server, String username) {
    final query = Query<User>(context)
      ..where((o) => o.username).equalTo(username)
      ..returningProperties(
        (t) => [t.id, t.hashedPassword, t.salt, t.username, t.role],
      );

    return query.fetchOne();
  }

  @override
  List<AuthScope> getAllowedScopes(covariant User user) {
    if (user.role == "admin") {
      return AuthScope.any;
    } else if (user.role == "user") {
      return [AuthScope("user")];
    } else if (user.role == "viewer") {
      return [AuthScope("user.readonly"), AuthScope("location:add:xyz")];
    } else if (user.role == "invalid") {
      return [AuthScope("location")];
    }

    return [];
  }
}

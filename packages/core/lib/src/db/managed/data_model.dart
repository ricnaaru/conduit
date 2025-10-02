import 'package:collection/collection.dart' show IterableExtension;
import 'package:conduit_common/conduit_common.dart';
import 'package:conduit_core/src/db/managed/managed.dart';
import 'package:conduit_core/src/db/query/query.dart';
import 'package:conduit_runtime/runtime.dart';

/// Instances of this class contain descriptions and metadata for mapping [ManagedObject]s to database rows.
///
/// An instance of this type must be used to initialize a [ManagedContext], and so are required to use [Query]s.
///
/// The [ManagedDataModel.fromCurrentMirrorSystem] constructor will reflect on an application's code and find
/// all subclasses of [ManagedObject], building a [ManagedEntity] for each.
///
/// Most applications do not need to access instances of this type.
///
class ManagedDataModel extends Object implements APIComponentDocumenter {
  /// Creates an instance of [ManagedDataModel] from a list of types that extend [ManagedObject]. It is preferable
  /// to use [ManagedDataModel.fromCurrentMirrorSystem] over this method.
  ///
  /// To register a class as a managed object within this data model, you must include its type in the list. Example:
  ///
  ///       new DataModel([User, Token, Post]);
  ManagedDataModel(List<Type> instanceTypes) {
    final runtimes = RuntimeContext.current.runtimes.iterable
        .whereType<ManagedEntityRuntime>()
        .toList();
    final expectedRuntimes = instanceTypes
        .map(
          (t) => runtimes.firstWhereOrNull((e) => e.entity.instanceType == t),
        )
        .toList();

    if (expectedRuntimes.any((e) => e == null)) {
      throw ManagedDataModelError(
        "Data model types were not found!",
      );
    }

    for (final runtime in expectedRuntimes) {
      _entities[runtime!.entity.instanceType] = runtime.entity;
      _tableDefinitionToEntityMap[runtime.entity.tableDefinition] =
          runtime.entity;
    }
    for (final runtime in expectedRuntimes) {
      runtime!.finalize(this);
    }
  }

  /// Creates an instance of a [ManagedDataModel] from all subclasses of [ManagedObject] in all libraries visible to the calling library.
  ///
  /// This constructor will search every available package and file library that is visible to the library
  /// that runs this constructor for subclasses of [ManagedObject]. A [ManagedEntity] will be created
  /// and stored in this instance for every such class found.
  ///
  /// Standard Dart libraries (prefixed with 'dart:') and URL-encoded libraries (prefixed with 'data:') are not searched.
  ///
  /// This is the preferred method of instantiating this type.
  ManagedDataModel.fromCurrentMirrorSystem() {
    final runtimes = RuntimeContext.current.runtimes.iterable
        .whereType<ManagedEntityRuntime>();

    for (final runtime in runtimes) {
      _entities[runtime.entity.instanceType] = runtime.entity;
      _tableDefinitionToEntityMap[runtime.entity.tableDefinition] =
          runtime.entity;
    }
    for (final runtime in runtimes) {
      runtime.finalize(this);
    }
  }

  Iterable<ManagedEntity> get entities => _entities.values;
  final Map<Type, ManagedEntity> _entities = {};
  final Map<String, ManagedEntity> _tableDefinitionToEntityMap = {};

  /// Returns a [ManagedEntity] for a [Type].
  ///
  /// [type] may be either a subclass of [ManagedObject] or a [ManagedObject]'s table definition. For example, the following
  /// definition, you could retrieve its entity by passing MyModel or _MyModel as an argument to this method:
  ///
  ///         class MyModel extends ManagedObject<_MyModel> implements _MyModel {}
  ///         class _MyModel {
  ///           @primaryKey
  ///           int id;
  ///         }
  /// If the [type] has no known [ManagedEntity] then a [StateError] is thrown.
  /// Use [tryEntityForType] to test if an entity exists.
  ManagedEntity entityForType(Type type) {
    final entity = tryEntityForType(type);

    if (entity == null) {
      throw StateError(
        "No entity found for '$type. Did you forget to create a 'ManagedContext'?",
      );
    }

    return entity;
  }

  ManagedEntity? tryEntityForType(Type type) =>
      _entities[type] ?? _tableDefinitionToEntityMap[type.toString()];

  @override
  void documentComponents(APIDocumentContext context) {
    for (final e in entities) {
      e.documentComponents(context);
    }
  }
}

/// Thrown when a [ManagedDataModel] encounters an error.
class ManagedDataModelError extends Error {
  ManagedDataModelError(this.message);

  final String message;

  @override
  String toString() {
    return "Data Model Error: $message";
  }
}

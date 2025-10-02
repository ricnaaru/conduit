import 'package:conduit_common/conduit_common.dart';
import 'package:conduit_core/src/db/managed/backing.dart';
import 'package:conduit_core/src/db/managed/data_model_manager.dart' as mm;
import 'package:conduit_core/src/db/managed/managed.dart';
import 'package:conduit_core/src/db/query/query.dart';
import 'package:conduit_core/src/http/serializable.dart';
import 'package:conduit_open_api/v3.dart';
import 'package:meta/meta.dart';

/// Instances of this class provide storage for [ManagedObject]s.
///
/// This class is primarily used internally.
///
/// A [ManagedObject] stores properties declared by its type argument in instances of this type.
/// Values are validated against the [ManagedObject.entity].
///
/// Instances of this type only store properties for which a value has been explicitly set. This allows
/// serialization classes to omit unset values from the serialized values. Therefore, instances of this class
/// provide behavior that can differentiate between a property being the null value and a property simply not being
/// set. (Therefore, you must use [removeProperty] instead of setting a value to null to really remove it from instances
/// of this type.)
///
/// Conduit implements concrete subclasses of this class to provide behavior for property storage
/// and query-building.
abstract class ManagedBacking {
  /// Retrieve a property by its entity and name.
  dynamic valueForProperty(ManagedPropertyDescription property);

  /// Sets a property by its entity and name.
  void setValueForProperty(ManagedPropertyDescription property, dynamic value);

  /// Removes a property from this instance.
  ///
  /// Use this method to use any reference of a property from this instance.
  void removeProperty(String propertyName) {
    contents.remove(propertyName);
  }

  /// A map of all set values of this instance.
  Map<String, dynamic> get contents;
}

/// An object that represents a database row.
///
/// This class must be subclassed. A subclass is declared for each table in a database. These subclasses
/// create the data model of an application.
///
/// A managed object is declared in two parts, the subclass and its table definition.
///
///         class User extends ManagedObject<_User> implements _User {
///           String name;
///         }
///         class _User {
///           @primaryKey
///           int id;
///
///           @Column(indexed: true)
///           String email;
///         }
///
/// Table definitions are plain Dart objects that represent a database table. Each property is a column in the database.
///
/// A subclass of this type must implement its table definition and use it as the type argument of [ManagedObject]. Properties and methods
/// declared in the subclass (also called the 'instance type') are not stored in the database.
///
/// See more documentation on defining a data model at http://www.theconduit.dev/docs/db/modeling_data/
abstract class ManagedObject<T> extends Serializable {
  /// IMPROVEMENT: Cache of entity.properties to reduce property loading time
  late Map<String, ManagedPropertyDescription?> properties = entity.properties;

  /// Cache of entity.properties using ResponseKey name as key, in case no ResponseKey is set then default property name is used as key
  late Map<String, ManagedPropertyDescription?> responseKeyProperties = {
    for (final key in properties.keys) mapKeyName(key): properties[key]
  };

  late final bool modelFieldIncludeIfNull = properties.isEmpty ||
      (properties.values.first?.responseModel?.includeIfNullField ?? true);

  String mapKeyName(String propertyName) {
    final property = properties[propertyName];
    return property?.responseKey?.name ?? property?.name ?? propertyName;
  }

  static bool get shouldAutomaticallyDocument => false;

  /// The [ManagedEntity] this instance is described by.
  ManagedEntity entity = mm.findEntity(T);

  /// The persistent values of this object.
  ///
  /// Values stored by this object are stored in [backing]. A backing is a [Map], where each key
  /// is a property name of this object. A backing adds some access logic to storing and retrieving
  /// its key-value pairs.
  ///
  /// You rarely need to use [backing] directly. There are many implementations of [ManagedBacking]
  /// for fulfilling the behavior of the ORM, so you cannot rely on its behavior.
  ManagedBacking backing = ManagedValueBacking();

  /// Retrieves a value by property name from [backing].
  dynamic operator [](String propertyName) {
    final prop = properties[propertyName];
    if (prop == null) {
      throw ArgumentError("Invalid property access for '${entity.name}'. "
          "Property '$propertyName' does not exist on '${entity.name}'.");
    }

    return backing.valueForProperty(prop);
  }

  /// Sets a value by property name in [backing].
  void operator []=(String? propertyName, dynamic value) {
    final prop = properties[propertyName];
    if (prop == null) {
      throw ArgumentError("Invalid property access for '${entity.name}'. "
          "Property '$propertyName' does not exist on '${entity.name}'.");
    }

    backing.setValueForProperty(prop, value);
  }

  /// Removes a property from [backing].
  ///
  /// This will remove a value from the backing map.
  void removePropertyFromBackingMap(String propertyName) {
    backing.removeProperty(propertyName);
  }

  /// Removes multiple properties from [backing].
  void removePropertiesFromBackingMap(List<String> propertyNames) {
    for (final propertyName in propertyNames) {
      backing.removeProperty(propertyName);
    }
  }

  /// Checks whether or not a property has been set in this instances' [backing].
  bool hasValueForProperty(String propertyName) {
    return backing.contents.containsKey(propertyName);
  }

  /// Callback to modify an object prior to updating it with a [Query].
  ///
  /// Subclasses of this type may override this method to set or modify values prior to being updated
  /// via [Query.update] or [Query.updateOne]. It is automatically invoked by [Query.update] and [Query.updateOne].
  ///
  /// This method is invoked prior to validation and therefore any values modified in this method
  /// are subject to the validation behavior of this instance.
  ///
  /// An example implementation would set the 'updatedDate' of an object each time it was updated:
  ///
  ///         @override
  ///         void willUpdate() {
  ///           updatedDate = new DateTime.now().toUtc();
  ///         }
  ///
  /// This method is only invoked when a query is configured by its [Query.values]. This method is not invoked
  /// if [Query.valueMap] is used to configure a query.
  void willUpdate() {}

  /// Callback to modify an object prior to inserting it with a [Query].
  ///
  /// Subclasses of this type may override this method to set or modify values prior to being inserted
  /// via [Query.insert]. It is automatically invoked by [Query.insert].
  ///
  /// This method is invoked prior to validation and therefore any values modified in this method
  /// are subject to the validation behavior of this instance.
  ///
  /// An example implementation would set the 'createdDate' of an object when it is first created
  ///
  ///         @override
  ///         void willInsert() {
  ///           createdDate = new DateTime.now().toUtc();
  ///         }
  ///
  /// This method is only invoked when a query is configured by its [Query.values]. This method is not invoked
  /// if [Query.valueMap] is used to configure a query.
  void willInsert() {}

  /// Validates an object according to its property [Validate] metadata.
  ///
  /// This method is invoked by [Query] when inserting or updating an instance of this type. By default,
  /// this method runs all of the [Validate] metadata for each property of this instance's persistent type. See [Validate]
  /// for more information. If validations succeed, the returned context [ValidationContext.isValid] will be true. Otherwise,
  /// it is false and all errors are available in [ValidationContext.errors].
  ///
  /// This method returns the result of [ManagedValidator.run]. You may override this method to provide additional validation
  /// prior to insertion or deletion. If you override this method, you *must* invoke the super implementation to
  /// allow [Validate] annotations to run, e.g.:
  ///
  ///         ValidationContext validate({Validating forEvent: Validating.insert}) {
  ///           var context = super(forEvent: forEvent);
  ///
  ///           if (a + b > 10) {
  ///             context.addError("a + b > 10");
  ///           }
  ///
  ///           return context;
  ///         }
  @mustCallSuper
  ValidationContext validate({Validating forEvent = Validating.insert}) {
    return ManagedValidator.run(this, event: forEvent);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final propertyName = entity.runtime.getPropertyName(invocation, entity);
    if (propertyName != null) {
      if (invocation.isGetter) {
        return this[propertyName];
      } else if (invocation.isSetter) {
        this[propertyName] = invocation.positionalArguments.first;

        return null;
      }
    }

    throw NoSuchMethodError.withInvocation(this, invocation);
  }

  @override
  void readFromMap(Map<String, dynamic> object) {
    object.forEach((key, v) {
      final property = responseKeyProperties[key];
      if (property == null) {
        throw ValidationException(["invalid input key '$key'"]);
      }
      if (property.isPrivate) {
        throw ValidationException(["invalid input key '$key'"]);
      }

      if (property is ManagedAttributeDescription) {
        if (!property.isTransient) {
          backing.setValueForProperty(
            property,
            property.convertFromPrimitiveValue(v),
          );
        } else {
          if (!property.transientStatus!.isAvailableAsInput) {
            throw ValidationException(["invalid input key '$key'"]);
          }

          final decodedValue = property.convertFromPrimitiveValue(v);

          if (!property.isAssignableWith(decodedValue)) {
            throw ValidationException(["invalid input type for key '$key'"]);
          }

          entity.runtime
              .setTransientValueForKey(this, property.name, decodedValue);
        }
      } else {
        backing.setValueForProperty(
          property,
          property.convertFromPrimitiveValue(v),
        );
      }
    });
  }

  /// Converts this instance into a serializable map.
  ///
  /// This method returns a map of the key-values pairs in this instance. This value is typically converted into a transmission format like JSON.
  ///
  /// Only properties present in [backing] are serialized, otherwise, they are omitted from the map. If a property is present in [backing] and the value is null,
  /// the value null will be serialized for that property key.
  ///
  /// Usage:
  ///     var json = json.encode(model.asMap());
  @override
  Map<String, dynamic> asMap() {
    final outputMap = <String, dynamic>{};

    backing.contents.forEach((k, v) {
      if (!_isPropertyPrivate(k)) {
        final property = properties[k];
        final value = property!.convertToPrimitiveValue(v);
        if (value == null && !_includeIfNull(property)) {
          return;
        }
        outputMap[mapKeyName(k)] = value;
      }
    });

    entity.attributes.values
        .where((attr) => attr!.transientStatus?.isAvailableAsOutput ?? false)
        .forEach((attr) {
      final value = entity.runtime.getTransientValueForKey(this, attr!.name);
      if (value != null) {
        outputMap[mapKeyName(attr.responseKey?.name ?? attr.name)] = value;
      }
    });

    return outputMap;
  }

  @override
  APISchemaObject documentSchema(APIDocumentContext context) =>
      entity.document(context);

  static bool _isPropertyPrivate(String propertyName) =>
      propertyName.startsWith("_");

  bool _includeIfNull(ManagedPropertyDescription property) =>
      property.responseKey?.includeIfNull ?? modelFieldIncludeIfNull;
}

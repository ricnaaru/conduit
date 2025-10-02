import 'dart:io';
import 'dart:mirrors';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:conduit_runtime/src/analyzer.dart';
import 'package:conduit_runtime/src/context.dart';
import 'package:conduit_runtime/src/mirror_context.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

/// Configuration and context values used during [Build.execute].
class BuildContext {
  BuildContext(
    this.rootLibraryFileUri,
    this.buildDirectoryUri,
    this.executableUri,
    this.source, {
    this.environment,
    this.forTests = false,
  }) {
    analyzer = CodeAnalyzer(sourceApplicationDirectory.uri);
  }

  factory BuildContext.fromMap(Map<String, dynamic> map) {
    return BuildContext(
      Uri.parse(map['rootLibraryFileUri']),
      Uri.parse(map['buildDirectoryUri']),
      Uri.parse(map['executableUri']),
      map['source'],
      environment: map['environment'],
      forTests: map['forTests'] ?? false,
    );
  }

  Map<String, dynamic> get safeMap => {
        'rootLibraryFileUri': sourceLibraryFile.uri.toString(),
        'buildDirectoryUri': buildDirectoryUri.toString(),
        'source': source,
        'executableUri': executableUri.toString(),
        'environment': environment,
        'forTests': forTests
      };

  late final CodeAnalyzer analyzer;

  /// A [Uri] to the library file of the application to be compiled.
  final Uri rootLibraryFileUri;

  /// A [Uri] to the executable build product file.
  final Uri executableUri;

  /// A [Uri] to directory where build artifacts are stored during the build process.
  final Uri buildDirectoryUri;

  /// The source script for the executable.
  final String source;

  /// Whether dev dependencies of the application package are included in the dependencies of the compiled executable.
  final bool forTests;

  PackageConfig? _packageConfig;

  final Map<String, String>? environment;

  /// The [RuntimeContext] available during the build process.
  MirrorContext get context => RuntimeContext.current as MirrorContext;

  Uri get targetScriptFileUri => forTests
      ? getDirectory(buildDirectoryUri.resolve("test/"))
          .uri
          .resolve("main_test.dart")
      : buildDirectoryUri.resolve("main.dart");

  Pubspec get sourceApplicationPubspec => Pubspec.parse(
        File.fromUri(sourceApplicationDirectory.uri.resolve("pubspec.yaml"))
            .readAsStringSync(),
      );

  Map<dynamic, dynamic> get sourceApplicationPubspecMap => loadYaml(
        File.fromUri(
          sourceApplicationDirectory.uri.resolve("pubspec.yaml"),
        ).readAsStringSync(),
      ) as Map<dynamic, dynamic>;

  /// The directory of the application being compiled.
  Directory get sourceApplicationDirectory =>
      getDirectory(rootLibraryFileUri.resolve("../"));

  /// The library file of the application being compiled.
  File get sourceLibraryFile => getFile(rootLibraryFileUri);

  /// The directory where build artifacts are stored.
  Directory get buildDirectory => getDirectory(buildDirectoryUri);

  /// The generated runtime directory
  Directory get buildRuntimeDirectory =>
      getDirectory(buildDirectoryUri.resolve("generated_runtime/"));

  /// Directory for compiled packages
  Directory get buildPackagesDirectory =>
      getDirectory(buildDirectoryUri.resolve("packages/"));

  /// Directory for compiled application
  Directory get buildApplicationDirectory => getDirectory(
        buildPackagesDirectory.uri.resolve("${sourceApplicationPubspec.name}/"),
      );

  /// Gets dependency package location relative to [sourceApplicationDirectory].
  Future<PackageConfig> get packageConfig async {
    return _packageConfig ??=
        (await findPackageConfig(sourceApplicationDirectory))!;
  }

  /// Returns a [Directory] at [uri], creates it recursively if it doesn't exist.
  Directory getDirectory(Uri uri) {
    final dir = Directory.fromUri(uri);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Returns a [File] at [uri], creates all parent directories recursively if necessary.
  File getFile(Uri uri) {
    final file = File.fromUri(uri);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    return file;
  }

  Future<Package?> getPackageFromUri(Uri? uri) async {
    if (uri == null) {
      return null;
    }
    if (uri.scheme == "package") {
      final segments = uri.pathSegments;
      return (await packageConfig)[segments.first]!;
    } else if (!uri.isAbsolute) {
      throw ArgumentError("'uri' must be absolute or a package URI");
    }
    return null;
  }

  Future<List<String>> getImportDirectives({
    Uri? uri,
    String? source,
    bool alsoImportOriginalFile = false,
  }) async {
    if (uri != null && source != null) {
      throw ArgumentError(
        "either uri or source must be non-null, but not both",
      );
    }

    if (uri == null && source == null) {
      throw ArgumentError(
        "either uri or source must be non-null, but not both",
      );
    }

    if (alsoImportOriginalFile == true && uri == null) {
      throw ArgumentError(
        "flag 'alsoImportOriginalFile' may only be set if 'uri' is also set",
      );
    }
    final Package? package = await getPackageFromUri(uri);
    final String? trailingSegments = uri?.pathSegments.sublist(1).join('/');
    final fileUri =
        package?.packageUriRoot.resolve(trailingSegments ?? '') ?? uri;
    final text = source ?? File.fromUri(fileUri!).readAsStringSync();
    final importRegex = RegExp("import [\\'\\\"]([^\\'\\\"]*)[\\'\\\"];");

    final imports = importRegex.allMatches(text).map((m) {
      final importedUri = Uri.parse(m.group(1)!);

      if (!importedUri.isAbsolute) {
        final path = fileUri
            ?.resolve(importedUri.path)
            .toFilePath(windows: Platform.isWindows);
        return "import 'file:${absolute(path!)}';";
      }

      return text.substring(m.start, m.end);
    }).toList();

    if (alsoImportOriginalFile) {
      imports.add("import '$uri';");
    }

    return imports;
  }

  Future<ClassDeclaration?> getClassDeclarationFromType(Type type) async {
    final classMirror = reflectType(type);
    Uri uri = classMirror.location!.sourceUri;
    if (!classMirror.location!.sourceUri.isAbsolute) {
      final Package? package = await getPackageFromUri(uri);
      uri = package!.packageUriRoot;
    }
    return analyzer.getClassFromFile(
      MirrorSystem.getName(classMirror.simpleName),
      uri,
    );
  }

  Future<FieldDeclaration?> _getField(ClassMirror type, String propertyName) {
    return getClassDeclarationFromType(type.reflectedType).then((cd) {
      try {
        return cd!.members.firstWhere(
          (m) => (m as FieldDeclaration)
              .fields
              .variables
              .any((v) => v.name.value() == propertyName),
        ) as FieldDeclaration;
      } catch (e) {
        return null;
      }
    });
  }

  Future<List<Annotation>> getAnnotationsFromField(
    Type type1,
    String propertyName,
  ) async {
    var type = reflectClass(type1);
    FieldDeclaration? field = await _getField(type, propertyName);
    while (field == null) {
      type = type.superclass!;
      if (type.reflectedType == Object) {
        break;
      }
      field = await _getField(type, propertyName);
    }

    if (field == null) {
      return [];
    }

    return field.metadata;
  }
}

import 'dart:io';

import 'package:conduit_runtime/runtime.dart';
import 'package:crypto/crypto.dart';

class MigrationSource {
  MigrationSource(this.source, this.uri, int nameStartIndex, int nameEndIndex) {
    originalName = source!.substring(nameStartIndex, nameEndIndex);
    name = "M${md5.convert(source!.codeUnits)}";
    source = source!.replaceRange(nameStartIndex, nameEndIndex, name);
  }

  MigrationSource.fromMap(Map<String, dynamic> map) {
    originalName = map["originalName"] as String;
    source = map["source"] as String?;
    name = map["name"] as String;
    uri = map["uri"] as String?;
  }

  factory MigrationSource.fromFile(Uri uri) {
    final analyzer = CodeAnalyzer(uri);
    final migrationTypes = analyzer.getSubclassesFromFile("Migration", uri);
    if (migrationTypes.length != 1) {
      throw StateError(
        "Invalid migration file. Must contain exactly one 'Migration' subclass. File: '$uri'.",
      );
    }

    final klass = migrationTypes.first;
    final source = klass.toSource();
    final offset = klass.name.offset - klass.offset;
    return MigrationSource(
      source,
      uri.toFilePath(windows: Platform.isWindows),
      offset,
      offset + klass.name.length,
    );
  }

  Map<String, dynamic> asMap() {
    return {
      "originalName": originalName,
      "name": name,
      "source": source,
      "uri": uri
    };
  }

  static String combine(List<MigrationSource> sources) {
    return sources.map((s) => s.source).join("\n");
  }

  static int versionNumberFromUri(Uri uri) {
    final fileName = uri.pathSegments.last;
    final migrationName = fileName.split(".").first;
    return int.parse(migrationName.split("_").first);
  }

  String? source;

  late final String originalName;

  late final String name;

  String? uri;

  int get versionNumber => versionNumberFromUri(Uri.parse(uri!));
}

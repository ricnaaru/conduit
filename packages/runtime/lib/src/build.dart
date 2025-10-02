// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:conduit_runtime/src/build_context.dart';
import 'package:conduit_runtime/src/compiler.dart';
import 'package:conduit_runtime/src/generator.dart';
import 'package:io/io.dart';
import 'package:package_config/package_config.dart';

class Build {
  Build(this.context);

  final BuildContext context;

  Future execute() async {
    final compilers = context.context.compilers;

    print("Resolving ASTs...");
    final astsToResolve = <Uri>{
      ...compilers.expand((c) => c.getUrisToResolve(context))
    };
    await Future.forEach<Uri>(
      astsToResolve,
      (astUri) async {
        final package = await context.getPackageFromUri(astUri);
        final Uri packageUri =
            package?.packageUriRoot.resolve(package.name) ?? astUri;
        try {
          await context.analyzer.resolveUnitOrLibraryAt(packageUri);
        } catch (e) {
          print('Invalid path at $astUri');
        }
      },
    );

    print("Generating runtime...");

    final runtimeGenerator = RuntimeGenerator();
    for (final MapEntry<String, dynamic> entry
        in context.context.runtimes.map.entries) {
      if (entry.value is SourceCompiler) {
        await (entry.value as SourceCompiler).compile(context).then(
              (source) =>
                  runtimeGenerator.addRuntime(name: entry.key, source: source),
            );
      }
    }

    await runtimeGenerator.writeTo(context.buildRuntimeDirectory.uri);
    print("Generated runtime at '${context.buildRuntimeDirectory.uri}'.");

    final nameOfPackageBeingCompiled = context.sourceApplicationPubspec.name;
    final pubspecMap = <String, Object>{
      'name': 'runtime_target',
      'version': '1.0.0',
      'environment': {'sdk': '>=3.4.0 <4.0.0'},
      'dependency_overrides': {}
    };
    final overrides = pubspecMap['dependency_overrides'] as Map;
    var sourcePackageIsCompiled = false;

    for (final compiler in compilers) {
      final packageInfo = await _getPackageInfoForCompiler(compiler);
      final sourceDirUri = packageInfo.root;
      final targetDirUri =
          context.buildPackagesDirectory.uri.resolve("${packageInfo.name}/");
      print("Compiling package '${packageInfo.name}'...");
      await copyPackage(sourceDirUri, targetDirUri);
      compiler.deflectPackage(Directory.fromUri(targetDirUri));

      if (packageInfo.name != nameOfPackageBeingCompiled) {
        overrides[packageInfo.name] = {
          "path": targetDirUri.toFilePath(windows: Platform.isWindows)
        };
      } else {
        sourcePackageIsCompiled = true;
      }
      print("Package '${packageInfo.name}' compiled to '$targetDirUri'.");
    }

    final appDst = context.buildApplicationDirectory.uri;
    if (!sourcePackageIsCompiled) {
      print(
        "Copying application package (from '${context.sourceApplicationDirectory.uri}')...",
      );
      await copyPackage(context.sourceApplicationDirectory.uri, appDst);
      print("Application packaged copied to '$appDst'.");
    }
    pubspecMap['dependencies'] = {
      nameOfPackageBeingCompiled: {
        "path": appDst.toFilePath(windows: Platform.isWindows)
      }
    };

    if (context.forTests) {
      final devDeps = context.sourceApplicationPubspecMap['dev_dependencies'];
      if (devDeps != null) {
        pubspecMap['dev_dependencies'] = devDeps;
      }

      overrides['conduit_core'] = {
        'path': appDst.toFilePath(windows: Platform.isWindows)
      };
    }

    File.fromUri(context.buildDirectoryUri.resolve("pubspec.yaml"))
        .writeAsStringSync(json.encode(pubspecMap));

    context
        .getFile(context.targetScriptFileUri)
        .writeAsStringSync(context.source);

    for (final compiler in context.context.compilers) {
      compiler.didFinishPackageGeneration(context);
    }

    print("Fetching dependencies (--offline --no-precompile)...");
    await getDependencies();
    print("Finished fetching dependencies.");
    if (!context.forTests) {
      print("Compiling...");
      await compile(context.targetScriptFileUri, context.executableUri);
      print("Success. Executable is located at '${context.executableUri}'.");
    }
  }

  Future getDependencies() async {
    const String cmd = "dart";

    final res = await Process.run(
      cmd,
      ["pub", "get", "--offline", "--no-precompile"],
      workingDirectory:
          context.buildDirectoryUri.toFilePath(windows: Platform.isWindows),
      runInShell: true,
    );
    if (res.exitCode != 0) {
      print("${res.stdout}");
      throw StateError(
        "'pub get' failed with the following message: ${res.stderr}",
      );
    }
  }

  Future compile(Uri srcUri, Uri dstUri) async {
    final res = await Process.run(
      "dart",
      [
        "compile",
        "exe",
        ...(context.environment?.entries.map((e) => "-D${e.key}=${e.value}") ??
            []),
        "-v",
        srcUri.toFilePath(windows: Platform.isWindows),
        "-o",
        dstUri.toFilePath(windows: Platform.isWindows)
      ],
      workingDirectory: context.buildApplicationDirectory.uri
          .toFilePath(windows: Platform.isWindows),
      runInShell: true,
    );

    if (res.exitCode != 0) {
      throw StateError(
        "'dart2native' failed with the following message: ${res.stderr}",
      );
    }
    print("${res.stdout}");
  }

  Future copyPackage(Uri srcUri, Uri dstUri) async {
    final dstDir = Directory.fromUri(dstUri);
    if (!dstDir.existsSync()) {
      dstDir.createSync(recursive: true);
    }
    try {
      await copyPath(
        srcUri.toFilePath(windows: Platform.isWindows),
        dstUri.toFilePath(windows: Platform.isWindows),
      );
    } on FileSystemException catch (e) {
      if (Platform.isWindows) {
        final File f = File(e.path!);
        if (f.existsSync()) {
          f.deleteSync();
        }
        File(e.path!).writeAsStringSync('dummy');
        await copyPath(
          srcUri.toFilePath(windows: Platform.isWindows),
          dstUri.toFilePath(windows: Platform.isWindows),
        );
      } else {
        rethrow;
      }
    }

    return context.getFile(srcUri.resolve("pubspec.yaml")).copy(
          dstUri
              .resolve("pubspec.yaml")
              .toFilePath(windows: Platform.isWindows),
        );
  }

  Future<Package> _getPackageInfoForCompiler(Compiler compiler) async {
    final compilerUri = reflect(compiler).type.location!.sourceUri;

    return (await context.packageConfig)[compilerUri.pathSegments.first]!;
  }
}

// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:_fe_analyzer_shared/src/scanner/token_impl.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:analyzer/src/dart/analysis/feature_set_provider.dart';
import 'package:analyzer/src/dart/analysis/unlinked_api_signature.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/micro/cider_byte_store.dart';
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';
import 'package:analyzer/src/summary/api_signature.dart';
import 'package:analyzer/src/summary/format.dart';
import 'package:analyzer/src/summary/idl.dart';
import 'package:analyzer/src/summary/link.dart' as graph
    show DependencyWalker, Node;
import 'package:analyzer/src/summary2/informative_data.dart';
import 'package:analyzer/src/util/file_paths.dart' as file_paths;
import 'package:analyzer/src/util/performance/operation_performance.dart';
import 'package:analyzer/src/workspace/workspace.dart';
import 'package:collection/collection.dart';
import 'package:convert/convert.dart';
import 'package:pub_semver/pub_semver.dart';

/// Ensure that the [FileState.libraryCycle] for the [file] and anything it
/// depends on is computed.
void computeLibraryCycle(Uint32List linkedSalt, FileState file) {
  var libraryWalker = _LibraryWalker(linkedSalt);
  libraryWalker.walk(libraryWalker.getNode(file));
}

class FileState {
  final FileSystemState _fsState;

  /// The path of the file.
  final String path;

  /// The URI of the file.
  final Uri uri;

  /// The [Source] of the file with the [uri].
  final Source source;

  /// The [WorkspacePackage] that contains this file.
  ///
  /// It might be `null` if the file is outside of the workspace.
  final WorkspacePackage? workspacePackage;

  /// The [FeatureSet] for all files in the analysis context.
  ///
  /// Usually it is the feature set of the latest language version, plus
  /// possibly additional enabled experiments (from the analysis options file,
  /// or from SDK allowed experiments).
  ///
  /// This feature set is then restricted, with the [_packageLanguageVersion],
  /// or with a `@dart` language override token in the file header.
  final FeatureSet _contextFeatureSet;

  /// The language version for the package that contains this file.
  final Version _packageLanguageVersion;

  /// Files that reference this file.
  final List<FileState> referencingFiles = [];

  final List<FileState> importedFiles = [];
  final List<FileState> exportedFiles = [];
  final List<FileState> partedFiles = [];
  final Set<FileState> directReferencedFiles = {};
  final Set<FileState> directReferencedLibraries = {};
  final List<FileState> libraryFiles = [];
  FileState? partOfLibrary;

  late List<int> _digest;
  late bool _exists;
  late List<int> _apiSignature;
  late UnlinkedUnit2 unlinked2;
  Uint8List? informativeBytes;
  LibraryCycle? _libraryCycle;

  /// id of the cache entry with unlinked data.
  late int unlinkedId;

  /// id of the cache entry with informative data.
  /// We use a separate entry because there is no good way to efficiently
  /// store a raw byte array.
  late int informativeId;

  FileState._(
    this._fsState,
    this.path,
    this.uri,
    this.source,
    this.workspacePackage,
    this._contextFeatureSet,
    this._packageLanguageVersion,
  );

  List<int> get apiSignature => _apiSignature;

  List<int> get digest => _digest;

  bool get exists => _exists;

  /// Return the [LibraryCycle] this file belongs to, even if it consists of
  /// just this file.  If the library cycle is not known yet, compute it.
  LibraryCycle get libraryCycle {
    if (_libraryCycle == null) {
      computeLibraryCycle(_fsState._linkedSalt, this);
    }
    return _libraryCycle!;
  }

  LineInfo get lineInfo => LineInfo(unlinked2.lineStarts);

  /// The resolved signature of the file, that depends on the [libraryCycle]
  /// signature, and the content of the file.
  String get resolvedSignature {
    var signatureBuilder = ApiSignature();
    signatureBuilder.addString(path);
    signatureBuilder.addBytes(libraryCycle.signature);

    var content = getContentWithSameDigest();
    signatureBuilder.addString(content);

    return signatureBuilder.toHex();
  }

  /// Return the [uri] string.
  String get uriStr => uri.toString();

  /// Collect all files that are transitively referenced by this file via
  /// imports, exports, and parts.
  void collectAllReferencedFiles(Set<String> referencedFiles) {
    for (var file in {...importedFiles, ...exportedFiles, ...partedFiles}) {
      if (referencedFiles.add(file.path)) {
        file.collectAllReferencedFiles(referencedFiles);
      }
    }
  }

  /// Return the content of the file, the empty string if cannot be read.
  String getContent() {
    try {
      var resource = _fsState._resourceProvider.getFile(path);
      return resource.readAsStringSync();
    } catch (_) {
      return '';
    }
  }

  /// Return the content of the file, the empty string if cannot be read.
  ///
  /// Additionally, we read the file digest, end verify that it is the same
  /// as the [_digest] that we recorded in [refresh]. If it is not, then the
  /// file was changed, and we failed to call [FileSystemState.changeFile]
  String getContentWithSameDigest() {
    var digest = utf8.encode(_fsState.getFileDigest(path));
    if (!const ListEquality<int>().equals(digest, _digest)) {
      throw StateError('File was changed, but not invalidated: $path');
    }

    return getContent();
  }

  void internal_setLibraryCycle(LibraryCycle cycle, String signature) {
    _libraryCycle = cycle;
  }

  CompilationUnitImpl parse(
      AnalysisErrorListener errorListener, String content) {
    CharSequenceReader reader = CharSequenceReader(content);
    Scanner scanner = Scanner(source, reader, errorListener)
      ..configureFeatures(
        featureSetForOverriding: _contextFeatureSet,
        featureSet: _contextFeatureSet.restrictToVersion(
          _packageLanguageVersion,
        ),
      );
    Token token = scanner.tokenize(reportScannerErrors: false);
    LineInfo lineInfo = LineInfo(scanner.lineStarts);

    // Pass the feature set from the scanner to the parser
    // because the scanner may have detected a language version comment
    // and downgraded the feature set it holds.
    Parser parser = Parser(
      source,
      errorListener,
      featureSet: scanner.featureSet,
    );
    parser.enableOptionalNewAndConst = true;
    var unit = parser.parseCompilationUnit(token);
    unit.lineInfo = lineInfo;

    // StringToken uses a static instance of StringCanonicalizer, so we need
    // to clear it explicitly once we are done using it for this file.
    StringToken.canonicalizer.clear();

    // TODO(scheglov) Use actual versions.
    unit.languageVersion = LibraryLanguageVersion(
      package: ExperimentStatus.currentVersion,
      override: null,
    );

    return unit;
  }

  void refresh({
    FileState? containingLibrary,
    required OperationPerformanceImpl performance,
  }) {
    _fsState.testView.refreshedFiles.add(path);
    performance.getDataInt('count').increment();

    performance.run('digest', (_) {
      _digest = utf8.encode(_fsState.getFileDigest(path));
      _exists = _digest.isNotEmpty;
    });

    String unlinkedKey = '$path.unlinked';
    String informativeKey = '$path.informative';

    // Prepare bytes of the unlinked bundle - existing or new.
    // TODO(migration): should not be nullable
    List<int>? unlinkedBytes;
    List<int>? informativeBytes;
    {
      var unlinkedData = _fsState._byteStore.get(unlinkedKey, _digest);
      var informativeData = _fsState._byteStore.get(informativeKey, _digest);
      unlinkedBytes = unlinkedData?.bytes;
      informativeBytes = informativeData?.bytes;

      if (unlinkedBytes == null ||
          unlinkedBytes.isEmpty ||
          informativeBytes == null ||
          informativeBytes.isEmpty) {
        var content = performance.run('content', (_) {
          return getContent();
        });

        var unit = performance.run('parse', (performance) {
          performance.getDataInt('count').increment();
          performance.getDataInt('length').add(content.length);
          return parse(AnalysisErrorListener.NULL_LISTENER, content);
        });

        performance.run('unlinked', (performance) {
          var unlinkedBuilder = serializeAstCiderUnlinked(_digest, unit);
          unlinkedBytes = unlinkedBuilder.toBuffer();
          performance.getDataInt('length').add(unlinkedBytes!.length);
          unlinkedData =
              _fsState._byteStore.putGet(unlinkedKey, _digest, unlinkedBytes!);
          unlinkedBytes = unlinkedData!.bytes;
        });

        performance.run('informative', (performance) {
          informativeBytes = writeUnitInformative(unit);
          performance.getDataInt('length').add(informativeBytes!.length);
          informativeData = _fsState._byteStore
              .putGet(informativeKey, _digest, informativeBytes!);
          informativeBytes = informativeData!.bytes;
        });

        performance.run('prefetch', (_) {
          var decoded = CiderUnlinkedUnit.fromBuffer(unlinkedBytes!);
          unlinked2 = decoded.unlinkedUnit!;
          _prefetchDirectReferences(unlinked2);
        });
      }
      unlinkedId = unlinkedData!.id;
      informativeId = informativeData!.id;
      this.informativeBytes = Uint8List.fromList(informativeBytes!);
    }

    // Read the unlinked bundle.
    unlinked2 = CiderUnlinkedUnit.fromBuffer(unlinkedBytes!).unlinkedUnit!;
    _apiSignature = Uint8List.fromList(unlinked2.apiSignature);

    // Build the graph.
    for (var directive in unlinked2.imports) {
      var file = _fileForRelativeUri(
        relativeUri: directive.uri,
        performance: performance,
      );
      if (file != null) {
        importedFiles.add(file);
      }
    }
    for (var directive in unlinked2.exports) {
      var file = _fileForRelativeUri(
        relativeUri: directive.uri,
        performance: performance,
      );
      if (file != null) {
        exportedFiles.add(file);
      }
    }
    for (var uri in unlinked2.parts) {
      var file = _fileForRelativeUri(
        containingLibrary: this,
        relativeUri: uri,
        performance: performance,
      );
      if (file != null) {
        partedFiles.add(file);
      }
    }
    if (unlinked2.hasPartOfDirective) {
      if (containingLibrary == null) {
        _fsState.testView.partsDiscoveredLibraries.add(path);
        var libraryName = unlinked2.partOfName;
        var libraryUri = unlinked2.partOfUri;
        partOfLibrary = null;
        if (libraryName.isNotEmpty) {
          _findPartOfNameLibrary(performance: performance);
        } else if (libraryUri.isNotEmpty) {
          partOfLibrary = _fileForRelativeUri(
            relativeUri: libraryUri,
            performance: performance,
          );
        }
      } else {
        partOfLibrary = containingLibrary;
      }
      if (partOfLibrary != null) {
        directReferencedFiles.add(partOfLibrary!);
      }
    }
    libraryFiles.add(this);
    libraryFiles.addAll(partedFiles);

    // Compute referenced files.
    directReferencedFiles
      ..addAll(importedFiles)
      ..addAll(exportedFiles)
      ..addAll(partedFiles);
    directReferencedLibraries
      ..addAll(importedFiles)
      ..addAll(exportedFiles);
  }

  @override
  String toString() {
    return path;
  }

  FileState? _fileForRelativeUri({
    FileState? containingLibrary,
    required String relativeUri,
    required OperationPerformanceImpl performance,
  }) {
    if (relativeUri.isEmpty) {
      return null;
    }

    Uri absoluteUri;
    try {
      absoluteUri = resolveRelativeUri(uri, Uri.parse(relativeUri));
    } on FormatException {
      return null;
    }

    var file = _fsState.getFileForUri(
      containingLibrary: containingLibrary,
      uri: absoluteUri,
      performance: performance,
    );
    if (file == null) {
      return null;
    }

    file.referencingFiles.add(this);
    return file;
  }

  /// This file has a `part of some.library;` directive. Because it does not
  /// specify the URI of the library, we don't know the library for sure.
  /// But usually the library is one of the sibling files.
  void _findPartOfNameLibrary({
    required OperationPerformanceImpl performance,
  }) {
    var resourceProvider = _fsState._resourceProvider;
    var pathContext = resourceProvider.pathContext;

    var children = <Resource>[];
    try {
      var parent = resourceProvider.getFile(path).parent2;
      children = parent.getChildren();
    } catch (_) {}

    for (var siblingFile in children) {
      if (file_paths.isDart(pathContext, siblingFile.path)) {
        var childState = _fsState.getFileForPath(
          path: siblingFile.path,
          performance: performance,
        );
        if (childState.partedFiles.contains(this)) {
          partOfLibrary = childState;
          break;
        }
      }
    }
  }

  void _prefetchDirectReferences(UnlinkedUnit2 unlinkedUnit2) {
    if (_fsState.prefetchFiles == null) {
      return;
    }

    var paths = <String>{};

    void findPathForUri(String relativeUri) {
      if (relativeUri.isEmpty) {
        return;
      }
      Uri absoluteUri;
      try {
        absoluteUri = resolveRelativeUri(uri, Uri.parse(relativeUri));
      } on FormatException {
        return;
      }
      var p = _fsState.getPathForUri(absoluteUri);
      if (p != null) {
        paths.add(p);
      }
    }

    for (var directive in unlinked2.imports) {
      findPathForUri(directive.uri);
    }
    for (var directive in unlinked2.exports) {
      findPathForUri(directive.uri);
    }
    for (var uri in unlinked2.parts) {
      findPathForUri(uri);
    }
    _fsState.prefetchFiles!(paths.toList());
  }

  static CiderUnlinkedUnitBuilder serializeAstCiderUnlinked(
      List<int> digest, CompilationUnit unit) {
    var exports = <UnlinkedNamespaceDirectiveBuilder>[];
    var imports = <UnlinkedNamespaceDirectiveBuilder>[];
    var parts = <String>[];
    var hasDartCoreImport = false;
    var hasLibraryDirective = false;
    var hasPartOfDirective = false;
    var partOfUriStr = '';
    var partOfName = '';
    for (var directive in unit.directives) {
      if (directive is ExportDirective) {
        var builder = _serializeNamespaceDirective(directive);
        exports.add(builder);
      } else if (directive is ImportDirective) {
        var builder = _serializeNamespaceDirective(directive);
        imports.add(builder);
        if (builder.uri == 'dart:core') {
          hasDartCoreImport = true;
        }
      } else if (directive is LibraryDirective) {
        hasLibraryDirective = true;
      } else if (directive is PartDirective) {
        var uriStr = directive.uri.stringValue;
        parts.add(uriStr ?? '');
      } else if (directive is PartOfDirective) {
        hasPartOfDirective = true;
        var libraryName = directive.libraryName;
        var uriStr = directive.uri?.stringValue;
        if (libraryName != null) {
          partOfName = libraryName.components.map((e) => e.name).join('.');
        } else if (uriStr != null) {
          partOfUriStr = uriStr;
        }
      }
    }
    if (!hasDartCoreImport) {
      imports.add(
        UnlinkedNamespaceDirectiveBuilder(
          uri: 'dart:core',
        ),
      );
    }
    var unlinkedBuilder = UnlinkedUnit2Builder(
      apiSignature: computeUnlinkedApiSignature(unit),
      exports: exports,
      imports: imports,
      parts: parts,
      hasLibraryDirective: hasLibraryDirective,
      hasPartOfDirective: hasPartOfDirective,
      partOfName: partOfName,
      partOfUri: partOfUriStr,
      lineStarts: unit.lineInfo!.lineStarts,
    );
    return CiderUnlinkedUnitBuilder(
        contentDigest: digest, unlinkedUnit: unlinkedBuilder);
  }

  static UnlinkedNamespaceDirectiveBuilder _serializeNamespaceDirective(
      NamespaceDirective directive) {
    return UnlinkedNamespaceDirectiveBuilder(
      configurations: directive.configurations.map((configuration) {
        var name = configuration.name.components.join('.');
        var value = configuration.value?.stringValue ?? '';
        return UnlinkedNamespaceDirectiveConfigurationBuilder(
          name: name,
          value: value,
          uri: configuration.uri.stringValue ?? '',
        );
      }).toList(),
      uri: directive.uri.stringValue ?? '',
    );
  }
}

class FileSystemState {
  final ResourceProvider _resourceProvider;
  final CiderByteStore _byteStore;
  final SourceFactory _sourceFactory;
  final Workspace _workspace;
  final Uint32List _linkedSalt;

  /// A function that returns the digest for a file as a String. The function
  /// returns a non null value, returns an empty string if file does
  /// not exist/has no contents.
  final String Function(String path) getFileDigest;

  final Map<String, FileState> _pathToFile = {};
  final Map<Uri, FileState> _uriToFile = {};

  final FeatureSetProvider featureSetProvider;

  /// A function that fetches the given list of files. This function can be used
  /// to batch file reads in systems where file fetches are expensive.
  final void Function(List<String> paths)? prefetchFiles;

  /// A function that returns true if the given file path is likely to be that
  /// of a file that is generated.
  final bool Function(String path)? isGenerated;

  final FileSystemStateTimers timers2 = FileSystemStateTimers();

  final FileSystemStateTestView testView = FileSystemStateTestView();

  FileSystemState(
    this._resourceProvider,
    this._byteStore,
    this._sourceFactory,
    this._workspace,
    @Deprecated('No longer used; will be removed')
        AnalysisOptions analysisOptions,
    this._linkedSalt,
    this.featureSetProvider,
    this.getFileDigest,
    this.prefetchFiles,
    this.isGenerated,
  );

  /// Update the state to reflect the fact that the file with the given [path]
  /// was changed. Specifically this means that we evict this file and every
  /// file that referenced it.
  void changeFile(String path, List<FileState> removedFiles) {
    var file = _pathToFile.remove(path);
    if (file == null) {
      return;
    }

    removedFiles.add(file);
    _uriToFile.remove(file.uri);

    // The removed file does not reference other file anymore.
    for (var referencedFile in file.directReferencedFiles) {
      referencedFile.referencingFiles.remove(file);
    }

    // Recursively remove files that reference the removed file.
    for (var reference in file.referencingFiles.toList()) {
      changeFile(reference.path, removedFiles);
    }
  }

  /// Clears all the cached files. Returns the list of ids of all the removed
  /// files.
  Set<int> collectSharedDataIdentifiers() {
    var result = <int>{};
    for (var file in _pathToFile.values) {
      result.add(file.unlinkedId);
      result.add(file.informativeId);
    }
    return result;
  }

  FeatureSet contextFeatureSet(
    String path,
    Uri uri,
    WorkspacePackage? workspacePackage,
  ) {
    var workspacePackageExperiments = workspacePackage?.enabledExperiments;
    if (workspacePackageExperiments != null) {
      return featureSetProvider.featureSetForExperiments(
        workspacePackageExperiments,
      );
    }

    return featureSetProvider.getFeatureSet(path, uri);
  }

  Version contextLanguageVersion(
    String path,
    Uri uri,
    WorkspacePackage? workspacePackage,
  ) {
    var workspaceLanguageVersion = workspacePackage?.languageVersion;
    if (workspaceLanguageVersion != null) {
      return workspaceLanguageVersion;
    }

    return featureSetProvider.getLanguageVersion(path, uri);
  }

  FileState getFileForPath({
    required String path,
    required OperationPerformanceImpl performance,
  }) {
    var file = _pathToFile[path];
    if (file == null) {
      var fileUri = _resourceProvider.pathContext.toUri(path);
      var uri = _sourceFactory.restoreUri(
        _FakeSource(path, fileUri),
      );
      if (uri == null) {
        throw StateError('Unable to convert path to URI: $path');
      }

      var source = _sourceFactory.forUri2(uri);
      if (source == null) {
        throw StateError('Unable to resolve URI: $uri, path: $path');
      }

      var workspacePackage = _workspace.findPackageFor(path);
      var featureSet = contextFeatureSet(path, uri, workspacePackage);
      var packageLanguageVersion =
          contextLanguageVersion(path, uri, workspacePackage);
      file = FileState._(this, path, uri, source, workspacePackage, featureSet,
          packageLanguageVersion);

      _pathToFile[path] = file;
      _uriToFile[uri] = file;

      performance.run('refresh', (performance) {
        file!.refresh(
          performance: performance,
        );
      });
    }
    return file;
  }

  FileState? getFileForUri({
    FileState? containingLibrary,
    required Uri uri,
    required OperationPerformanceImpl performance,
  }) {
    var file = _uriToFile[uri];
    if (file == null) {
      var source = _sourceFactory.forUri2(uri);
      if (source == null) {
        return null;
      }
      var path = source.fullName;

      var workspacePackage = _workspace.findPackageFor(path);
      var featureSet = contextFeatureSet(path, uri, workspacePackage);
      var packageLanguageVersion =
          contextLanguageVersion(path, uri, workspacePackage);

      file = FileState._(this, path, uri, source, workspacePackage, featureSet,
          packageLanguageVersion);
      _pathToFile[path] = file;
      _uriToFile[uri] = file;

      file.refresh(
        containingLibrary: containingLibrary,
        performance: performance,
      );
    }
    return file;
  }

  /// Returns a list of files whose contents contains the given string.
  /// Generated files are not included in the search.
  List<String> getFilesContaining(String value) {
    var result = <String>[];
    _pathToFile.forEach((path, file) {
      var genFile = isGenerated == null ? false : isGenerated!(path);
      if (!genFile && file.getContent().contains(value)) {
        result.add(path);
      }
    });
    return result;
  }

  String? getPathForUri(Uri uri) {
    var source = _sourceFactory.forUri2(uri);
    if (source == null) {
      return null;
    }
    return source.fullName;
  }

  /// Computes the set of [FileState]'s used/not used to analyze the given
  /// [files]. Removes the [FileState]'s of the files not used for analysis from
  /// the cache. Returns the set of unused [FileState]'s.
  List<FileState> removeUnusedFiles(List<String> files) {
    var allReferenced = <String>{};
    for (var path in files) {
      allReferenced.add(path);
      _pathToFile[path]?.collectAllReferencedFiles(allReferenced);
    }

    var unusedPaths = _pathToFile.keys.toSet();
    unusedPaths.removeAll(allReferenced);
    testView.removedPaths = unusedPaths;

    var removedFiles = <FileState>[];
    for (var path in unusedPaths) {
      var file = _pathToFile.remove(path)!;
      _uriToFile.remove(file.uri);
      removedFiles.add(file);
    }

    return removedFiles;
  }
}

class FileSystemStateTestView {
  final List<String> refreshedFiles = [];
  final List<String> partsDiscoveredLibraries = [];
  Set<String> removedPaths = {};
}

class FileSystemStateTimer {
  final Stopwatch timer = Stopwatch();

  T run<T>(T Function() f) {
    timer.start();
    try {
      return f();
    } finally {
      timer.stop();
    }
  }

  Future<T> runAsync<T>(T Function() f) async {
    timer.start();
    try {
      return f();
    } finally {
      timer.stop();
    }
  }
}

class FileSystemStateTimers {
  final FileSystemStateTimer digest = FileSystemStateTimer();
  final FileSystemStateTimer read = FileSystemStateTimer();
  final FileSystemStateTimer parse = FileSystemStateTimer();
  final FileSystemStateTimer unlinked = FileSystemStateTimer();
  final FileSystemStateTimer prefetch = FileSystemStateTimer();

  void reset() {
    digest.timer.reset();
    read.timer.reset();
    parse.timer.reset();
    unlinked.timer.reset();
    prefetch.timer.reset();
  }
}

/// Information about libraries that reference each other, so form a cycle.
class LibraryCycle {
  /// The libraries that belong to this cycle.
  final List<FileState> libraries = [];

  /// The library cycles that this cycle references directly.
  final Set<LibraryCycle> directDependencies = <LibraryCycle>{};

  /// The transitive signature of this cycle.
  ///
  /// It is based on the API signatures of all files of the [libraries], and
  /// the signatures of the cycles that the [libraries] reference
  /// directly.  So, indirectly it is based on the transitive closure of all
  /// files that [libraries] reference (but we don't compute these files).
  late List<int> signature;

  /// The hash of all the paths of the files in this cycle.
  late String cyclePathsHash;

  /// The ID of the resolution cache entry.
  /// It is `null` if we failed to load libraries of the cycle.
  int? resolutionId;

  LibraryCycle();

  String get signatureStr {
    return hex.encode(signature);
  }

  @override
  String toString() {
    return '[' + libraries.join(', ') + ']';
  }
}

class _FakeSource implements Source {
  @override
  final String fullName;

  @override
  final Uri uri;

  _FakeSource(this.fullName, this.uri);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Node in [_LibraryWalker].
class _LibraryNode extends graph.Node<_LibraryNode> {
  final _LibraryWalker walker;
  final FileState file;

  _LibraryNode(this.walker, this.file);

  @override
  bool get isEvaluated => file._libraryCycle != null;

  @override
  List<_LibraryNode> computeDependencies() {
    return file.directReferencedLibraries.map(walker.getNode).toList();
  }
}

/// Helper that organizes dependencies of a library into topologically
/// sorted [LibraryCycle]s.
class _LibraryWalker extends graph.DependencyWalker<_LibraryNode> {
  final Uint32List _linkedSalt;
  final Map<FileState, _LibraryNode> nodesOfFiles = {};

  _LibraryWalker(this._linkedSalt);

  @override
  void evaluate(_LibraryNode v) {
    evaluateScc([v]);
  }

  @override
  void evaluateScc(List<_LibraryNode> scc) {
    var cycle = LibraryCycle();

    var signature = ApiSignature();
    signature.addUint32List(_linkedSalt);

    // Sort libraries to produce stable signatures.
    scc.sort((first, second) {
      var firstPath = first.file.path;
      var secondPath = second.file.path;
      return firstPath.compareTo(secondPath);
    });

    // Append direct referenced cycles.
    for (var node in scc) {
      var file = node.file;
      _appendDirectlyReferenced(cycle, signature, file.importedFiles);
      _appendDirectlyReferenced(cycle, signature, file.exportedFiles);
    }

    // Fill the cycle with libraries.
    for (var node in scc) {
      cycle.libraries.add(node.file);

      signature.addString(node.file.uriStr);

      signature.addInt(node.file.libraryFiles.length);
      for (var file in node.file.libraryFiles) {
        signature.addBool(file.exists);
        signature.addBytes(file.apiSignature);
      }
    }

    // Compute the general library cycle signature.
    cycle.signature = signature.toByteList();

    // Compute the cycle file paths signature.
    var filePathsSignature = ApiSignature();
    for (var node in scc) {
      filePathsSignature.addString(node.file.path);
    }
    cycle.cyclePathsHash = filePathsSignature.toHex();

    // Compute library specific signatures.
    for (var node in scc) {
      var librarySignatureBuilder = ApiSignature()
        ..addString(node.file.uriStr)
        ..addBytes(cycle.signature);
      var librarySignature = librarySignatureBuilder.toHex();

      node.file.internal_setLibraryCycle(
        cycle,
        librarySignature,
      );
    }
  }

  _LibraryNode getNode(FileState file) {
    return nodesOfFiles.putIfAbsent(file, () => _LibraryNode(this, file));
  }

  void _appendDirectlyReferenced(
    LibraryCycle cycle,
    ApiSignature signature,
    List<FileState> directlyReferenced,
  ) {
    signature.addInt(directlyReferenced.length);
    for (var referencedLibrary in directlyReferenced) {
      var referencedCycle = referencedLibrary._libraryCycle;
      // We get null when the library is a part of the cycle being build.
      if (referencedCycle == null) continue;

      if (cycle.directDependencies.add(referencedCycle)) {
        signature.addBytes(referencedCycle.signature);
      }
    }
  }
}

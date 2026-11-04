/// Dumps the public API of one library as the analyzer sees it under one
/// compiler's `dart.library.*` set, and checks the shared conventions.
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
// The public collection has no `declaredVariables`, and without them the
// analyzer always takes the default branch of a conditional export.
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';

/// The libraries the native compilers provide, as conditional exports see them.
const nativeLibraries = {
  'dart.library.io': 'true',
  'dart.library.ffi': 'true',
  'dart.library.isolate': 'true',
};

/// The libraries the web compilers provide.
const webLibraries = {
  'dart.library.js_interop': 'true',
  'dart.library.js_util': 'true',
  'dart.library.html': 'true',
  'dart.library.js': 'true',
};

/// Libraries whose types may not appear in a public signature: they exist on
/// some platforms only, so an API that names them cannot be identical.
const platformLibraries = [
  'dart:ffi',
  'dart:io',
  'dart:isolate',
  'dart:js_interop',
  'dart:js_interop_unsafe',
  'dart:js_util',
  'dart:js',
  'dart:html',
  'package:web/',
  'package:flutter_web_plugins/',
];

/// The public API of one library on one platform.
final class ApiDump {
  ApiDump._(this.lines, this.platformTypes, this.conventions, this.names);

  /// One line per public symbol or member, sorted.
  final List<String> lines;

  /// Public signatures that name a platform type.
  final List<String> platformTypes;

  /// Convention violations: tasks without `create`, `dispose`, `delegate` or
  /// a capability query, and options classes outside `TaskOptions`.
  final List<String> conventions;

  /// Every public name the library exports.
  final Set<String> names;
}

/// Resolves [uri] from [packageRoot] with [declaredVariables] and dumps it.
Future<ApiDump> dumpLibrary({
  required String packageRoot,
  required String uri,
  required Map<String, String> declaredVariables,
}) async {
  final library = await resolveLibrary(
    packageRoot: packageRoot,
    uri: uri,
    declaredVariables: declaredVariables,
  );
  final lines = <String>[];
  final platformTypes = <String>[];
  final conventions = <String>[];
  final namespace = library.exportNamespace.definedNames2;
  final names = namespace.keys.where(_isPublicName).toSet();
  for (final name in names.toList()..sort()) {
    final element = namespace[name]!;
    final block = <String>[];
    switch (element) {
      case InterfaceElement():
        block.addAll(_describeInterface(element));
        _checkInterfaceTypes(element, platformTypes);
        _checkConventions(element, names, conventions);
      case ExtensionElement():
        block.add('extension $name on ${_type(element.extendedType)}');
        block.addAll(_members(element, name));
        _checkMemberTypes(element, name, platformTypes);
      case TypeAliasElement():
        block.add('typedef $name = ${_type(element.aliasedType)}');
        _report(name, element.aliasedType, platformTypes);
      case TopLevelFunctionElement():
        block.add('function ${element.displayString()}');
        _checkExecutableTypes(element, name, platformTypes);
      case TopLevelVariableElement():
        block.add(
          '${element.isConst ? 'const' : 'variable'} '
          '${_type(element.type)} $name',
        );
        _report(name, element.type, platformTypes);
      case GetterElement():
        block.add('getter ${element.displayString()}');
        _checkExecutableTypes(element, name, platformTypes);
      case SetterElement():
        block.add('setter ${element.displayString()}');
        _checkExecutableTypes(element, name, platformTypes);
      default:
        block.add('${element.kind.displayName} $name');
    }
    lines.addAll(block);
  }
  return ApiDump._(lines, platformTypes..sort(), conventions..sort(), names);
}

/// One analysis context per package and set of declared variables, shared by
/// every library resolved there.
final _collections =
    <(String, Map<String, String>), AnalysisContextCollectionImpl>{};

/// Resolves [uri] inside [packageRoot]'s analysis context.
Future<LibraryElement> resolveLibrary({
  required String packageRoot,
  required String uri,
  required Map<String, String> declaredVariables,
}) async {
  final collection = _collections.putIfAbsent(
    (packageRoot, declaredVariables),
    () => AnalysisContextCollectionImpl(
      includedPaths: [packageRoot],
      declaredVariables: declaredVariables,
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    ),
  );
  final result = await collection
      .contextFor(packageRoot)
      .currentSession
      .getLibraryByUri(uri);
  if (result is! LibraryElementResult) {
    throw StateError('Could not resolve $uri from $packageRoot: $result');
  }
  return result.element;
}

bool _isPublicName(String name) => !name.startsWith('_');

String _type(DartType type) => type.getDisplayString();

List<String> _describeInterface(InterfaceElement element) {
  final name = element.name!;
  final header = StringBuffer();
  switch (element) {
    case ClassElement():
      header.write(
        [
          if (element.isAbstract) 'abstract',
          if (element.isBase) 'base',
          if (element.isInterface) 'interface',
          if (element.isFinal) 'final',
          if (element.isSealed) 'sealed',
          if (element.isMixinClass) 'mixin',
          'class',
        ].join(' '),
      );
    case MixinElement():
      header.write(element.isBase ? 'base mixin' : 'mixin');
    case EnumElement():
      header.write('enum');
    case ExtensionTypeElement():
      header.write('extension type');
    default:
      header.write(element.kind.displayName);
  }
  header.write(' $name');
  if (element.typeParameters.isNotEmpty) {
    header.write(
      '<${element.typeParameters.map((t) => t.displayString()).join(', ')}>',
    );
  }
  final supertype = element.supertype;
  if (supertype != null && !supertype.isDartCoreObject) {
    header.write(' extends ${_type(supertype)}');
  }
  if (element.mixins.isNotEmpty) {
    header.write(' with ${element.mixins.map(_type).join(', ')}');
  }
  if (element.interfaces.isNotEmpty) {
    header.write(' implements ${element.interfaces.map(_type).join(', ')}');
  }
  final lines = <String>[header.toString()];
  final members = <String>[];
  for (final constructor in element.constructors) {
    if (!constructor.isPublic) continue;
    members.add(
      '  ${constructor.isFactory ? 'factory' : 'new'} '
      '${constructor.displayString()}',
    );
  }
  if (element is EnumElement) {
    for (final constant in element.constants) {
      members.add('  value $name.${constant.name}');
    }
  }
  members.addAll(_members(element, name));
  for (final member in element.interfaceMembers.values) {
    if (!member.isPublic || _declaredOnObject(member)) continue;
    members.add('  ${member.displayString()}');
  }
  lines.addAll(members.toSet().toList()..sort());
  return lines;
}

/// The static members of [element], each prefixed with `static`.
List<String> _members(InstanceElement element, String name) {
  final members = <String>[];
  for (final field in element.fields) {
    if (field.isPublic &&
        field.isStatic &&
        (field.getter?.isOriginVariable ?? true)) {
      members.add('  static ${field.displayString()}');
    }
  }
  for (final getter in element.getters) {
    if (getter.isPublic && getter.isStatic && !getter.isOriginVariable) {
      members.add('  static ${getter.displayString()}');
    }
  }
  for (final setter in element.setters) {
    if (setter.isPublic && setter.isStatic && !setter.isOriginVariable) {
      members.add('  static ${setter.displayString()}');
    }
  }
  for (final method in element.methods) {
    if (method.isPublic && method.isStatic) {
      members.add('  static ${method.displayString()}');
    }
  }
  if (element is ExtensionElement) {
    for (final method in element.methods) {
      if (method.isPublic && !method.isStatic) {
        members.add('  ${method.displayString()}');
      }
    }
    for (final getter in element.getters) {
      if (getter.isPublic && !getter.isStatic) {
        members.add('  ${getter.displayString()}');
      }
    }
  }
  return members;
}

bool _declaredOnObject(ExecutableElement member) {
  final owner = member.enclosingElement;
  return owner is ClassElement &&
      owner.name == 'Object' &&
      owner.library.uri.toString() == 'dart:core';
}

void _checkInterfaceTypes(InterfaceElement element, List<String> findings) {
  final name = element.name!;
  for (final type in element.allSupertypes) {
    _report(name, type, findings);
  }
  for (final constructor in element.constructors) {
    if (constructor.isPublic) {
      _checkExecutableTypes(constructor, name, findings);
    }
  }
  _checkMemberTypes(element, name, findings);
  for (final member in element.interfaceMembers.values) {
    if (member.isPublic && !_declaredOnObject(member)) {
      _checkExecutableTypes(member, '$name.${member.displayName}', findings);
    }
  }
}

void _checkMemberTypes(
  InstanceElement element,
  String name,
  List<String> findings,
) {
  for (final field in element.fields) {
    if (field.isPublic && field.isStatic) {
      _report('$name.${field.name}', field.type, findings);
    }
  }
  for (final method in element.methods) {
    if (method.isPublic && (method.isStatic || element is ExtensionElement)) {
      _checkExecutableTypes(method, '$name.${method.name}', findings);
    }
  }
  for (final getter in element.getters) {
    if (getter.isPublic && (getter.isStatic || element is ExtensionElement)) {
      _checkExecutableTypes(getter, '$name.${getter.name}', findings);
    }
  }
}

void _checkExecutableTypes(
  ExecutableElement element,
  String symbol,
  List<String> findings,
) {
  _report(symbol, element.returnType, findings);
  for (final parameter in element.formalParameters) {
    _report(symbol, parameter.type, findings);
  }
}

/// Records [symbol] when [type] names a platform library's type.
void _report(String symbol, DartType type, List<String> findings) {
  final libraries = <String>{};
  _collectLibraries(type, libraries);
  for (final library in libraries) {
    if (platformLibraries.any(library.startsWith)) {
      findings.add('$symbol names ${_type(type)} from $library');
    }
  }
}

void _collectLibraries(DartType type, Set<String> libraries) {
  switch (type) {
    case InterfaceType():
      final uri = type.element.library.uri.toString();
      libraries.add(uri);
      for (final argument in type.typeArguments) {
        _collectLibraries(argument, libraries);
      }
    case FunctionType():
      _collectLibraries(type.returnType, libraries);
      for (final parameter in type.formalParameters) {
        _collectLibraries(parameter.type, libraries);
      }
    case RecordType():
      for (final field in type.positionalFields) {
        _collectLibraries(field.type, libraries);
      }
      for (final field in type.namedFields) {
        _collectLibraries(field.type, libraries);
      }
    default:
      break;
  }
}

/// Every task (a class with `static Future<Self> create(...)`) has `dispose`,
/// `delegate` and `query<Task>Capabilities`; every options class but the base
/// and Gesture Recognizer's nested `ClassifierOptions` extends `TaskOptions`.
void _checkConventions(
  InterfaceElement element,
  Set<String> exported,
  List<String> findings,
) {
  final name = element.name!;
  final create = element.methods
      .where((m) => m.isStatic && m.name == 'create')
      .firstOrNull;
  if (create != null && _type(create.returnType) == 'Future<$name>') {
    final members = {
      for (final member in element.interfaceMembers.values)
        if (member.isPublic) member.displayName: member,
    };
    final dispose = members['dispose'];
    if (dispose == null || _type(dispose.returnType) != 'Future<void>') {
      findings.add('$name has no Future<void> dispose()');
    }
    if (members['delegate'] is! GetterElement) {
      findings.add('$name has no delegate getter');
    }
    if (!exported.contains('query${name}Capabilities')) {
      findings.add('$name has no query${name}Capabilities()');
    }
  }
  if (element is ClassElement &&
      name.endsWith('Options') &&
      name != 'TaskOptions' &&
      name != 'ClassifierOptions' &&
      !element.allSupertypes.any((t) => t.element.name == 'TaskOptions')) {
    findings.add('$name does not extend TaskOptions');
  }
}

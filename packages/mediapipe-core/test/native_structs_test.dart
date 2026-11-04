@TestOn('vm')
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show ClassifierSettings, mpHostSystem, mpHostVersion;
import 'package:test/test.dart';

void main() {
  group('checkNativeStatus', () {
    late List<Pointer<Char>> freed;
    void errorFree(Pointer<Char> message) {
      freed.add(message);
      malloc.free(message);
    }

    /// A call that reports [status] and, unless [message] is null, a message
    /// Google's library would allocate.
    int Function(Pointer<Pointer<Char>>) reporting(
      int status,
      String? message,
    ) => (error) {
      if (message != null) error.value = message.toNativeUtf8().cast();
      return status;
    };

    setUp(() => freed = []);

    test('an OK status passes and frees a message', () {
      checkNativeStatus(reporting(0, null), errorFree);
      expect(freed, isEmpty);
      checkNativeStatus(reporting(0, 'warning'), errorFree);
      expect(freed, hasLength(1));
    });

    test("a failure throws Google's message and status, freed", () {
      expect(
        () => checkNativeStatus(reporting(3, 'bad model'), errorFree),
        throwsA(
          isA<TaskException>()
              .having((e) => e.message, 'message', 'bad model')
              .having((e) => e.statusCode, 'statusCode', 3),
        ),
      );
      expect(freed, hasLength(1));
    });

    test('a failure without a message names its status', () {
      expect(
        () => checkNativeStatus(reporting(5, null), errorFree),
        throwsA(
          isA<TaskException>().having(
            (e) => e.message,
            'message',
            contains('status 5'),
          ),
        ),
      );
      expect(freed, isEmpty);
    });

    test('an empty message stays empty', () {
      expect(
        () => checkNativeStatus(reporting(2, ''), errorFree),
        throwsA(isA<TaskException>().having((e) => e.message, 'message', '')),
      );
      expect(freed, hasLength(1));
    });

    test("failure rewrites the error, and Google's message is still freed", () {
      expect(
        () => checkNativeStatus(
          reporting(3, 'EG2 embedder'),
          errorFree,
          failure: (message, status) =>
              TaskException('$message: use another model', statusCode: status),
        ),
        throwsA(
          isA<TaskException>().having(
            (e) => e.message,
            'message',
            'EG2 embedder: use another model',
          ),
        ),
      );
      expect(
        () => checkNativeStatus(
          reporting(3, 'boom'),
          errorFree,
          failure: (message, status) => throw StateError(message),
        ),
        throwsStateError,
      );
      expect(freed, hasLength(2));
    });
  });

  test('nativeString copies, and reads empty as absent on request', () {
    expect(nativeString(nullptr), isNull);
    using((arena) {
      final empty = ''.toNativeUtf8(allocator: arena).cast<Char>();
      final text = 'hello'.toNativeUtf8(allocator: arena).cast<Char>();
      expect(nativeString(empty), '');
      expect(nativeString(empty, emptyIsNull: true), isNull);
      expect(nativeString(text, emptyIsNull: true), 'hello');
    });
  });

  test('fillBaseOptions copies bytes, or passes the path, on the CPU', () {
    using((arena) {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final fromBytes = arena<MpBaseOptions>().ref;
      fillBaseOptions(fromBytes, arena, modelBytes: bytes);
      bytes[0] = 9;
      expect(fromBytes.modelAssetBufferCount, 3);
      expect(fromBytes.modelAssetBuffer.cast<Uint8>().asTypedList(3), [
        1,
        2,
        3,
      ]);
      expect(fromBytes.modelAssetPath, nullptr);
      expect(fromBytes.fileDescriptor, -1);
      expect(fromBytes.delegate, 0);
      expect(fromBytes.hostEnvironment, 5);
      expect(fromBytes.hostSystem, mpHostSystem);
      expect(nativeString(fromBytes.hostVersion), mpHostVersion);

      final fromPath = arena<MpBaseOptions>().ref;
      fillBaseOptions(fromPath, arena, modelPath: 'models/x.task');
      expect(nativeString(fromPath.modelAssetPath), 'models/x.task');
      expect(fromPath.modelAssetBuffer, nullptr);
      expect(fromPath.modelAssetBufferCount, 0);
    });
  });

  test('mpHostVersion names the OS, Dart and Flutter like a user agent', () {
    expect(
      mpHostVersion,
      matches(r'^(macOS|iOS|Android|Linux|Windows)( [\d.]+)? / Dart \S+'),
    );
    expect(
      mpHostVersion.endsWith(
        ' / Flutter ${const String.fromEnvironment('FLUTTER_VERSION')}',
      ),
      const bool.hasEnvironment('FLUTTER_VERSION'),
    );
  });

  test('fillClassifierOptions writes every setting', () {
    using((arena) {
      final options = arena<MpClassifierOptions>().ref;
      fillClassifierOptions(options, arena, _Settings('fr', ['cat', 'dog']));
      expect(nativeString(options.displayNamesLocale), 'fr');
      expect(options.maxResults, 3);
      expect(options.scoreThreshold, closeTo(0.25, 1e-7));
      expect(options.categoryAllowlistCount, 2);
      expect(nativeString(options.categoryAllowlist[1]), 'dog');
      expect(options.categoryDenylist, nullptr);
      expect(options.categoryDenylistCount, 0);

      fillClassifierOptions(options, arena, _Settings(null, const []));
      expect(options.displayNamesLocale, nullptr);
      expect(options.categoryAllowlist, nullptr);
      expect(nativeStrings(arena, const []), nullptr);
    });
  });

  test('copyClassifications copies every head and category', () {
    using((arena) {
      final result = arena<MpClassificationResult>();
      final heads = arena<MpClassifications>(2);
      final categories = arena<MpCategory>(2);
      categories[0]
        ..index = 4
        ..score = 0.5
        ..categoryName = 'cat'.toNativeUtf8(allocator: arena).cast()
        ..displayName = ''.toNativeUtf8(allocator: arena).cast();
      categories[1]
        ..index = 7
        ..score = 0.25;
      heads[0]
        ..categories = categories
        ..categoriesCount = 2
        ..headIndex = 0
        ..headName = 'animals'.toNativeUtf8(allocator: arena).cast();
      heads[1]
        ..categories = nullptr
        ..categoriesCount = 0
        ..headIndex = 1;
      result.ref
        ..classifications = heads
        ..classificationsCount = 2;
      final copy = copyClassifications(result.ref);
      expect(copy, hasLength(2));
      expect(copy[0].headName, 'animals');
      expect(copy[0].categories, const [
        MediaPipeCategory(
          index: 4,
          score: 0.5,
          categoryName: 'cat',
          displayName: '',
        ),
        MediaPipeCategory(index: 7, score: 0.25),
      ]);
      expect(copy[1].headIndex, 1);
      expect(copy[1].headName, isNull);
      expect(copy[1].categories, isEmpty);
    });
  });
}

final class _Settings implements ClassifierSettings {
  _Settings(this.displayNamesLocale, this.categoryAllowlist);

  @override
  final String? displayNamesLocale;
  @override
  final List<String> categoryAllowlist;
  @override
  List<String> get categoryDenylist => const [];
  @override
  int get maxResults => 3;
  @override
  double get scoreThreshold => 0.25;
}

import 'dart:ffi';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/src/io/ffi_utils.dart';

void main() {
  group('NullAwarePtr should', () {
    test('be nullable', () {
      Pointer? nul;
      expect(nul, isNull);
      expect(nul.isNullPointer, false);
      expect(nul.isNotNullPointer, false);
      expect(nul.isNotNullAndIsNotNullPointer, false);
      expect(nul.isNullOrNullPointer, true);
    });
    test('detect null pointers', () {
      Pointer? nulPtr = nullptr;
      expect(nulPtr, isNotNull);
      expect(nulPtr.isNullPointer, true);
      expect(nulPtr.isNotNullPointer, false);
      expect(nulPtr.isNotNullAndIsNotNullPointer, false);
      expect(nulPtr.isNullOrNullPointer, true);
    });

    test('detect null pointers without nullability', () {
      Pointer n = nullptr;
      expect(n, isNotNull);
      expect(n.isNullPointer, true);
      expect(n.isNotNullPointer, false);
      expect(n.isNotNullAndIsNotNullPointer, false);
      expect(n.isNullOrNullPointer, true);
    });

    test('detect real pointers', () {
      Pointer? ptr = malloc<Uint8>(1);
      expect(ptr, isNotNull);
      expect(ptr.isNullPointer, false);
      expect(ptr.isNotNullPointer, true);
      expect(ptr.isNotNullAndIsNotNullPointer, true);
      expect(ptr.isNullOrNullPointer, false);
      malloc.free(ptr);
    });

    test('detect real pointers without nullability', () {
      Pointer ptr = malloc<Uint8>(1);
      expect(ptr, isNotNull);
      expect(ptr.isNullPointer, false);
      expect(ptr.isNotNullPointer, true);
      expect(ptr.isNotNullAndIsNotNullPointer, true);
      expect(ptr.isNullOrNullPointer, false);
      malloc.free(ptr);
    });
  });

  group('Strings should', () {
    test('be convertable to char*', () {
      final Pointer<Char> abc = 'abc'.copyToNative();
      calloc.free(abc);
    });

    test('be round-trippable', () {
      expect('abc'.copyToNative().toDartString(), 'abc');
    });
  });

  group('Lists of Strings should', () {
    test('be convertable to char**', () {
      final Pointer<Pointer<Char>> strings = ['abc'].copyToNative();
      calloc.free(strings);
    });

    test('be round-trippable', () {
      expect(['abc'].copyToNative().toDartStrings(1), ['abc']);
    });
  });

  group('Uint8List should', () {
    test('be convertable to Pointer<Char>', () {
      final Pointer<Char> ptr = Uint8List.fromList([1, 2, 3]).copyToNative();
      malloc.free(ptr);
    });

    test('be round-trippable', () {
      expect(
        Uint8List.fromList([1, 2, 3]).copyToNative().toUint8List(3).toList(),
        <int>[1, 2, 3],
      );
    });

    test('copy memory with toList', () {
      final ptr = Uint8List.fromList([1, 2, 3]).copyToNative();
      final List<int> ints = ptr.toUint8List(3).toList();
      calloc.free(ptr);
      expect(ints[0], 1);
      expect(ints[1], 2);
      expect(ints[2], 3);
    });
  });

  group('Float32List should', () {
    test('be convertable to Pointer<Char>', () {
      final Pointer<Float> ptr =
          Float32List.fromList([1.0, 2.0, 3.1]).copyToNative();
      malloc.free(ptr);
    });

    test('be round-trippable', () {
      final doubles = Float32List.fromList([1.1, 2.2, 3.3])
          .copyToNative()
          .toFloat32List(3)
          .toList();
      expect(doubles[0], closeTo(1.1, 0.0001));
      expect(doubles[1], closeTo(2.2, 0.0001));
      expect(doubles[2], closeTo(3.3, 0.0001));
    });
  });
}

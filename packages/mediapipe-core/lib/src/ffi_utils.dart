import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

Pointer<Pointer<Char>> prepareListOfStrings(List<String> values) {
  final ptrArray = calloc<Pointer<Char>>(values.length);
  for (var i = 0; i < values.length; i++) {
    ptrArray[i] = values[i].toNativeUtf8().cast<Char>();
  }
  return ptrArray;
}

Pointer<Char> prepareString(String val) => val.toNativeUtf8().cast<Char>();

String? toDartString(Pointer<Char> val) {
  if (val == nullptr) return null;
  return val.cast<Utf8>().toDartString();
}

List<String?> toDartStrings(Pointer<Pointer<Char>> val, int length) {
  final dartStrings = <String?>[];
  int counter = 0;
  while (counter < length) {
    dartStrings.add(toDartString(val[counter]));
    counter++;
  }
  return dartStrings;
}

Pointer<Char> prepareUint8List(Uint8List ints) {
  final Pointer<Uint8> ptr = calloc<Uint8>(ints.length);
  ptr.asTypedList(ints.length).setAll(0, ints);
  return ptr.cast();
}

Uint8List toUint8List(Pointer<Char> val, {int? length}) {
  final codeUnits = val.cast<Uint8>();
  if (length != null) {
    RangeError.checkNotNegative(length, 'length');
  } else {
    length = _length(codeUnits);
  }
  return codeUnits.asTypedList(length);
}

int _length(Pointer<Uint8> codeUnits) {
  var length = 0;
  while (codeUnits[length] != 0) {
    length++;
  }
  return length;
}

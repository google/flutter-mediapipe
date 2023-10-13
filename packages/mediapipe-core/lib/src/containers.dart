import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'mediapipe_common_bindings.dart' as bindings;

class Category {
  const Category({
    required this.index,
    required this.score,
    required this.categoryName,
    required this.displayName,
  });
  final int index;
  final double score;
  final String? categoryName;
  final String? displayName;

  static List<Category> fromStructs(
    Pointer<bindings.Category> structs,
    int count,
  ) {
    final categories = <Category>[];
    for (int i = 0; i < count; i++) {
      categories.add(fromStruct(structs[i]));
    }
    return categories;
  }

  static Category fromStruct(bindings.Category struct) {
    return Category(
      index: struct.index,
      score: struct.score,
      categoryName: toDartString(struct.category_name),
      displayName: toDartString(struct.display_name),
    );
  }

  static void freeStructs(Pointer<bindings.Category> structs, int count) {
    int index = 0;
    while (index < count) {
      bindings.Category obj = structs[index];
      calloc.free(obj.category_name);
      calloc.free(obj.display_name);
      index++;
    }
    calloc.free(structs);
  }

  @override
  String toString() => 'Category(index=$index, score=$score, '
      'categoryName=$categoryName, displayName=$displayName)';
}

class Classifications {
  const Classifications({
    required this.categories,
    required this.headIndex,
    required this.headName,
  });
  final List<Category> categories;
  final int headIndex;
  final String? headName;

  static List<Classifications> fromStructs(
    Pointer<bindings.Classifications> structs,
    int count,
  ) {
    final classifications = <Classifications>[];
    for (int i = 0; i < count; i++) {
      classifications.add(fromStruct(structs[i]));
    }
    return classifications;
  }

  static Classifications fromStruct(bindings.Classifications struct) {
    return Classifications(
      categories: Category.fromStructs(
        struct.categories,
        struct.categories_count,
      ),
      headIndex: struct.head_index,
      headName: toDartString(struct.head_name),
    );
  }

  static void freeStructs(
    Pointer<bindings.Classifications> structs,
    int count,
  ) {
    int index = 0;
    while (index < count) {
      bindings.Classifications obj = structs[index];
      Category.freeStructs(obj.categories, obj.categories_count);
      calloc.free(obj.head_name);
      index++;
    }
    calloc.free(structs);
  }

  Category? get firstCategory =>
      categories.isNotEmpty ? categories.first : null;

  @override
  String toString() {
    final categoryStrings = categories.map((cat) => cat.toString()).join(', ');
    return 'Classification(categories=[$categoryStrings], '
        'headIndex=$headIndex, headName=$headName)';
  }
}

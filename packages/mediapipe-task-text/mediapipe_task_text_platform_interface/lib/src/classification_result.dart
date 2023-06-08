class ClassificationResult {
  ClassificationResult(this.value);
  factory ClassificationResult.fromJson(Map<String, dynamic> json) =>
      ClassificationResult(json['value']);

  final String value;
}

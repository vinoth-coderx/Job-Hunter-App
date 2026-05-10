/// Mirror of `services/ai/fieldSuggester.service.ts:FieldSuggestion`.
/// One of `value`, `values`, or `numericValue` is set depending on the
/// shape of the field the AI generated for.
class AiFieldSuggestion {
  final String field;
  final String? value;
  final List<String>? values;
  final num? numericValue;

  const AiFieldSuggestion({
    required this.field,
    this.value,
    this.values,
    this.numericValue,
  });

  factory AiFieldSuggestion.fromJson(Map<String, dynamic> j) {
    final raw = j['values'];
    return AiFieldSuggestion(
      field: (j['field'] ?? '').toString(),
      value: j['value']?.toString(),
      values: raw is List ? raw.map((e) => e.toString()).toList() : null,
      numericValue: j['numericValue'] is num ? j['numericValue'] as num : null,
    );
  }

  bool get hasValue =>
      (value != null && value!.isNotEmpty) ||
      (values != null && values!.isNotEmpty) ||
      numericValue != null;
}

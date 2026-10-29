/// Represents an editable field discovered in an external Android app via AccessibilityService.
class ExternalFieldModel {
  final int index;
  final String label;
  final String hint;
  final String currentValue;
  final String shortId;

  const ExternalFieldModel({
    required this.index,
    required this.label,
    required this.hint,
    required this.currentValue,
    required this.shortId,
  });

  bool get isPopulated => currentValue.isNotEmpty;

  String get displayLabel {
    if (label.isNotEmpty) return label;
    if (hint.isNotEmpty) return hint;
    return 'Field #$index';
  }

  factory ExternalFieldModel.fromMap(int index, Map<String, dynamic> map) {
    return ExternalFieldModel(
      index: index,
      label: map['label']?.toString() ?? '',
      hint: map['hint']?.toString() ?? '',
      currentValue: map['text']?.toString() ?? '',
      shortId: map['shortId']?.toString() ?? '-',
    );
  }
}


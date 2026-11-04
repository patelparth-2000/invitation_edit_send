import 'dart:convert';

/// Result of the last render for a guest. Shown as icon + text, never colour only.
enum GuestStatus {
  notCreated('Not created'),
  created('Created'),
  failed('Failed');

  const GuestStatus(this.label);
  final String label;

  static GuestStatus parse(Object? raw) => GuestStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => GuestStatus.notCreated,
      );
}

/// One row of the mail-merge: the values typed for each field of a card.
class Guest {
  const Guest({
    this.id,
    required this.layoutId,
    required this.values,
    this.status = GuestStatus.notCreated,
    this.pdfPath,
  });

  final int? id;

  /// `row_number` of the card layout in `image_edit_table`.
  final int layoutId;

  /// One value per field, in slot order.
  final List<String> values;
  final GuestStatus status;

  /// Last PDF written for this guest (null until created).
  final String? pdfPath;

  Guest copyWith({
    int? id,
    List<String>? values,
    GuestStatus? status,
    String? Function()? pdfPath,
  }) =>
      Guest(
        id: id ?? this.id,
        layoutId: layoutId,
        values: values ?? this.values,
        status: status ?? this.status,
        pdfPath: pdfPath != null ? pdfPath() : this.pdfPath,
      );

  /// Text used to name the guest's PDF and as the row title: the first
  /// non-empty value.
  String get displayName =>
      values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');

  factory Guest.fromMap(Map<String, Object?> map) {
    final raw = map['values_json'];
    final decoded =
        raw is String && raw.isNotEmpty ? jsonDecode(raw) as List : const [];
    return Guest(
      id: map['id'] as int?,
      layoutId: (map['layout_id'] as int?) ?? 0,
      values: [for (final v in decoded) v?.toString() ?? ''],
      status: GuestStatus.parse(map['status']),
      pdfPath: map['pdf_path'] as String?,
    );
  }
}

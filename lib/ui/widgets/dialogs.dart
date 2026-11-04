import 'package:flutter/material.dart';

/// Yes/No confirmation. Resolves to false on Cancel or dismiss.
abstract final class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError)
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }
}

/// Asks for one line of text. Resolves to the trimmed text, or null on
/// Cancel / dismiss. OK is disabled while [validator] returns an error
/// (by default: while the text is empty). The controller is owned and
/// disposed by the dialog's State (F-14).
abstract final class TextPromptDialog {
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String initial = '',
    String hint = '',
    String confirmLabel = 'OK',
    String? Function(String value)? validator,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: title,
        initial: initial,
        hint: hint,
        confirmLabel: confirmLabel,
        validator: validator ?? _notEmpty,
      ),
    );
  }

  static String? _notEmpty(String v) =>
      v.trim().isEmpty ? 'Please enter some text' : null;
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.validator,
  });

  final String title;
  final String initial;
  final String hint;
  final String confirmLabel;
  final String? Function(String value) validator;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial)
        ..selection =
            TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _error => widget.validator(_controller.text);

  void _submit() {
    if (_error != null) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _touched = true),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _touched ? error : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: error == null ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

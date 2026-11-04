import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A FilledButton that disables itself while its async [onPressed] runs and
/// shows a spinner, or a determinate bar when [progress] is given (F-12).
/// [busy] lets the parent force the busy look (e.g. a long batch run).
class BusyButton extends StatefulWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busyLabel,
    this.progress,
    this.busy = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final String? busyLabel;
  final double? progress;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _running = false;

  bool get _busy => _running || widget.busy;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _running = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final Widget leading = _busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: widget.progress,
              color: onPrimary,
            ),
          )
        : (widget.icon != null ? Icon(widget.icon) : const SizedBox.shrink());
    final label = Text(_busy ? (widget.busyLabel ?? widget.label) : widget.label);
    final button = FilledButton(
      onPressed: (_busy || widget.onPressed == null) ? null : _run,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_busy || widget.icon != null) ...[
            leading,
            const SizedBox(width: AppSpacing.s),
          ],
          Flexible(child: label),
        ],
      ),
    );
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

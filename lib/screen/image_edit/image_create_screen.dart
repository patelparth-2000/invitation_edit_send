import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../models/card_layout.dart';
import '../../services/data_base_service.dart';
import '../../services/image_edit_model.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/widgets/busy_button.dart';
import '../../ui/widgets/card_canvas.dart';
import '../../ui/widgets/dialogs.dart';
import '../../ui/widgets/states.dart';
import '../../utils/common.dart';
import '../image_send/image_send_screen.dart';

/// One field while it is being edited. Position is in design coordinates
/// (the image's preview size when the layout is saved).
class _Field {
  _Field(this.text, this.topLeft, this.scale, this.color);
  String text;
  Offset topLeft;
  double scale;
  Color color;
}

/// "Design card": place, style and save the text fields of a layout.
///
/// With [existing] the saved layout is loaded and Save updates it in place
/// ("Edit layout"); otherwise Save inserts a new card.
class ImageCreateScreen extends StatefulWidget {
  const ImageCreateScreen({
    super.key,
    required this.imagePath,
    required this.imageName,
    this.existing,
    this.dbService,
  });

  final String imagePath;
  final String imageName;
  final ImageEditModel? existing;
  final DataBaseService? dbService;

  @override
  State<ImageCreateScreen> createState() => _ImageCreateScreenState();
}

class _ImageCreateScreenState extends State<ImageCreateScreen> {
  late final DataBaseService dbService =
      widget.dbService ?? DataBaseService.instance;

  static const double minScale = 0.5;
  static const double maxScale = 3.0;

  late String imagePath = widget.imagePath;
  Size? _imageSize;
  bool _loading = true;
  String? _loadError;

  /// Size of the image on screen when fields were placed. Set from the first
  /// layout of a new card, or from the stored layout when editing.
  Size? _designSize;

  final List<_Field> _fields = [];
  int? _selected;
  bool _saving = false;
  bool _bannerDismissed = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final layout = CardLayout.fromModel(existing);
      if (!layout.previewSize.isEmpty) _designSize = layout.previewSize;
      for (var i = 0; i < layout.slots.length; i++) {
        final s = layout.slots[i];
        _fields.add(_Field('Field ${i + 1}', Offset(s.renderX, s.displayY),
            s.scale, layout.colorOf(i)));
      }
      _bannerDismissed = true;
    }
    _measureImage();
  }

  /// Measures the image as Flutter displays it.
  Future<void> _measureImage() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final completer = Completer<Size>();
    final stream =
        FileImage(File(imagePath)).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(Size(
          info.image.width.toDouble(), info.image.height.toDouble()));
      stream.removeListener(listener);
    }, onError: (e, _) {
      if (!completer.isCompleted) completer.completeError(e);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    try {
      final size = await completer.future;
      if (!mounted) return;
      setState(() {
        _imageSize = size;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Could not open image: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'This image could not be opened.';
        _loading = false;
      });
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _crop() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: Theme.of(context).colorScheme.primary,
          toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
          hideBottomControls: true,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null) return;
    final stored = await persistPickedImage(cropped.path);
    if (!mounted) return;
    setState(() {
      imagePath = stored;
      // The aspect ratio changed: re-measure and re-base the design size (F-19).
      _designSize = null;
    });
    await _measureImage();
  }

  Future<void> _addField() async {
    final text = await TextPromptDialog.show(context,
        title: 'Add field',
        hint: 'Sample text, e.g. Guest name',
        confirmLabel: 'Add');
    if (text == null || !mounted) return;
    setState(() {
      _fields.add(_Field(text, const Offset(50, 50), 1.0,
          _fields.isEmpty ? AppColors.cardTextSwatches.first : _fields.last.color));
      _selected = _fields.length - 1;
    });
  }

  Future<void> _editSelectedText() async {
    final i = _selected;
    if (i == null) return;
    final text = await TextPromptDialog.show(context,
        title: 'Edit field', initial: _fields[i].text, confirmLabel: 'Save');
    if (text == null || !mounted) return;
    setState(() => _fields[i].text = text);
  }

  Future<void> _pickColour() async {
    final i = _selected;
    if (i == null) return;
    final colour = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
          child: Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.m,
            children: [
              for (final c in AppColors.cardTextSwatches)
                Semantics(
                  button: true,
                  selected: c == _fields[i].color,
                  label: _colourName(c),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context, c),
                    child: Container(
                      width: AppSpacing.minTap,
                      height: AppSpacing.minTap,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: c == _fields[i].color ? 3 : 1,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (colour == null || !mounted) return;
    setState(() => _fields[i].color = colour);
  }

  static String _colourName(Color c) {
    const names = [
      'Red', 'Maroon', 'Marigold', 'Gold', 'Navy', 'Green', 'Black', 'White'
    ];
    final i = AppColors.cardTextSwatches.indexOf(c);
    return i >= 0 ? names[i] : 'Colour';
  }

  void _deleteSelected() {
    final i = _selected;
    if (i == null) return;
    final removed = _fields[i];
    setState(() {
      _fields.removeAt(i);
      _selected = null;
    });
    _showMessage('Field deleted',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() => _fields.insert(i.clamp(0, _fields.length), removed));
          },
        ));
  }

  Future<void> _save() async {
    if (_fields.isEmpty) return; // Save is disabled, but be safe (F-13).
    final design = _designSize;
    if (design == null) {
      _showMessage('The image is not ready yet. Try again.');
      return;
    }
    setState(() {
      _saving = true;
      _selected = null;
    });
    try {
      final slots = [
        for (final f in _fields)
          TextSlot.fromEditor(f.topLeft.dx, f.topLeft.dy, f.scale,
              color: f.color.toARGB32())
      ];
      final first = _fields.first.color;
      final model = ImageEditModel(
        rowNumber: widget.existing?.rowNumber,
        deleteImage: 0,
        fontType: cardFontTypeId,
        imagePath: imagePath,
        textNumber: _fields.length.toString(),
        textCoordinate: CardLayout.encodeSlots(slots),
        textColor: CardLayout.encodeColor(
            (first.r * 255).round(), (first.g * 255).round(), (first.b * 255).round()),
        fileName: widget.existing?.fileName ?? widget.imageName,
        imageSize: CardLayout.encodeSize(design),
      );
      if (_isEdit) {
        await dbService.imageEditUpdate(model);
      } else {
        model.rowNumber = await dbService.imageEditInsert(model);
      }
      if (!mounted) return;
      if (_isEdit) {
        Navigator.of(context).pop(true);
      } else {
        // The natural next step after designing is adding guests (U-4).
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) =>
              ImageSendScreen(imageEdit: model, dbService: dbService),
        ));
      }
    } catch (e) {
      debugPrint('Saving the card failed: $e');
      _showMessage('Could not save the card: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing?.fileName ?? widget.imageName),
        actions: [
          if (!_isEdit)
            IconButton(
              tooltip: 'Crop',
              onPressed: _saving || _loading ? null : _crop,
              icon: const Icon(Icons.crop),
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s),
            child: BusyButton(
              label: 'Save',
              busyLabel: 'Saving…',
              busy: _saving,
              onPressed: _fields.isEmpty || _designSize == null ? null : _save,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_bannerDismissed && !_loading && _loadError == null)
            MaterialBanner(
              content: const Text(
                  'Tap Add field. Drag to move. Pinch or use Size to resize.'),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _bannerDismissed = true),
                  child: const Text('Got it'),
                ),
              ],
            ),
          Expanded(
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: _buildCanvas(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildToolbar(),
    );
  }

  Widget _buildCanvas() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null || _imageSize == null) {
      return ErrorState(
        message: _loadError ?? 'This image could not be opened.',
        retryLabel: 'Choose another',
        onRetry: () => Navigator.of(context).pop(),
      );
    }
    return AbsorbPointer(
      absorbing: _saving,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s),
        child: CardCanvas(
          image: FileImage(File(imagePath)),
          imageSize: _imageSize!,
          designSize: _designSize,
          imageSemanticsLabel: '${widget.imageName} invitation image',
          slots: [
            for (var i = 0; i < _fields.length; i++)
              SlotView(
                text: _fields[i].text,
                topLeft: _fields[i].topLeft,
                scale: _fields[i].scale,
                color: _fields[i].color,
                semanticsLabel: 'Field ${i + 1}, ${_fields[i].text}',
              ),
          ],
          selected: _selected,
          onLaidOut: (size) {
            if (_designSize == null) setState(() => _designSize = size);
          },
          onSelect: (i) => setState(() => _selected = i < 0 ? null : i),
          onTransform: (i, delta, factor) => setState(() {
            final f = _fields[i];
            f.topLeft += delta;
            f.scale = (f.scale * factor).clamp(minScale, maxScale);
          }),
        ),
      ),
    );
  }

  /// Bottom toolbar (plan 5.2). Grows with the text size instead of using
  /// a fixed-height BottomAppBar, and the tool row scrolls if it must.
  Widget _buildToolbar() {
    final i = _selected;
    final scheme = Theme.of(context).colorScheme;
    final Widget content;
    if (i == null || i >= _fields.length) {
      content = Align(
        heightFactor: 1,
        child: FilledButton.icon(
          onPressed:
              _saving || _loading || _loadError != null ? null : _addField,
          icon: const Icon(Icons.add),
          label: const Text('Add field'),
        ),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Text('Size'),
              ),
              Expanded(
                child: Slider(
                  min: minScale,
                  max: maxScale,
                  value: _fields[i].scale.clamp(minScale, maxScale),
                  label: _fields[i].scale.toStringAsFixed(1),
                  semanticFormatterCallback: (v) =>
                      'Size ${v.toStringAsFixed(1)}',
                  onChanged: (v) => setState(() => _fields[i].scale = v),
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ToolButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit text',
                    onPressed: _editSelectedText),
                _ToolButton(
                    icon: Icons.palette_outlined,
                    label: 'Colour',
                    onPressed: _pickColour),
                _ToolButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onPressed: _deleteSelected),
                _ToolButton(
                    icon: Icons.check,
                    label: 'Done',
                    onPressed: () => setState(() => _selected = null)),
              ],
            ),
          ),
        ],
      );
    }
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s),
          child: content,
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
}

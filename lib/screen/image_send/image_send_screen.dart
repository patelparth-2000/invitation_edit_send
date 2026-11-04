import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/card_layout.dart';
import '../../models/guest.dart';
import '../../services/data_base_service.dart';
import '../../services/image_edit_model.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/widgets/busy_button.dart';
import '../../ui/widgets/states.dart';
import '../../utils/common.dart';
import '../image_edit/image_show.dart';
import 'image_preview_screen.dart';

/// Renders one guest's card. Injectable so widget tests can run without
/// decoding images or writing files.
abstract class GuestRenderer {
  /// Prepares the background once per run.
  Future<void> begin(ImageEditModel card);

  /// Renders [guest]; returns the PNG bytes (when [png]) and the PDF path.
  Future<({Uint8List? png, String pdfPath})> render(
      CardLayout layout, Guest guest,
      {bool png = false});

  /// Releases what [begin] prepared.
  void end();
}

/// The real renderer: decodes the background once per run (P-3), renders
/// with Flutter's text engine (3.9) and writes the PDF to the app's PDF
/// folder (D-4(c)). No intermediate PNG is written to disk (P-2).
class DefaultGuestRenderer implements GuestRenderer {
  DecodedCard? _base;

  @override
  Future<void> begin(ImageEditModel card) async {
    _base ??= await decodeCard(card.imagePath);
  }

  @override
  Future<({Uint8List? png, String pdfPath})> render(
      CardLayout layout, Guest guest,
      {bool png = false}) async {
    final base = _base;
    if (base == null) throw StateError('begin() was not called');
    final out = await renderCard(
        base, layout.fieldsWith(guest.values), layout.previewSize,
        png: png, pdf: true);
    final path = await writePdf(out.pdf!, guest.displayName);
    return (png: out.png, pdfPath: path);
  }

  @override
  void end() => _base = null;
}

class ImageSendScreen extends StatefulWidget {
  const ImageSendScreen({
    super.key,
    required this.imageEdit,
    this.dbService,
    this.renderer,
  });

  final ImageEditModel imageEdit;
  final DataBaseService? dbService;
  final GuestRenderer? renderer;

  @override
  State<ImageSendScreen> createState() => _ImageSendScreenState();
}

class _ImageSendScreenState extends State<ImageSendScreen> {
  late final DataBaseService dbService =
      widget.dbService ?? DataBaseService.instance;
  late final GuestRenderer renderer = widget.renderer ?? DefaultGuestRenderer();
  late final CardLayout layout = CardLayout.fromModel(widget.imageEdit);

  /// Guests are stored in `guest_table` (F-7).
  List<Guest> guests = [];
  bool _loading = true;
  String? _loadError;

  bool _busy = false;
  bool _runningAll = false;
  bool _cancelRequested = false;
  int _done = 0;
  int _runTotal = 0;

  int? get _layoutId => widget.imageEdit.rowNumber;
  int get fieldCount => layout.slots.length;
  String get cardName => widget.imageEdit.fileName ?? 'Invitation';

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final id = _layoutId;
      final loaded = id == null ? <Guest>[] : await dbService.getGuests(id);
      if (!mounted) return;
      setState(() {
        guests = loaded;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading guests failed: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load the guest list.\n$e';
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

  bool _same(Guest a, Guest b) =>
      identical(a, b) || (a.id != null && a.id == b.id);

  void _replace(Guest old, Guest updated) {
    setState(() {
      guests = [for (final g in guests) _same(g, old) ? updated : g];
    });
  }

  Guest _current(Guest g) =>
      guests.firstWhere((x) => _same(x, g), orElse: () => g);

  Future<Guest> _persist(Guest g) async {
    if (_layoutId == null) return g;
    return dbService.saveGuest(g);
  }

  /// Renders [guest], stores its status, and returns the PNG when asked.
  Future<Uint8List?> _renderAndRecord(Guest guest, {bool png = false}) async {
    try {
      final r = await renderer.render(layout, guest, png: png);
      final updated = await _persist(guest.copyWith(
          status: GuestStatus.created, pdfPath: () => r.pdfPath));
      if (mounted) _replace(guest, updated);
      return r.png;
    } catch (e) {
      debugPrint('Render failed for ${guest.displayName}: $e');
      final failed = guest.copyWith(status: GuestStatus.failed);
      try {
        final saved = await _persist(failed);
        if (mounted) _replace(guest, saved);
      } catch (_) {
        if (mounted) _replace(guest, failed);
      }
      rethrow;
    }
  }

  Future<void> _createOne(Guest guest) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await renderer.begin(widget.imageEdit);
      final png = await _renderAndRecord(guest, png: true);
      final saved = _current(guest);
      if (!mounted || png == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageShow(
            imageBytes: png,
            pdfPath: saved.pdfPath,
            title: guest.displayName,
          ),
        ),
      );
    } catch (e) {
      _showMessage('Could not create the card for "${guest.displayName}": $e');
    } finally {
      renderer.end();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Renders [targets] one at a time. A failing guest does not stop the run
  /// (F-11); Cancel stops after the current guest.
  Future<void> _createAll([List<Guest>? targets]) async {
    final list = List<Guest>.of(targets ?? guests);
    if (_busy || list.isEmpty) return;
    setState(() {
      _busy = true;
      _runningAll = true;
      _cancelRequested = false;
      _done = 0;
      _runTotal = list.length;
    });
    var created = 0;
    var failed = 0;
    try {
      await renderer.begin(widget.imageEdit);
      for (final guest in list) {
        if (_cancelRequested || !mounted) break;
        try {
          await _renderAndRecord(_current(guest));
          created++;
        } catch (_) {
          failed++;
        }
        if (!mounted) return;
        setState(() => _done++);
      }
    } catch (e) {
      // Preparing the background failed: nothing can be created.
      _showMessage('Could not open the card image: $e');
      return;
    } finally {
      renderer.end();
      if (mounted) {
        setState(() {
          _busy = false;
          _runningAll = false;
        });
      }
    }
    if (!mounted) return;
    // Not awaited: the run is over; the button must not wait on the sheet.
    unawaited(_showSummary(
        created: created, failed: failed, cancelled: _cancelRequested));
  }

  Future<void> _showSummary(
      {required int created, required int failed, required bool cancelled}) {
    final failedGuests =
        guests.where((g) => g.status == GuestStatus.failed).toList();
    final shareable = guests.where((g) => g.pdfPath != null).toList();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                [
                  '$created created',
                  if (failed > 0) '$failed failed',
                  if (cancelled) 'stopped early',
                ].join(', '),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.l),
              if (failedGuests.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _createAll(failedGuests);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text('Retry failed (${failedGuests.length})'),
                ),
              if (shareable.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _share(shareable);
                  },
                  icon: const Icon(Icons.share),
                  label: Text('Share all (${shareable.length})'),
                ),
              ],
              const SizedBox(height: AppSpacing.s),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// R1: share PDFs through the system share sheet (WhatsApp, email, ...).
  Future<void> _share(List<Guest> list) async {
    final files = [
      for (final g in list)
        if (g.pdfPath != null && File(g.pdfPath!).existsSync())
          XFile(g.pdfPath!, mimeType: 'application/pdf'),
    ];
    if (files.isEmpty) {
      _showMessage('Create the PDFs first.');
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(files: files));
    } catch (e) {
      _showMessage('Could not share: $e');
    }
  }

  Future<void> _openGuestSheet({Guest? guest}) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GuestSheet(
        fieldCount: fieldCount,
        initial: guest?.values,
        onSaveAndAddAnother: guest == null ? _insertGuest : null,
      ),
    );
    if (result == null || !mounted) return;
    if (guest == null) {
      await _insertGuest(result);
      return;
    }
    // Editing works on a copy; Cancel never reaches here (F-8).
    final updated = _current(guest)
        .copyWith(values: result, status: GuestStatus.notCreated);
    try {
      final saved = await _persist(updated);
      if (mounted) _replace(guest, saved);
    } catch (e) {
      _showMessage('Could not save the change: $e');
    }
  }

  Future<void> _insertGuest(List<String> values) async {
    var guest = Guest(layoutId: _layoutId ?? 0, values: values);
    try {
      guest = await _persist(guest);
    } catch (e) {
      _showMessage('Guest added, but could not be saved: $e');
    }
    if (!mounted) return;
    setState(() => guests = [...guests, guest]);
  }

  Future<void> _deleteGuest(Guest guest) async {
    final index = guests.indexWhere((g) => _same(g, guest));
    setState(() => guests = guests.where((g) => !_same(g, guest)).toList());
    if (guest.id != null) {
      try {
        await dbService.deleteGuest(guest.id!);
      } catch (e) {
        if (mounted) {
          setState(() => guests = [...guests]..insert(index, guest));
        }
        _showMessage('Could not remove the guest: $e');
        return;
      }
    }
    _showMessage(
      'Removed "${guest.displayName}"',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          final restored = await _persist(Guest(
              layoutId: guest.layoutId,
              values: guest.values,
              status: guest.status,
              pdfPath: guest.pdfPath));
          if (!mounted) return;
          setState(() => guests = [...guests]
            ..insert(index.clamp(0, guests.length), restored));
        },
      ),
    );
  }

  void _openPreview({List<String>? values}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            ImagePreviewScreen(imageEdit: widget.imageEdit, values: values),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = !_busy && fieldCount > 0 && !_loading;
    return Scaffold(
      appBar: AppBar(title: Text(cardName)),
      floatingActionButton: guests.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add-guest',
              onPressed: canAdd ? () => _openGuestSheet() : null,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add guest'),
            ),
      bottomNavigationBar: guests.isEmpty ? null : _buildBottomBar(),
      body: Column(
        children: [
          _Header(
            card: widget.imageEdit,
            fieldCount: fieldCount,
            onPreview: () => _openPreview(),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.l, AppSpacing.s, AppSpacing.l, AppSpacing.m),
        child: _runningAll
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Created $_done of $_runTotal'),
                        const SizedBox(height: AppSpacing.s),
                        LinearProgressIndicator(
                          value: _runTotal == 0 ? null : _done / _runTotal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  TextButton(
                    onPressed: _cancelRequested
                        ? null
                        : () => setState(() => _cancelRequested = true),
                    child: Text(_cancelRequested ? 'Stopping…' : 'Cancel'),
                  ),
                ],
              )
            : BusyButton(
                expand: true,
                icon: Icons.picture_as_pdf_outlined,
                label: 'Create all (${guests.length})',
                busy: _busy,
                onPressed: _busy ? null : () => _createAll(),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ErrorState(message: _loadError!, onRetry: _loadGuests);
    }
    if (fieldCount == 0) {
      return const EmptyState(
        icon: Icons.text_fields,
        title: 'This card has no fields',
        message: 'Edit the layout and add at least one text field.',
      );
    }
    if (guests.isEmpty) {
      return EmptyState(
        icon: Icons.group_add_outlined,
        title: 'No guests yet',
        message:
            'Add guests one by one. Each guest gets their own card and PDF.',
        actionLabel: 'Add guest',
        onAction: () => _openGuestSheet(),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, AppSpacing.m, AppSpacing.l, 96),
      itemCount: guests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
      itemBuilder: (context, index) {
        final guest = guests[index];
        final rest = guest.values.skip(1).where((v) => v.isNotEmpty);
        return Card(
          child: ListTile(
            onTap: _busy ? null : () => _openGuestSheet(guest: guest),
            leading: _StatusBadge(status: guest.status),
            title: Text(guest.displayName.isEmpty ? '—' : guest.displayName),
            subtitle: rest.isEmpty ? null : Text(rest.join(' · ')),
            trailing: PopupMenuButton<String>(
              tooltip: 'More options',
              enabled: !_busy,
              onSelected: (v) {
                switch (v) {
                  case 'preview':
                    _openPreview(values: guest.values);
                  case 'create':
                    _createOne(guest);
                  case 'share':
                    _share([guest]);
                  case 'edit':
                    _openGuestSheet(guest: guest);
                  case 'delete':
                    _deleteGuest(guest);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'preview', child: Text('Preview')),
                const PopupMenuItem(value: 'create', child: Text('Create now')),
                if (guest.pdfPath != null)
                  const PopupMenuItem(value: 'share', child: Text('Share PDF')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.card, required this.fieldCount, required this.onPreview});
  final ImageEditModel card;
  final int fieldCount;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Image.file(
            File(card.imagePath ?? ''),
            fit: BoxFit.cover,
            cacheWidth: 168,
            semanticLabel: '${card.fileName ?? 'Invitation'} invitation image',
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
      title: Text('$fieldCount field${fieldCount == 1 ? '' : 's'}'),
      trailing: TextButton(onPressed: onPreview, child: const Text('Preview')),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final GuestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (status) {
      GuestStatus.created => (Icons.check_circle, AppColors.success),
      GuestStatus.failed => (Icons.error, scheme.error),
      GuestStatus.notCreated => (Icons.radio_button_unchecked, scheme.outline),
    };
    // Icon + text: status is never colour-only.
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color, size: 20)),
          Text(status.label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Add/edit form. Works on its own controllers; nothing changes until Save
/// (F-8). Field 1 is required. Pops with the values, or null on dismiss.
class _GuestSheet extends StatefulWidget {
  const _GuestSheet({
    required this.fieldCount,
    this.initial,
    this.onSaveAndAddAnother,
  });

  final int fieldCount;
  final List<String>? initial;
  final Future<void> Function(List<String> values)? onSaveAndAddAnother;

  @override
  State<_GuestSheet> createState() => _GuestSheetState();
}

class _GuestSheetState extends State<_GuestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = List.generate(
    widget.fieldCount,
    (i) => TextEditingController(
        text: (widget.initial != null && i < widget.initial!.length)
            ? widget.initial![i]
            : ''),
  );
  late final List<FocusNode> _focus =
      List.generate(widget.fieldCount, (_) => FocusNode());
  int _addedHere = 0;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  List<String> get _values => [for (final c in _controllers) c.text.trim()];

  Future<void> _saveAndAddAnother() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSaveAndAddAnother!(_values);
    if (!mounted) return;
    setState(() => _addedHere++);
    for (final c in _controllers) {
      c.clear();
    }
    _focus.first.requestFocus();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_values);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final addAnother = widget.onSaveAndAddAnother != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.l,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEdit ? 'Edit guest' : 'Add guest',
                  style: Theme.of(context).textTheme.titleLarge),
              if (_addedHere > 0)
                Text('$_addedHere added',
                    style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.l),
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focus[i],
                    autofocus: i == 0,
                    textInputAction: i == _controllers.length - 1
                        ? TextInputAction.done
                        : TextInputAction.next,
                    decoration: InputDecoration(labelText: 'Field ${i + 1}'),
                    validator: i == 0
                        ? (v) => (v == null || v.trim().isEmpty)
                            ? 'Field 1 is required'
                            : null
                        : null,
                  ),
                ),
              const SizedBox(height: AppSpacing.s),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.m,
                runSpacing: AppSpacing.s,
                children: [
                  if (addAnother)
                    OutlinedButton(
                      onPressed: _saveAndAddAnother,
                      child: const Text('Save and add another'),
                    ),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

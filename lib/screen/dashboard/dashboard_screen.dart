import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/card_layout.dart';
import '../../services/data_base_service.dart';
import '../../services/image_edit_model.dart';
import '../../services/permission_manager.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/widgets/card_tile.dart';
import '../../ui/widgets/dialogs.dart';
import '../../ui/widgets/states.dart';
import '../../utils/common.dart';
import '../image_edit/image_create_screen.dart';
import '../image_send/image_send_screen.dart';

/// "My invitations" (plan 5.3): saved layouts as a grid.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.dbService});

  /// Injectable for tests; defaults to the app-wide instance (task 1.1).
  final DataBaseService? dbService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DataBaseService dbService =
      widget.dbService ?? DataBaseService.instance;

  List<ImageEditModel> cards = [];
  Map<int, int> _guestCounts = const {};
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final all = await dbService.getAllImageEdits();
      Map<int, int> counts = const {};
      try {
        counts = await dbService.guestCounts();
      } catch (e) {
        debugPrint('Guest counts failed: $e');
      }
      final visible = all.where((e) => e.deleteImage != 1).toList()
        ..sort((a, b) => (b.updateDate ?? '').compareTo(a.updateDate ?? ''));
      if (!mounted) return;
      setState(() {
        cards = visible;
        _guestCounts = counts;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading cards failed: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load your invitations.\n$e';
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

  Future<void> _rename(ImageEditModel card) async {
    final name = await TextPromptDialog.show(context,
        title: 'Rename invitation',
        initial: card.fileName ?? '',
        hint: 'Invitation name',
        confirmLabel: 'Rename');
    // Cancel keeps the old name (F-15).
    if (name == null || name == card.fileName) return;
    try {
      await dbService.imageEditUpdate(
          ImageEditModel(rowNumber: card.rowNumber, fileName: name));
      await _reload();
    } catch (e) {
      _showMessage('Could not rename: $e');
    }
  }

  Future<void> _delete(ImageEditModel card) async {
    final ok = await ConfirmDialog.show(context,
        title: 'Delete invitation?',
        message: 'Remove "${card.fileName ?? 'this invitation'}" from your '
            'list? PDFs already created are kept.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await dbService.imageEditUpdate(
          ImageEditModel(rowNumber: card.rowNumber, deleteImage: 1));
      await _reload();
      _showMessage(
        'Invitation deleted',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await dbService.imageEditUpdate(
                ImageEditModel(rowNumber: card.rowNumber, deleteImage: 0));
            await _reload();
          },
        ),
      );
    } catch (e) {
      _showMessage('Could not delete: $e');
    }
  }

  Future<void> _openGuests(ImageEditModel card) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageSendScreen(imageEdit: card, dbService: dbService),
      ),
    );
    await _reload();
  }

  Future<void> _editLayout(ImageEditModel card) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageCreateScreen(
          imagePath: card.imagePath ?? '',
          imageName: card.fileName ?? 'Invitation',
          existing: card,
          dbService: dbService,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _newInvitation() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _pick(ImageSource source) async {
    // The gallery uses the system photo picker and needs no permission
    // (X-2); the camera does, because CAMERA is declared.
    if (source == ImageSource.camera) {
      final status = await PermissionManager.requestCameraPermission();
      if (!status.isGranted) {
        _showPermissionDialog(permanently: status.isPermanentlyDenied);
        return;
      }
    }
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source);
    } catch (e) {
      _showMessage('Could not open the ${source.name}: $e');
      return;
    }
    if (picked == null || !mounted) return;

    final name = await TextPromptDialog.show(context,
        title: 'Name this invitation',
        initial: 'Invitation',
        hint: 'e.g. Navchandi puja',
        confirmLabel: 'Next');
    if (name == null || !mounted) return;

    // Keep our own copy: image_picker's file lives in the cache (F-2).
    final String stored;
    try {
      stored = await persistPickedImage(picked.path);
    } catch (e) {
      _showMessage('Could not store the image: $e');
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageCreateScreen(
          imagePath: stored,
          imageName: name,
          dbService: dbService,
        ),
      ),
    );
    await _reload(); // F-16
  }

  void _showPermissionDialog({required bool permanently}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera access needed'),
        content: Text(permanently
            ? 'Camera access is turned off for this app. Allow it in the app '
                'settings, or choose a picture from the gallery instead.'
            : 'Allow camera access to take a photo, or choose a picture from '
                'the gallery instead.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          if (permanently)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                PermissionManager.openSettings();
              },
              child: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _loading || cards.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'new-invitation',
              onPressed: _newInvitation,
              icon: const Icon(Icons.add),
              label: const Text('New invitation'),
            ),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.medium(title: Text('My invitations')),
          ..._content(context),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    if (_loading) {
      return const [
        SliverFillRemaining(
            child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (_loadError != null) {
      return [
        SliverFillRemaining(
            child: ErrorState(message: _loadError!, onRetry: _reload)),
      ];
    }
    if (cards.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.mail_outline,
            title: 'No invitations yet',
            message: 'Start from a photo of your invitation card.',
            actionLabel: 'New invitation',
            onAction: _newInvitation,
          ),
        ),
      ];
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.l, 0, AppSpacing.l, 96),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            childAspectRatio: 0.72,
            mainAxisSpacing: AppSpacing.m,
            crossAxisSpacing: AppSpacing.m,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            final fields = CardLayout.decodeSlots(card.textCoordinate).length;
            final guestCount = _guestCounts[card.rowNumber] ?? 0;
            return CardTile(
              title: card.fileName ?? 'Invitation',
              subtitle: '$fields field${fields == 1 ? '' : 's'} · '
                  '$guestCount guest${guestCount == 1 ? '' : 's'}',
              // Decode at tile size, not camera resolution (P-4).
              thumb: ResizeImage(FileImage(File(card.imagePath ?? '')),
                  width: (240 * dpr).round(), policy: ResizeImagePolicy.fit),
              onTap: () => _openGuests(card),
              menu: const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'layout', child: Text('Edit layout')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onMenuSelected: (v) {
                switch (v) {
                  case 'rename':
                    _rename(card);
                  case 'layout':
                    _editLayout(card);
                  case 'delete':
                    _delete(card);
                }
              },
            );
          },
        ),
      ),
    ];
  }
}

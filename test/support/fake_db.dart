import 'package:invitation_edit_send/models/guest.dart';
import 'package:invitation_edit_send/services/data_base_service.dart';
import 'package:invitation_edit_send/services/image_edit_model.dart';

/// In-memory stand-in for [DataBaseService] for widget tests.
class FakeDb extends DataBaseService {
  FakeDb({List<ImageEditModel>? cards, List<Guest>? guests, this.failLoad = false})
      : cards = [...?cards],
        guests = [...?guests],
        super.fake();

  final List<ImageEditModel> cards;
  final List<Guest> guests;
  final List<ImageEditModel> updates = [];
  final List<ImageEditModel> inserts = [];
  bool failLoad;
  int _nextId = 100;

  @override
  Future<List<ImageEditModel>> getAllImageEdits() async {
    if (failLoad) throw StateError('disk on fire');
    return List.of(cards);
  }

  @override
  Future<int> imageEditInsert(ImageEditModel imageEdit) async {
    inserts.add(imageEdit);
    final id = _nextId++;
    cards.add(imageEdit..rowNumber = id);
    return id;
  }

  @override
  Future<void> imageEditUpdate(ImageEditModel imageEdit) async {
    updates.add(imageEdit);
    final i = cards.indexWhere((c) => c.rowNumber == imageEdit.rowNumber);
    if (i < 0) return;
    final c = cards[i];
    if (imageEdit.fileName != null) c.fileName = imageEdit.fileName;
    if (imageEdit.deleteImage != null) c.deleteImage = imageEdit.deleteImage;
    if (imageEdit.textCoordinate != null) {
      c.textCoordinate = imageEdit.textCoordinate;
    }
  }

  @override
  Future<Map<int, int>> guestCounts() async {
    final m = <int, int>{};
    for (final g in guests) {
      m[g.layoutId] = (m[g.layoutId] ?? 0) + 1;
    }
    return m;
  }

  @override
  Future<List<Guest>> getGuests(int layoutId) async =>
      guests.where((g) => g.layoutId == layoutId).toList();

  @override
  Future<Guest> saveGuest(Guest guest) async {
    if (guest.id == null) {
      final saved = guest.copyWith(id: _nextId++);
      guests.add(saved);
      return saved;
    }
    final i = guests.indexWhere((g) => g.id == guest.id);
    if (i >= 0) guests[i] = guest;
    return guest;
  }

  @override
  Future<void> deleteGuest(int id) async =>
      guests.removeWhere((g) => g.id == id);
}

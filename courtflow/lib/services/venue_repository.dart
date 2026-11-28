import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/court_model.dart';
import '../models/slot_model.dart';
import '../models/venue_model.dart';
import 'firestore_paths.dart';

/// Firestore reads for venues, courts and slots.
class VenueRepository {
  VenueRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Venue>> watchDirectory() {
    return FirestorePaths.venues(_db)
        .where('publicDirectoryVisible', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final venues = <Venue>[];
      for (final doc in snapshot.docs) {
        venues.add(await _withCourts(doc));
      }
      venues.sort((a, b) => a.name.compareTo(b.name));
      return venues;
    });
  }

  Stream<Venue?> watchVenue(String facilityId) {
    return FirestorePaths.venue(_db, facilityId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      return _withCourts(doc);
    });
  }

  Stream<List<Court>> watchCourts(String facilityId) {
    return FirestorePaths.courts(_db, facilityId).snapshots().map((snapshot) {
      return [
        for (final doc in snapshot.docs)
          if (doc.data()['isActive'] as bool? ?? true)
            Court.fromMap(doc.id, doc.data()),
      ];
    });
  }

  /// Slots without a document are available per the data model, so missing
  /// hours are synthesized between the venue's opening and closing hours.
  Stream<List<Slot>> watchDaySlots({
    required String facilityId,
    required String courtId,
    required String date,
    required int openHour,
    required int closeHour,
  }) {
    return FirestorePaths.slots(_db, facilityId, courtId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
      final byHour = <int, Slot>{};
      for (final doc in snapshot.docs) {
        final slot = Slot.fromMap(facilityId, courtId, doc.id, doc.data());
        byHour[slot.startHour] = slot;
      }
      return [
        for (var hour = openHour; hour < closeHour; hour++)
          byHour[hour] ??
              Slot(
                facilityId: facilityId,
                courtId: courtId,
                date: date,
                startHour: hour,
              ),
      ];
    });
  }

  Future<Venue> _withCourts(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final courtsSnapshot = await doc.reference.collection('courts').get();
    final courts = [
      for (final court in courtsSnapshot.docs)
        if (court.data()['isActive'] as bool? ?? true)
          Court.fromMap(court.id, court.data()),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return Venue.fromMap(doc.id, doc.data() ?? const {}, courts: courts);
  }
}

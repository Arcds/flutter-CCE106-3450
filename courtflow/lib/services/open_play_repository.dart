import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/open_play_model.dart';
import 'firestore_paths.dart';

class OpenPlayRepository {
  OpenPlayRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<OpenPlaySession>> watchAllSessions() {
    return _db
        .collectionGroup('openPlaySessions')
        .orderBy('date')
        .snapshots()
        .map(_mapDocs);
  }

  Stream<List<OpenPlaySession>> watchFacilitySessions(String facilityId) {
    return FirestorePaths.openPlaySessions(_db, facilityId)
        .orderBy('date')
        .snapshots()
        .map(_mapDocs);
  }

  List<OpenPlaySession> _mapDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final sessions = [
      for (final doc in snapshot.docs)
        OpenPlaySession.fromMap(doc.id, doc.data()),
    ];
    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }
}

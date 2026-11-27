import 'package:flutter_test/flutter_test.dart';
import 'package:muxis/core/sync/sync_models.dart';

void main() {
  group('Sync Models & Serialization Tests', () {
    test('SyncMutation correctly serializes to and from Map', () {
      final now = DateTime.now();
      final mutation = SyncMutation(
        id: 'mut-123',
        entityType: SyncEntityType.playlist,
        action: MutationAction.upsert,
        data: {'title': 'Night Drive', 'is_deleted': false},
        timestamp: now,
      );

      final map = mutation.toMap();
      expect(map['id'], equals('mut-123'));
      expect(map['entityType'], equals('playlist'));
      expect(map['action'], equals('upsert'));
      expect(map['data']['title'], equals('Night Drive'));

      final restored = SyncMutation.fromMap(map);
      expect(restored.id, equals(mutation.id));
      expect(restored.entityType, equals(SyncEntityType.playlist));
      expect(restored.action, equals(MutationAction.upsert));
      expect(restored.data['title'], equals('Night Drive'));
    });

    test('SyncReport correctly reports sync metrics and success state', () {
      final report = SyncReport(
        syncTime: DateTime.now(),
        playlistsSynced: 5,
        favoritesSynced: 42,
        tracksSynced: 88,
        isSuccess: true,
      );

      expect(report.playlistsSynced, equals(5));
      expect(report.favoritesSynced, equals(42));
      expect(report.tracksSynced, equals(88));
      expect(report.isSuccess, isTrue);
      expect(report.errorMessage, isNull);
    });

    test('SyncReport handles failure states cleanly', () {
      final failReport = SyncReport(
        syncTime: DateTime.now(),
        isSuccess: false,
        errorMessage: 'Network timeout during push',
      );

      expect(failReport.isSuccess, isFalse);
      expect(failReport.errorMessage, contains('timeout'));
    });
  });

  group('Portable URI Formatting Logic', () {
    String generatePortableUri(String id, String title, String artist) {
      if (id.startsWith('isrc:') ||
          id.startsWith('yt:') ||
          id.startsWith('cc:') ||
          id.startsWith('public:')) {
        return id;
      }
      final clean =
          '${artist.toLowerCase().trim()}_${title.toLowerCase().trim()}'
              .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      return 'meta:$clean';
    }

    test('Converts local filesystem track IDs to portable meta format', () {
      final uri = generatePortableUri(
        r'C:\Users\John\Music\Starlight.flac',
        'Starlight',
        'Muse',
      );
      expect(uri, equals('meta:muse_starlight'));
      expect(uri, isNot(contains('C:')));
      expect(uri, isNot(contains(r'\')));
    });

    test('Preserves pre-existing public and ISRC stream identifiers', () {
      expect(
        generatePortableUri('isrc:USUM71204928', 'Song', 'Artist'),
        equals('isrc:USUM71204928'),
      );
      expect(
        generatePortableUri('public:cc-license-01', 'Bach', 'Performer'),
        equals('public:cc-license-01'),
      );
      expect(
        generatePortableUri(
          'yt:dQw4w9WgXcQ',
          'Never Gonna Give You Up',
          'Rick Astley',
        ),
        equals('yt:dQw4w9WgXcQ'),
      );
    });
  });
}

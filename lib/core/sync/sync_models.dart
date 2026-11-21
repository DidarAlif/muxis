enum SyncStatus { idle, syncing, synced, offline, error }

enum SyncEntityType { playlist, playlistTrack, favorite, userSettings }

enum MutationAction { upsert, delete }

class SyncMutation {
  final String id;
  final SyncEntityType entityType;
  final MutationAction action;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const SyncMutation({
    required this.id,
    required this.entityType,
    required this.action,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityType': entityType.name,
      'action': action.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SyncMutation.fromMap(Map<String, dynamic> map) {
    return SyncMutation(
      id: map['id'] as String,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == map['entityType'],
      ),
      action: MutationAction.values.firstWhere((e) => e.name == map['action']),
      data: Map<String, dynamic>.from(map['data'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

class SyncReport {
  final DateTime syncTime;
  final int playlistsSynced;
  final int favoritesSynced;
  final int tracksSynced;
  final bool isSuccess;
  final String? errorMessage;

  const SyncReport({
    required this.syncTime,
    this.playlistsSynced = 0,
    this.favoritesSynced = 0,
    this.tracksSynced = 0,
    this.isSuccess = true,
    this.errorMessage,
  });
}

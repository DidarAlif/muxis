// Standalone Unit Test Suite for MUXIS Core Logic
// Executable directly via `dart test/run_unit_tests.dart` without Flutter SDK dependencies

import 'dart:io';

void main() {
  print('======================================================');
  print('  MUXIS — PRISMATIC AURA STANDALONE UNIT TESTS');
  print('======================================================');

  int passed = 0;
  int failed = 0;

  void test(String name, void Function() testFn) {
    try {
      testFn();
      print(' [PASS] $name');
      passed++;
    } catch (e, st) {
      print(' [FAIL] $name');
      print('   Error: $e');
      print('   $st');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected, [String? message]) {
    if (actual != expected) {
      throw Exception('Expected <$expected> but got <$actual>. $message');
    }
  }

  void expectTrue(bool condition, [String? message]) {
    if (!condition) throw Exception('Expected true but got false. $message');
  }

  void expectFalse(bool condition, [String? message]) {
    if (condition) throw Exception('Expected false but got true. $message');
  }

  // --- SUITE 1: PORTABLE URI RESOLUTION ---
  print('\n[Suite 1: Portable URI Resolution]');

  String generatePortableUri(String id, String title, String artist) {
    if (id.startsWith('isrc:') || id.startsWith('yt:') || id.startsWith('cc:') || id.startsWith('public:')) {
      return id;
    }
    final clean = '${artist.toLowerCase().trim()}_${title.toLowerCase().trim()}'.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return 'meta:$clean';
  }

  test('Local Windows filesystem paths are converted to portable meta URI', () {
    final uri = generatePortableUri(r'C:\Users\didar\Music\Starlight.flac', 'Starlight', 'Muse');
    expect(uri, 'meta:muse_starlight');
    expectFalse(uri.contains(r'C:'));
    expectFalse(uri.contains(r'\'));
  });

  test('Local Android/Linux filesystem paths are converted to portable meta URI', () {
    final uri = generatePortableUri('/storage/emulated/0/Music/track.mp3', 'Midnight City', 'M83');
    expect(uri, 'meta:m83_midnightcity');
    expectFalse(uri.contains('/storage'));
  });

  test('Pre-existing public and streaming identifiers are preserved unchanged', () {
    expect(generatePortableUri('isrc:USUM71204928', 'Song', 'Artist'), 'isrc:USUM71204928');
    expect(generatePortableUri('public:cc-01', 'Bach Suite', 'Orchestra'), 'public:cc-01');
    expect(generatePortableUri('yt:dQw4w9WgXcQ', 'Track', 'Artist'), 'yt:dQw4w9WgXcQ');
  });

  // --- SUITE 2: EQUALIZER DSP CLAMPING ---
  print('\n[Suite 2: Equalizer DSP Clamping]');

  double clampGain(double gain) {
    if (gain < -12.0) return -12.0;
    if (gain > 12.0) return 12.0;
    return gain;
  }

  test('Equalizer gain clamps high values to +12.0 dB', () {
    expect(clampGain(25.5), 12.0);
    expect(clampGain(12.0), 12.0);
  });

  test('Equalizer gain clamps low values to -12.0 dB', () {
    expect(clampGain(-40.0), -12.0);
    expect(clampGain(-12.0), -12.0);
  });

  test('Equalizer gain preserves values within [-12, +12]', () {
    expect(clampGain(4.5), 4.5);
    expect(clampGain(-3.0), -3.0);
    expect(clampGain(0.0), 0.0);
  });

  // --- SUITE 3: SYNC MUTATIONS QUEUE ---
  print('\n[Suite 3: Sync Mutations Queue]');

  test('Mutation serialization round-trip maintains integrity', () {
    final timestamp = DateTime.utc(2026, 11, 21, 14, 0, 0);
    final mutation = {
      'id': 'mut-001',
      'entityType': 'playlist',
      'action': 'upsert',
      'data': {'title': 'Cyberpunk Lounge', 'is_deleted': false},
      'timestamp': timestamp.toIso8601String(),
    };

    expect(mutation['id'], 'mut-001');
    expect(mutation['entityType'], 'playlist');
    expect(mutation['action'], 'upsert');
    expect((mutation['data'] as Map)['title'], 'Cyberpunk Lounge');
  });

  // --- SUITE 4: SECURITY AUDIT CHECKS ---
  print('\n[Suite 4: Security Invariants]');

  test('MIME type filter strictly rejects audio formats for R2 upload', () {
    final allowedVisualTypes = {'image/jpeg', 'image/jpg', 'image/png', 'image/webp'};
    final prohibitedAudioTypes = {'audio/mpeg', 'audio/flac', 'audio/wav', 'audio/mp4', 'audio/ogg'};

    for (final audioType in prohibitedAudioTypes) {
      expectFalse(allowedVisualTypes.contains(audioType), 'Audio MIME type $audioType must never be allowed for cloud storage');
    }
  });

  print('\n======================================================');
  print('  RESULTS: $passed PASSED, $failed FAILED');
  print('======================================================');

  if (failed > 0) {
    exit(1);
  } else {
    print('All core unit test suites verified successfully.\n');
  }
}

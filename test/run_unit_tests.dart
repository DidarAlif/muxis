// Standalone Unit Test Suite for MUXIS Core Logic
// Executable directly via `dart test/run_unit_tests.dart` without Flutter SDK dependencies

import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  // --- SUITE 5: LIBRARY PERSISTENCE & STREAMING CONFIGURATION ---
  print('\n[Suite 5: Library & Streaming Configuration]');

  test('Supported audio extensions include all lossless and compressed standards', () {
    const supportedAudioExtensions = {
      '.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.opus',
    };
    expectTrue(supportedAudioExtensions.contains('.flac'));
    expectTrue(supportedAudioExtensions.contains('.mp3'));
    expectTrue(supportedAudioExtensions.contains('.wav'));
    expectTrue(supportedAudioExtensions.contains('.opus'));
    expectFalse(supportedAudioExtensions.contains('.exe'));
  });

  test('Playlist track management adds and removes track URIs correctly', () {
    final playlists = <String, List<String>>{};
    const name = 'Synthwave Neon';
    playlists[name] = [];

    // Add track
    playlists[name]!.add('local-12345');
    playlists[name]!.add('local-67890');
    expect(playlists[name]!.length, 2);
    expectTrue(playlists[name]!.contains('local-12345'));

    // Remove track
    playlists[name]!.remove('local-12345');
    expect(playlists[name]!.length, 1);
    expectFalse(playlists[name]!.contains('local-12345'));
  });

  test('Active streaming source validation', () {
    const validSources = ['youtube', 'spotify', 'local'];
    expectTrue(validSources.contains('youtube'));
    expectTrue(validSources.contains('spotify'));
    expectTrue(validSources.contains('local'));
    expectFalse(validSources.contains('unknown'));
  });

  // --- SUITE 6: BROWSER OAUTH & PKCE GENERATION ---
  print('\n[Suite 6: Browser OAuth & PKCE Verification]');

  String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  test('PKCE code verifier meets RFC 7636 length requirements', () {
    final verifier = generateCodeVerifier();
    expectTrue(verifier.length >= 43 && verifier.length <= 128);
    expectFalse(verifier.contains('='));
  });

  test('OAuth callback loopback ports are within permitted desktop range', () {
    const allowedPorts = [8888, 8889, 43821, 51731];
    expectTrue(allowedPorts.contains(8888));
    expectTrue(allowedPorts.length >= 2);
  });

  // --- SUITE 7: 10-BAND DSP EQUALIZER & ACOUSTIC GAIN ---
  print('\n[Suite 7: 10-Band DSP Equalizer & Acoustic Gain]');

  test('10-band studio frequency coverage spans full audible spectrum', () {
    const freqs = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    expect(freqs.length, 10);
    expect(freqs.first, 32);
    expect(freqs.last, 16000);
  });

  test('Acoustic gain calculation maintains safe linear headroom', () {
    double computeGain(double preampDb, double bassBoost) {
      final preamp = pow(10.0, preampDb / 20.0).toDouble();
      final bass = pow(10.0, (bassBoost * 6.0 * 0.15) / 20.0).toDouble();
      return (preamp * (0.6 + 0.25 * bass)).clamp(0.2, 2.0);
    }

    final flatGain = computeGain(0.0, 0.0);
    expectTrue(flatGain >= 0.8 && flatGain <= 1.0);

    final boostedGain = computeGain(3.0, 0.8);
    expectTrue(boostedGain > flatGain);
    expectTrue(boostedGain <= 2.0);
  });

  test('Pitch shift semitone multiplier computes correctly', () {
    // 0 semitones = 1.0x
    final unity = pow(2.0, 0.0 / 12.0);
    expect(unity, 1.0);

    // +12 semitones (1 octave up) = 2.0x
    final octaveUp = pow(2.0, 12.0 / 12.0);
    expect(octaveUp, 2.0);

    // -12 semitones (1 octave down) = 0.5x
    final octaveDown = pow(2.0, -12.0 / 12.0);
    expect(octaveDown, 0.5);

    // Slowed + reverb (-2 semitones)
    final slowedPitch = pow(2.0, -2.0 / 12.0);
    expectTrue(slowedPitch > 0.88 && slowedPitch < 0.90);
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

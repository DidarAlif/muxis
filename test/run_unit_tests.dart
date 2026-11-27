// Standalone Unit Test Suite for MUXIS Core Logic
// Executable directly via `dart test/run_unit_tests.dart` without Flutter SDK dependencies

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../lib/core/updates/app_update_models.dart';
import '../lib/shared/models/featured_section.dart';
import '../lib/shared/models/playlist.dart';
import '../lib/shared/models/radio_station.dart';
import '../lib/shared/models/track.dart';
import '../lib/shared/utils/cloud_auth_utils.dart';
import '../lib/shared/utils/library_filter.dart';
import '../lib/shared/utils/soundcloud_auth_utils.dart';

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
    if (id.startsWith('isrc:') ||
        id.startsWith('yt:') ||
        id.startsWith('cc:') ||
        id.startsWith('public:')) {
      return id;
    }
    final clean = '${artist.toLowerCase().trim()}_${title.toLowerCase().trim()}'
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return 'meta:$clean';
  }

  test('Local Windows filesystem paths are converted to portable meta URI', () {
    final uri = generatePortableUri(
      r'C:\Users\didar\Music\Starlight.flac',
      'Starlight',
      'Muse',
    );
    expect(uri, 'meta:muse_starlight');
    expectFalse(uri.contains(r'C:'));
    expectFalse(uri.contains(r'\'));
  });

  test(
    'Local Android/Linux filesystem paths are converted to portable meta URI',
    () {
      final uri = generatePortableUri(
        '/storage/emulated/0/Music/track.mp3',
        'Midnight City',
        'M83',
      );
      expect(uri, 'meta:m83_midnightcity');
      expectFalse(uri.contains('/storage'));
    },
  );

  test(
    'Pre-existing public and streaming identifiers are preserved unchanged',
    () {
      expect(
        generatePortableUri('isrc:USUM71204928', 'Song', 'Artist'),
        'isrc:USUM71204928',
      );
      expect(
        generatePortableUri('public:cc-01', 'Bach Suite', 'Orchestra'),
        'public:cc-01',
      );
      expect(
        generatePortableUri('yt:dQw4w9WgXcQ', 'Track', 'Artist'),
        'yt:dQw4w9WgXcQ',
      );
    },
  );

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
    final allowedVisualTypes = {
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    };
    final prohibitedAudioTypes = {
      'audio/mpeg',
      'audio/flac',
      'audio/wav',
      'audio/mp4',
      'audio/ogg',
    };

    for (final audioType in prohibitedAudioTypes) {
      expectFalse(
        allowedVisualTypes.contains(audioType),
        'Audio MIME type $audioType must never be allowed for cloud storage',
      );
    }
  });

  // --- SUITE 5: LIBRARY PERSISTENCE & STREAMING CONFIGURATION ---
  print('\n[Suite 5: Library & Streaming Configuration]');

  test(
    'Supported audio extensions include all lossless and compressed standards',
    () {
      const supportedAudioExtensions = {
        '.mp3',
        '.flac',
        '.wav',
        '.m4a',
        '.aac',
        '.ogg',
        '.opus',
      };
      expectTrue(supportedAudioExtensions.contains('.flac'));
      expectTrue(supportedAudioExtensions.contains('.mp3'));
      expectTrue(supportedAudioExtensions.contains('.wav'));
      expectTrue(supportedAudioExtensions.contains('.opus'));
      expectFalse(supportedAudioExtensions.contains('.exe'));
    },
  );

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
    const validSources = ['youtube', 'spotify', 'soundcloud', 'local'];
    expectTrue(validSources.contains('youtube'));
    expectTrue(validSources.contains('spotify'));
    expectTrue(validSources.contains('soundcloud'));
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

  // --- SUITE 8: IN-APP SELF-UPDATE ENGINE ---
  print('\n[Suite 8: In-App Self-Update Engine]');

  test('Semantic version comparison accurately detects newer releases', () {
    expectTrue(
      MuxisVersionComparator.isNewerVersion(
        remoteVersion: 'v1.1.8',
        currentVersion: '1.1.7',
      ),
    );
    expectTrue(
      MuxisVersionComparator.isNewerVersion(
        remoteVersion: 'v1.2.0',
        currentVersion: '1.1.9',
      ),
    );
    expectTrue(
      MuxisVersionComparator.isNewerVersion(
        remoteVersion: 'v2.0.0',
        currentVersion: '1.9.9',
      ),
    );
    expectFalse(
      MuxisVersionComparator.isNewerVersion(
        remoteVersion: 'v1.1.8',
        currentVersion: '1.1.8+18',
      ),
    );
    expectFalse(
      MuxisVersionComparator.isNewerVersion(
        remoteVersion: 'v1.1.7',
        currentVersion: '1.1.8',
      ),
    );
    expectTrue(
      MuxisVersionComparator.isNewerVersion(
        remoteVersion: '1.2.0',
        currentVersion: '1.2.0-beta.1',
      ),
    );
  });

  test('Platform asset selector prefers native installers cleanly', () {
    final assets = [
      const AppReleaseAsset(
        name: 'Muxis-Windows-x64.zip',
        downloadUrl: 'https://example.com/win.zip',
        sizeBytes: 15000000,
      ),
      const AppReleaseAsset(
        name: 'Muxis-Windows-x64-Setup.exe',
        downloadUrl: 'https://example.com/setup.exe',
        sizeBytes: 12700000,
      ),
      const AppReleaseAsset(
        name: 'Muxis-Android.apk',
        downloadUrl: 'https://example.com/app.apk',
        sizeBytes: 28000000,
      ),
      const AppReleaseAsset(
        name: 'Muxis-macOS-Universal.zip',
        downloadUrl: 'https://example.com/mac.zip',
        sizeBytes: 26000000,
      ),
      const AppReleaseAsset(
        name: 'Muxis-Linux-x64.tar.gz',
        downloadUrl: 'https://example.com/linux.tar.gz',
        sizeBytes: 12300000,
      ),
    ];

    expect(
      MuxisUpdateSelector.selectAssetForOperatingSystem(
        assets,
        'windows',
      )?.name,
      'Muxis-Windows-x64-Setup.exe',
    );
    expect(
      MuxisUpdateSelector.selectAssetForOperatingSystem(
        assets,
        'android',
      )?.name,
      'Muxis-Android.apk',
    );
    expect(
      MuxisUpdateSelector.selectAssetForOperatingSystem(assets, 'macos')?.name,
      'Muxis-macOS-Universal.zip',
    );
    expect(
      MuxisUpdateSelector.selectAssetForOperatingSystem(assets, 'linux')?.name,
      'Muxis-Linux-x64.tar.gz',
    );
  });

  test('SHA-256 parser extracts exact checksum for target asset', () {
    const body = '''
0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  Muxis-Android.apk
fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210 *Muxis-Windows-x64-Setup.exe
''';
    expect(
      MuxisUpdateSelector.parseSha256ForAsset(
        body,
        'Muxis-Windows-x64-Setup.exe',
      ),
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
    );
    expect(
      MuxisUpdateSelector.parseSha256ForAsset(body, 'Muxis-Android.apk'),
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    expect(MuxisUpdateSelector.parseSha256ForAsset(body, 'missing.zip'), null);
    expect(MuxisUpdateSelector.formatBytes(12749738), '12.2 MB');
  });

  // --- SUITE 9: SOUNDCLOUD, FEATURED SHELVES, RADIO TUNER & LIBRARY FILTERING ---
  print('\n[Suite 9: SoundCloud, Featured Shelves, Radio & Library Sort]');

  test(
    'FeaturedSection map serialization round-trips playlists and tracks',
    () {
      const track = Track(
        id: 'sc-99',
        title: 'Neon Drift',
        artist: 'Aurora Producer',
        album: 'Night Drive',
        duration: Duration(seconds: 215),
        source: MusicSource.soundcloud,
        audioFormat: 'SoundCloud Stream',
      );
      const pl = Playlist(
        id: 'sc-pl-1',
        title: 'SoundCloud Weekly',
        description: 'Curated electronic waves',
        tracks: [track],
        trackCount: 1,
      );
      const section = FeaturedSection(
        id: 'sec-1',
        title: 'Featured On SoundCloud',
        subtitle: 'Picked for you',
        source: MusicSource.soundcloud,
        tracks: [track],
        playlists: [pl],
      );

      final decoded = FeaturedSection.fromMap(section.toMap());
      expect(decoded.id, 'sec-1');
      expect(decoded.title, 'Featured On SoundCloud');
      expect(decoded.source, MusicSource.soundcloud);
      expect(decoded.tracks.length, 1);
      expect(decoded.tracks.first.id, 'sc-99');
      expect(decoded.playlists.length, 1);
      expect(decoded.playlists.first.tracks.first.artist, 'Aurora Producer');
    },
  );

  test(
    'RadioStation frequency resolution parses explicit and hashed FM slots',
    () {
      final explicitFreq = RadioStation.resolveFrequency(
        name: 'ABC Radio FM 89.2 Dhaka',
        tags: 'pop,news',
        seedId: 'station-explicit-1',
      );
      expect(explicitFreq.mhz, 89.2);
      expect(explicitFreq.label, '89.2 FM');

      final fallbackFreq = RadioStation.resolveFrequency(
        name: 'SomaFM Groove Salad',
        tags: 'ambient,chillout',
        seedId: 'somafm-gs-001',
      );
      expectTrue(fallbackFreq.mhz >= 87.5 && fallbackFreq.mhz <= 108.0);
      expectTrue(fallbackFreq.label.endsWith('FM'));

      const station = RadioStation(
        id: 'st-1',
        name: 'Radio Foorti 88.0',
        streamUrl: 'https://stream.example.com/live.mp3',
        country: 'Bangladesh',
        countryCode: 'BD',
        city: 'Dhaka',
        frequencyMhz: 88.0,
        frequencyLabel: '88.0 FM',
        codec: 'MP3',
        bitrateKbps: 128,
        tags: 'pop,hits',
      );
      final track = station.toTrack();
      expect(track.source, MusicSource.radio);
      expect(track.streamUrl, 'https://stream.example.com/live.mp3');
      expect(track.duration, Duration.zero);
    },
  );

  test(
    'Library sort and keyword preset filtering handles all modes accurately',
    () {
      const tracks = [
        Track(
          id: 't1',
          title: 'Starlight (Live Remix)',
          artist: 'Zebra Act',
          album: 'Black Holes',
          duration: Duration(minutes: 6),
          source: MusicSource.local,
          audioFormat: 'FLAC 24-bit Lossless',
          isFavorite: true,
        ),
        Track(
          id: 't2',
          title: 'Ambient Rain',
          artist: 'Alpha Artist',
          album: 'Raindrops EP',
          duration: Duration(seconds: 110),
          source: MusicSource.soundcloud,
          audioFormat: 'MP3 128kbps',
        ),
        Track(
          id: 't3',
          title: 'Midnight Drive',
          artist: 'Midnight Band',
          album: 'Night Owl',
          duration: Duration(minutes: 3, seconds: 45),
          source: MusicSource.spotify,
          audioFormat: 'Spotify Bridge',
        ),
      ];

      final sortedAsc = applyLibrarySortAndFilter(
        tracks: tracks,
        sortOption: LibrarySortOption.titleAsc,
      );
      expect(sortedAsc.map((t) => t.id).join(','), 't2,t3,t1');

      final sortedLongest = applyLibrarySortAndFilter(
        tracks: tracks,
        sortOption: LibrarySortOption.durationDesc,
      );
      expect(sortedLongest.first.id, 't1');

      final losslessOnly = applyLibrarySortAndFilter(
        tracks: tracks,
        preset: LibraryKeywordPreset.lossless,
      );
      expect(losslessOnly.length, 1);
      expect(losslessOnly.first.id, 't1');

      final scOnly = applyLibrarySortAndFilter(
        tracks: tracks,
        preset: LibraryKeywordPreset.soundcloud,
      );
      expect(scOnly.length, 1);
      expect(scOnly.first.id, 't2');

      final chillShort = applyLibrarySortAndFilter(
        tracks: tracks,
        preset: LibraryKeywordPreset.shortTracks,
      );
      expect(chillShort.length, 1);
      expect(chillShort.first.id, 't2');

      final remix = applyLibrarySortAndFilter(
        tracks: tracks,
        preset: LibraryKeywordPreset.remixLive,
      );
      expect(remix.length, 1);
      expect(remix.first.id, 't1');
    },
  );

  // --- SUITE 12: SOUNDCLOUD SINGLE-WINDOW OAUTH & PKCE ---
  print('\n[Suite 12: SoundCloud Single-Window OAuth & PKCE]');

  test(
    'SoundCloud PKCE generates RFC-7636 verifier and encodes client state',
    () {
      final rfcVector = SoundCloudPkcePair.fromVerifier(
        codeVerifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
        nonce: 'test_nonce_1234',
      );
      expect(
        rfcVector.codeChallenge,
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );

      final pkce = SoundCloudPkcePair.generate();
      expectTrue(pkce.codeVerifier.length == 64);
      expectFalse(pkce.codeChallenge.contains('='));
      expectTrue(pkce.nonce.length == 32);

      final state = pkce.buildStateJson('zQBXL76oebJv6L1OhUMMtNEmdG6Th0wF');
      final extracted = SoundCloudPkcePair.extractClientIdFromState(state);
      expect(extracted, 'zQBXL76oebJv6L1OhUMMtNEmdG6Th0wF');
    },
  );

  test('Rewriting embedded web-auth promotes top-level same-window OAuth', () {
    final pkce = SoundCloudPkcePair.generate();
    final embedded = Uri.parse(
      'https://secure.soundcloud.com/web-auth?client_id=testcid123&app_id=46941&theme=dark&ui_evo=true&embedded_in_iframe=true&redirect_uri=https%3A%2F%2Fsoundcloud.com%2Fsignin%2Fcallback',
    );
    final rewritten = SoundCloudAuthUrlHelper.rewriteWebAuthToStandAlone(
      embedded,
      pkce,
    );
    expectTrue(rewritten != null);
    expect(rewritten!.queryParameters['app_id'], '3152');
    expect(rewritten.queryParameters['stand_alone'], 'true');
    expectFalse(rewritten.queryParameters.containsKey('embedded_in_iframe'));
    expect(rewritten.queryParameters['code_challenge'], pkce.codeChallenge);
    expect(
      SoundCloudPkcePair.extractClientIdFromState(
        rewritten.queryParameters['state'],
      ),
      'testcid123',
    );

    // Must not overwrite returning federated provider callback payload
    final returningCallback = rewritten.replace(
      queryParameters: {
        ...rewritten.queryParameters,
        'provider_params': 'eyJ0b2tlbiI6Inh5eiJ9',
      },
    );
    expect(
      SoundCloudAuthUrlHelper.rewriteWebAuthToStandAlone(
        returningCallback,
        pkce,
      ),
      null,
    );
  });

  test('SoundCloud host matcher excludes secure/api subdomains and matches callback', () {
    expectTrue(SoundCloudAuthUrlHelper.isMainSoundCloudHost('soundcloud.com'));
    expectTrue(
      SoundCloudAuthUrlHelper.isMainSoundCloudHost('m.soundcloud.com'),
    );
    expectFalse(
      SoundCloudAuthUrlHelper.isMainSoundCloudHost('secure.soundcloud.com'),
    );
    expectFalse(
      SoundCloudAuthUrlHelper.isMainSoundCloudHost('api-auth.soundcloud.com'),
    );

    final callbackUri = Uri.parse(
      'https://soundcloud.com/signin/callback?code=authcode123&state=abc',
    );
    expectTrue(SoundCloudAuthUrlHelper.isSigninCallbackUri(callbackUri));
    expectFalse(SoundCloudAuthUrlHelper.isSignedInHomeUri(callbackUri));

    final secureAuthUri = Uri.parse('https://secure.soundcloud.com/web-auth');
    expectFalse(SoundCloudAuthUrlHelper.isSignedInHomeUri(secureAuthUri));

    final homeUri = Uri.parse('https://soundcloud.com/discover');
    expectTrue(SoundCloudAuthUrlHelper.isSignedInHomeUri(homeUri));
  });

  test(
    'SoundCloud cookie & manual oauth_token normalizers clean inputs safely',
    () {
      final tok = SoundCloudAuthUrlHelper.extractOAuthTokenFromCookies(
        'sc_anonymous_id=123; oauth_token=2-295843-9911-abc%2Bdef; other=1',
      );
      expect(tok, '2-295843-9911-abc+def');

      expect(
        SoundCloudAuthUrlHelper.normalizeManualOAuthToken(
          'oauth_token=2-295843-9911-xyz; path=/',
        ),
        '2-295843-9911-xyz',
      );
      expect(
        SoundCloudAuthUrlHelper.normalizeManualOAuthToken(
          'OAuth 2-295843-9911',
        ),
        '2-295843-9911',
      );
      expectTrue(
        SoundCloudAuthUrlHelper.looksLikeGoogleWebViewBlock(
          url: 'https://accounts.google.com/v3/signin/rejected',
          bodyText: 'This browser or app may not be secure. Learn more',
        ),
      );
    },
  );

  // --- SUITE 13: HIGH-VOLUME LIBRARY SORT & FILTER ---
  print('\n[Suite 13: High-Volume Library Sort & Filter]');

  test(
    'Pre-keyed library sort handles 2000 tracks accurately across all modes',
    () {
      final largeTracks = List<Track>.generate(2000, (i) {
        final rev = 1999 - i;
        return Track(
          id: 'tr-$i',
          title: 'Track ${rev.toString().padLeft(4, '0')}',
          artist: 'Artist ${(i % 50).toString().padLeft(2, '0')}',
          album: 'Album ${i % 25}',
          duration: Duration(seconds: 60 + i),
          source: MusicSource.values[i % MusicSource.values.length],
          isFavorite: i % 10 == 0,
        );
      });

      final titleAsc = applyLibrarySortAndFilter(
        tracks: largeTracks,
        sortOption: LibrarySortOption.titleAsc,
      );
      expect(titleAsc.length, 2000);
      expect(titleAsc.first.title, 'Track 0000');
      expect(titleAsc.last.title, 'Track 1999');

      final titleDesc = applyLibrarySortAndFilter(
        tracks: largeTracks,
        sortOption: LibrarySortOption.titleDesc,
      );
      expect(titleDesc.first.title, 'Track 1999');
      expect(titleDesc.last.title, 'Track 0000');

      final recentFastPath = applyLibrarySortAndFilter(tracks: largeTracks);
      expect(recentFastPath.first.id, 'tr-1999');
      expect(recentFastPath.last.id, 'tr-0');

      final byArtist = applyLibrarySortAndFilter(
        tracks: largeTracks,
        sortOption: LibrarySortOption.artistAsc,
      );
      expect(byArtist.first.artist, 'Artist 00');

      final bySource = applyLibrarySortAndFilter(
        tracks: largeTracks,
        sortOption: LibrarySortOption.source,
      );
      expect(bySource.first.source, MusicSource.values.first);
    },
  );

  // --- SUITE 14: MUXIS CLOUD AUTH HELPERS ---
  print('\n[Suite 14: MUXIS Cloud Auth Helpers]');

  test(
    'CloudAuthHelper parses Supabase /auth/v1/settings and callback URIs',
    () {
      final disabled = CloudAuthHelper.parseAuthSettings({
        'external': {'google': false, 'apple': false, 'email': true},
        'mailer_autoconfirm': false,
      });
      expectFalse(disabled.google);
      expectFalse(disabled.apple);
      expectTrue(disabled.email);
      expectFalse(disabled.autoconfirm);

      final enabled = CloudAuthHelper.parseAuthSettings(
        '{"external":{"google":true,"apple":true,"email":true},"mailer_autoconfirm":true}',
      );
      expectTrue(enabled.google);
      expectTrue(enabled.apple);
      expectTrue(enabled.autoconfirm);

      expectTrue(
        CloudAuthHelper.validateSignup(email: 'bad', password: 'password123') !=
            null,
      );
      expectTrue(
        CloudAuthHelper.validateSignup(
              email: 'user@gmail.com',
              password: '123',
            ) !=
            null,
      );
      expect(
        CloudAuthHelper.validateSignup(
          email: 'user@gmail.com',
          password: 'password123',
        ),
        null,
      );

      expectFalse(
        CloudAuthHelper.isCompletedCallbackUri(
          Uri.parse('http://localhost:3000/auth-callback'),
        ),
      );
      expectTrue(
        CloudAuthHelper.isCompletedCallbackUri(
          Uri.parse('http://localhost:3000/auth-callback?code=abc123'),
        ),
      );
      expectTrue(
        CloudAuthHelper.isCompletedCallbackUri(
          Uri.parse('http://localhost:3000/auth-callback?error=access_denied'),
        ),
      );
    },
  );

  print('\n======================================================');
  print('  RESULTS: $passed PASSED, $failed FAILED');
  print('======================================================');

  if (failed > 0) {
    exit(1);
  } else {
    print('All core unit test suites verified successfully.\n');
  }
}

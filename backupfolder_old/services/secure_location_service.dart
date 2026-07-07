import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ============================================================
// SECURITY CONSTANTS
// ============================================================
class LocationSecurityConfig {
  static const int maxPositionAgeSeconds = 30;
  static const double strictAccuracyMeters = 25.0;
  static const double relaxedAccuracyMeters = 50.0;
  static const double absoluteMaxAccuracyMeters = 60.0;
  static const double geofenceRadiusMeters = 50.0;
  static const int strictWindowSeconds = 8;
  static const int hardTimeoutSeconds = 20;
  static const double maxReasonableSpeedMs = 30.0; // ~108 km/h
}

// ============================================================
// SECURE POSITION RESULT — carries audit trail
// ============================================================
class SecurePositionResult {
  final Position position;
  final String integrityHash;
  final DateTime capturedAt;
  final bool isMockDetected;
  final bool passedSanityCheck;
  final String source;
  final Map<String, dynamic> auditData;

  const SecurePositionResult({
    required this.position,
    required this.integrityHash,
    required this.capturedAt,
    required this.isMockDetected,
    required this.passedSanityCheck,
    required this.source,
    required this.auditData,
  });

  bool get isTrusted =>
      !isMockDetected &&
      passedSanityCheck &&
      position.accuracy <= LocationSecurityConfig.absoluteMaxAccuracyMeters;
}

// ============================================================
// SECURE LOCATION SERVICE
// ============================================================
class SecureLocationService {
  static SecurePositionResult? _lastResult;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<SecurePositionResult> getSecurePosition() async {
    await _ensureLocationPermission();

    // Reuse very recent trusted location if available (helps offline cases)
    if (_lastResult != null) {
      final ageSeconds =
          DateTime.now().toUtc().difference(_lastResult!.capturedAt).inSeconds;
      if (ageSeconds <= 300 &&
          _lastResult!.position.accuracy <=
              LocationSecurityConfig.absoluteMaxAccuracyMeters) {
        print(
          '[SECURE_LOC] Using cached secure position '
          '(${ageSeconds}s old, '
          '${_lastResult!.position.accuracy.toStringAsFixed(0)}m)',
        );
        return _lastResult!;
      }
    }

    final isMock = await _detectMockLocation();
    if (isMock) {
      print('[SECURE_LOC] ⚠️ Mock location / emulator detected!');
    }

    final position = await _getPositionViaStream();
    _validatePositionAge(position);
    final passedSanity = _performSanityCheck(position);
    final hash = _buildIntegrityHash(position);
    final auditData = await _buildAuditTrail(
      position: position,
      isMock: isMock,
      passedSanity: passedSanity,
      hash: hash,
    );

    final result = SecurePositionResult(
      position: position,
      integrityHash: hash,
      capturedAt: DateTime.now().toUtc(),
      isMockDetected: isMock,
      passedSanityCheck: passedSanity,
      source: _classifySource(position),
      auditData: auditData,
    );

    _lastResult = result;

    print(
      '[SECURE_LOC] Position secured: '
      'lat=${position.latitude.toStringAsFixed(6)}, '
      'lon=${position.longitude.toStringAsFixed(6)}, '
      'accuracy=${position.accuracy.toStringAsFixed(0)}m, '
      'mock=$isMock, sanity=$passedSanity, hash=${hash.substring(0, 8)}...',
    );

    return result;
  }

  static Future<Position> _getPositionViaStream() async {
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        final age = DateTime.now().difference(cached.timestamp);
        if (age.inSeconds < 15 &&
            cached.accuracy <= LocationSecurityConfig.strictAccuracyMeters) {
          print(
            '[SECURE_LOC] Using fresh cache '
            '(${age.inSeconds}s old, ${cached.accuracy.toStringAsFixed(0)}m)',
          );
          return cached;
        }
      }
    } catch (_) {}

    final completer = Completer<Position>();
    StreamSubscription<Position>? sub;
    Timer? relaxTimer;
    Timer? hardTimer;

    double threshold = LocationSecurityConfig.strictAccuracyMeters;
    Position? bestSoFar;

    void accept(Position pos, String reason) {
      if (completer.isCompleted) return;
      print(
        '[SECURE_LOC] Accepting position ($reason): '
        '${pos.accuracy.toStringAsFixed(0)}m accuracy',
      );
      sub?.cancel();
      relaxTimer?.cancel();
      hardTimer?.cancel();
      completer.complete(pos);
    }

    final locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            forceLocationManager: false,
            intervalDuration: const Duration(seconds: 1),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          );

    sub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (pos) {
        print(
          '[SECURE_LOC] Stream: ${pos.accuracy.toStringAsFixed(0)}m '
          '(need <=$threshold m, mock=${pos.isMocked})',
        );

        if (bestSoFar == null || pos.accuracy < bestSoFar!.accuracy) {
          bestSoFar = pos;
        }

        if (pos.isMocked) {
          print('[SECURE_LOC] ⚠️ Stream position flagged as mocked, skipping');
          return;
        }

        if (pos.accuracy <= threshold) {
          accept(pos, 'within threshold ${threshold.toStringAsFixed(0)}m');
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          sub?.cancel();
          relaxTimer?.cancel();
          hardTimer?.cancel();
          completer.completeError(
            Exception('Location stream error: $e'),
          );
        }
      },
    );

    relaxTimer = Timer(
      const Duration(seconds: LocationSecurityConfig.strictWindowSeconds),
      () {
        if (!completer.isCompleted) {
          threshold = LocationSecurityConfig.relaxedAccuracyMeters;
          print(
            '[SECURE_LOC] Relaxing to ${threshold.toStringAsFixed(0)}m',
          );

          if (bestSoFar != null &&
              bestSoFar!.accuracy <= threshold &&
              !bestSoFar!.isMocked) {
            accept(bestSoFar!, 'best-so-far meets relaxed threshold');
          }
        }
      },
    );

    hardTimer = Timer(
      const Duration(seconds: LocationSecurityConfig.hardTimeoutSeconds),
      () {
        if (completer.isCompleted) return;

        if (bestSoFar != null &&
            bestSoFar!.accuracy <=
                LocationSecurityConfig.absoluteMaxAccuracyMeters &&
            !bestSoFar!.isMocked) {
          accept(
            bestSoFar!,
            'hard timeout — best available '
            '${bestSoFar!.accuracy.toStringAsFixed(0)}m',
          );
          return;
        }

        // Offline / poor-signal fallback: try last known position before failing
        Geolocator.getLastKnownPosition().then((fallback) {
          if (completer.isCompleted) return;
          if (fallback != null) {
            accept(
              fallback,
              'hard timeout — using last known position',
            );
          } else {
            sub?.cancel();
            relaxTimer?.cancel();
            completer.completeError(
              Exception(
                'Could not get accurate location within '
                '${LocationSecurityConfig.hardTimeoutSeconds}s. '
                'Best accuracy: '
                '${bestSoFar?.accuracy.toStringAsFixed(0) ?? "none"}m. '
                'Please move outdoors and try again.',
              ),
            );
          }
        }).catchError((_) {
          if (completer.isCompleted) return;
          sub?.cancel();
          relaxTimer?.cancel();
          completer.completeError(
            Exception(
              'Could not get accurate location within '
              '${LocationSecurityConfig.hardTimeoutSeconds}s. '
              'Best accuracy: '
              '${bestSoFar?.accuracy.toStringAsFixed(0) ?? "none"}m. '
              'Please move outdoors and try again.',
            ),
          );
        });
      },
    );

    return completer.future;
  }

  static Future<bool> _detectMockLocation() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        if (!androidInfo.isPhysicalDevice) {
          print('[SECURE_LOC] ⚠️ Running on emulator/virtual device');
          return true;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        if (!iosInfo.isPhysicalDevice) {
          print('[SECURE_LOC] ⚠️ Running on iOS simulator');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('[SECURE_LOC] Mock detection error: $e');
      return false;
    }
  }

  static void _validatePositionAge(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    if (age.inSeconds > LocationSecurityConfig.maxPositionAgeSeconds) {
      // For offline/poor-signal scenarios we allow older positions and just log.
      print(
        '[SECURE_LOC] Position age ${age.inSeconds}s exceeds strict '
        'limit of ${LocationSecurityConfig.maxPositionAgeSeconds}s, '
        'continuing with latest available fix.',
      );
    }
  }

  static bool _performSanityCheck(Position newPos) {
    if (_lastResult == null) return true;

    final last = _lastResult!.position;
    final timeDelta =
        DateTime.now().difference(_lastResult!.capturedAt).inSeconds.toDouble();

    if (timeDelta <= 0) return true;

    final distance = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    final impliedSpeed = distance / timeDelta;

    if (impliedSpeed > LocationSecurityConfig.maxReasonableSpeedMs) {
      print(
        '[SECURE_LOC] ⚠️ Sanity FAILED: '
        'Moved ${distance.toStringAsFixed(0)}m in ${timeDelta.toStringAsFixed(0)}s '
        '(${(impliedSpeed * 3.6).toStringAsFixed(0)} km/h)',
      );
      return false;
    }

    print(
      '[SECURE_LOC] ✅ Sanity passed: '
      '${distance.toStringAsFixed(0)}m in ${timeDelta.toStringAsFixed(0)}s',
    );
    return true;
  }

  static String _buildIntegrityHash(Position position) {
    final data = [
      position.latitude.toStringAsFixed(8),
      position.longitude.toStringAsFixed(8),
      position.accuracy.toStringAsFixed(2),
      position.timestamp.millisecondsSinceEpoch.toString(),
    ].join('|');

    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<Map<String, dynamic>> _buildAuditTrail({
    required Position position,
    required bool isMock,
    required bool passedSanity,
    required String hash,
  }) async {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'heading': position.heading,
      'timestamp_device': position.timestamp.toIso8601String(),
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      'is_mocked': isMock || position.isMocked,
      'passed_sanity': passedSanity,
      'integrity_hash': hash,
      'source': _classifySource(position),
      'platform': Platform.isAndroid ? 'android' : 'ios',
    };
  }

  static Future<bool> verifyGeofenceOnServer({
    required SecurePositionResult securePosition,
    required String classID,
    required String learnerID,
    required String action,
    required String baseUrl,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/verify_geofence.php');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'learner_id': learnerID,
              'class_id': classID,
              'action': action,
              'audit_data': securePosition.auditData,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('[SECURE_LOC] ✅ Server geofence verification passed');
          return true;
        } else {
          print(
            '[SECURE_LOC] ❌ Server geofence rejected: ${data['error']}',
          );
          return false;
        }
      }
      return false;
    } catch (e) {
      print('[SECURE_LOC] Server verification failed: $e');
      return securePosition.isTrusted &&
          !securePosition.isMockDetected &&
          securePosition.passedSanityCheck;
    }
  }

  static String _classifySource(Position pos) {
    if (pos.accuracy <= 10) return 'gps_excellent';
    if (pos.accuracy <= 25) return 'gps_good';
    if (pos.accuracy <= 50) return 'gps_fair';
    return 'network_or_poor_gps';
  }

  static Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. '
        'Please enable in device settings.',
      );
    }
  }
}

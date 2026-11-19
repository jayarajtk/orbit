import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';

/// Sends the device's position to the server, which snaps it (ADR-0003).
// An interface rather than a function typedef so tests can swap in a fake
// and the location service can grow (permission state, foreground updates).
// ignore: one_member_abstracts
abstract interface class LocationRepository {
  /// Asks for "while in use" permission if needed, reads one medium-accuracy
  /// fix and uploads it. Returns false when permission is refused or
  /// location services are off.
  Future<bool> shareCurrentLocation();
}

/// The configured [LocationRepository].
final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => AppEnv.usesApi
      ? DeviceLocationRepository(ref.watch(dioProvider))
      : const DemoLocationRepository(),
);

/// Demo mode: distances are part of the dummy data.
class DemoLocationRepository implements LocationRepository {
  /// Creates the demo repository.
  const DemoLocationRepository();

  @override
  Future<bool> shareCurrentLocation() async => true;
}

/// Reads one fix with `geolocator` and uploads it. No background location
/// and no continuous tracking: one fix per call (ADR-0003 battery rules).
class DeviceLocationRepository implements LocationRepository {
  /// Creates the repository on [_dio].
  DeviceLocationRepository(this._dio);

  final Dio _dio;

  @override
  Future<bool> shareCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
    try {
      await guardApi(
        () => _dio.put<void>(
          '/me/location',
          data: {'lat': position.latitude, 'lng': position.longitude},
        ),
      );
    } on ApiException catch (e) {
      // Updated within the last minute: the stored location is fresh enough.
      if (!e.isProblem('location-rate-limited')) rethrow;
    }
    return true;
  }
}

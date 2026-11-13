import 'package:geolocator/geolocator.dart';

class LocationUnavailableException implements Exception {
  final String message;
  LocationUnavailableException(this.message);
  @override
  String toString() => message;
}

/// Wraps on-device GPS access. Location is read directly from the OS and
/// used only to query nearby stops — it is never sent anywhere except as
/// coordinates in a Transport for NSW API request, and never stored.
class LocationService {
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationUnavailableException('Location services are turned off. Enable them to find nearby stops.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationUnavailableException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationUnavailableException('Location permission is permanently denied. Enable it in system settings.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}

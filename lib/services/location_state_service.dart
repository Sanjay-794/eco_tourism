class LocationStateService {
  LocationStateService._();

  static double? _lastLatitude;
  static double? _lastLongitude;

  static void setLastLocation(double latitude, double longitude) {
    _lastLatitude = latitude;
    _lastLongitude = longitude;
  }

  static (double, double)? getLastLocation() {
    if (_lastLatitude == null || _lastLongitude == null) return null;
    return (_lastLatitude!, _lastLongitude!);
  }
}
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();
  LocationData? _lastKnownLocation;
  Stream<LocationData>? _locationStream;

  
  LocationService() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    
    _locationStream = _location.onLocationChanged;
    _locationStream?.listen((LocationData location) {
      _lastKnownLocation = location;
    });
  }

  Future<LocationData?> getCurrentLocation() async {
    
    if (_lastKnownLocation != null) {
      return _lastKnownLocation;
    }

    
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null; 
      }
    }

    
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return null; 
      }
    }

    
    _lastKnownLocation = await _location.getLocation();
    return _lastKnownLocation;
  }

  
  LocationData? getLastLocation() {
    return _lastKnownLocation;
  }

  
  Stream<LocationData> trackLocation() {
    return _locationStream ?? _location.onLocationChanged;
  }
}
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();

  
  LocationService() {
    
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  Future<LocationData?> getCurrentLocation() async {
    
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

    
    return await _location.getLocation();
  }

  
  Stream<LocationData> trackLocation() {
    return _location.onLocationChanged;
  }
}

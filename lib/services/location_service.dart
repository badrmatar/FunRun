
import 'dart:io';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    
    if (Platform.isIOS && permission == LocationPermission.whileInUse) {
      
      await Geolocator.requestPermission();
    }
  }

  
  Future<Position?> getCurrentLocation() async {
    try {
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      
      LocationPermission permission = await Geolocator.checkPermission();
      print('Current location permission status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('After request, permission status: $permission');

        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied');
        return null;
      }

      
      if (Platform.isIOS) {
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (timeoutError) {
          print('Timeout getting precise location, falling back to last known position');
          
          return await Geolocator.getLastKnownPosition();
        }
      } else {
        
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }


  Stream<Position> trackLocation() {
    var locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, 
    );

    
    if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
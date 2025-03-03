
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
      
      if (Platform.isIOS) {
        final LocationSettings locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation, 
          activityType: ActivityType.fitness,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );

        
        final positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) => sink.close(),
        );

        
        try {
          final positions = await positionStream.take(10).toList();

          
          if (positions.isNotEmpty) {
            positions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
            return positions.first; 
          }
        } catch (e) {
          print('Error in position stream: $e');
        }

        
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 20),
        );
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
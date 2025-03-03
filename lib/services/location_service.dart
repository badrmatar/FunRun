
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

  
  bool _isValidAccuracy(double accuracy) {
    
    if (accuracy == 1440.0) return false;

    
    if (accuracy > 100.0 && !Platform.isIOS) return false;
    if (accuracy > 200.0 && Platform.isIOS) return false;

    return true;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      
      if (Platform.isIOS) {
        final LocationSettings locationSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation, 
          activityType: ActivityType.fitness,
          distanceFilter: 0, 
          pauseLocationUpdatesAutomatically: false,
          
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );

        
        try {
          final positionStream = Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: (sink) => sink.close(),
          );

          final positions = await positionStream.take(8).toList();

          
          final validPositions = positions
              .where((pos) => _isValidAccuracy(pos.accuracy))
              .toList();

          if (validPositions.isNotEmpty) {
            validPositions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
            return validPositions.first; 
          }

          
          if (positions.isNotEmpty) {
            positions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
            return positions.first;
          }
        } catch (e) {
          print('Error in position stream: $e');
        }

        
        final Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 20),
        );

        
        if (_isValidAccuracy(position.accuracy)) {
          return position;
        } else {
          
          await Future.delayed(const Duration(seconds: 2));
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 10),
          );
        }
      } else {
        
        final LocationSettings locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          forceLocationManager: false, 
          intervalDuration: const Duration(seconds: 1),
        );

        try {
          final positionStream = Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: (sink) => sink.close(),
          );

          final positions = await positionStream.take(5).toList();

          
          final validPositions = positions
              .where((pos) => _isValidAccuracy(pos.accuracy))
              .toList();

          if (validPositions.isNotEmpty) {
            validPositions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
            return validPositions.first;
          }

          if (positions.isNotEmpty) {
            positions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
            return positions.first;
          }
        } catch (e) {
          print('Error in Android position stream: $e');
        }

        
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
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
    } else {
      
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .where((position) => _isValidAccuracy(position.accuracy)); 
  }
}
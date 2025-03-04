

import 'dart:async';
import 'dart:math';
import 'dart:io'; 
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../services/location_service.dart';

mixin RunTrackingMixin<T extends StatefulWidget> on State<T> {
  
  final LocationService locationService = LocationService();
  Position? currentLocation;
  Position? startLocation;
  Position? endLocation;
  double distanceCovered = 0.0;
  int secondsElapsed = 0;
  Timer? runTimer;
  bool isTracking = false;
  bool autoPaused = false;
  StreamSubscription<Position>? locationSubscription;
  Timer? _locationQualityCheckTimer; 

  
  final List<LatLng> routePoints = [];
  Polyline routePolyline = const Polyline(
    polylineId: PolylineId('route'),
    color: Colors.orange,
    width: 5,
    points: [],
  );
  GoogleMapController? mapController;

  
  int stillCounter = 0;
  final double pauseThreshold = 0.5;
  final double resumeThreshold = 1.0;
  LatLng? lastRecordedLocation;

  
  int _poorQualityReadingsCount = 0;
  Position? _lastGoodPosition;
  final int _maxPoorReadings = 5; 

  
  final double _goodAccuracyThreshold = 30.0; 
  final double _acceptableAccuracyThreshold = 50.0; 

  
  void startRun(Position initialPosition) {
    setState(() {
      startLocation = initialPosition;
      currentLocation = initialPosition; 
      _lastGoodPosition = initialPosition; 
      isTracking = true;
      distanceCovered = 0.0;
      secondsElapsed = 0;
      autoPaused = false;
      routePoints.clear();
      _poorQualityReadingsCount = 0;

      final startPoint = LatLng(initialPosition.latitude, initialPosition.longitude);
      routePoints.add(startPoint);
      routePolyline = routePolyline.copyWith(pointsParam: routePoints);
      lastRecordedLocation = startPoint;
    });

    
    runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!autoPaused && mounted) {
        setState(() => secondsElapsed++);
      }
    });

    
    _startLocationQualityMonitoring();

    
    _startContinuousLocationTracking();
  }

  
  void _startLocationQualityMonitoring() {
    _locationQualityCheckTimer?.cancel();
    _locationQualityCheckTimer = Timer.periodic(
        const Duration(seconds: 30), 
            (_) => _checkLocationQuality()
    );
  }

  
  void _checkLocationQuality() {
    if (!isTracking || currentLocation == null) return;

    
    if (_poorQualityReadingsCount >= _maxPoorReadings) {
      print('Location quality degraded - forcing refresh');

      
      _restartLocationTracking();

      
      _poorQualityReadingsCount = 0;
    }
  }

  
  void _restartLocationTracking() {
    
    locationSubscription?.cancel();

    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && isTracking) {
        _startContinuousLocationTracking();
      }
    });
  }

  
  void _startContinuousLocationTracking() {
    final LocationSettings locationSettings = Platform.isIOS
        ? AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: true,
      showBackgroundLocationIndicator: true,
    )
        : AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      forceLocationManager: true, 
    );

    
    locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings
    ).listen((position) {
      if (!isTracking) return;

      
      bool isGoodQuality = _isGoodQualityReading(position);

      if (isGoodQuality) {
        
        _poorQualityReadingsCount = 0;

        
        _lastGoodPosition = position;

        
        final speed = position.speed.clamp(0.0, double.infinity);
        _handleAutoPauseLogic(speed);

        
        if (lastRecordedLocation != null && !autoPaused) {
          final newDistance = calculateDistance(
            lastRecordedLocation!.latitude,
            lastRecordedLocation!.longitude,
            position.latitude,
            position.longitude,
          );
          if (newDistance > 5.0) {  
            setState(() {
              distanceCovered += newDistance;
              lastRecordedLocation = LatLng(position.latitude, position.longitude);
            });
          }
        }

        
        setState(() {
          currentLocation = position;
          final newPoint = LatLng(position.latitude, position.longitude);
          routePoints.add(newPoint);
          routePolyline = routePolyline.copyWith(pointsParam: routePoints);
        });

        
        mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      } else {
        
        _poorQualityReadingsCount++;

        print('Poor quality GPS reading: ${position.accuracy}m (${_poorQualityReadingsCount}/$_maxPoorReadings)');

        
        if (_lastGoodPosition != null && _poorQualityReadingsCount < _maxPoorReadings * 2) {
          
          setState(() {
            currentLocation = position; 
          });
        }
      }
    }, onError: (error) {
      print('Error in location tracking: $error');

      
      _poorQualityReadingsCount++;

      
      if (_poorQualityReadingsCount >= _maxPoorReadings) {
        _restartLocationTracking();
        _poorQualityReadingsCount = 0;
      }
    });
  }

  
  bool _isGoodQualityReading(Position position) {
    
    if (Platform.isIOS) {
      
      if (position.accuracy == 1440.0) return false;
      if (position.accuracy == 65.0) return false;
      if (position.accuracy >= 100.0) return false;

      
      if (position.speed < 0) return false; 

      
      if (_lastGoodPosition != null) {
        final double jumpDistance = Geolocator.distanceBetween(
            _lastGoodPosition!.latitude,
            _lastGoodPosition!.longitude,
            position.latitude,
            position.longitude
        );

        
        
        if (jumpDistance > 300 && position.speed < 20) {
          print('Detected position jump of ${jumpDistance.round()}m - ignoring');
          return false;
        }
      }
    }

    
    return position.accuracy <= _acceptableAccuracyThreshold;
  }

  
  void endRun() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    _locationQualityCheckTimer?.cancel();
    isTracking = false;
    endLocation = currentLocation;
  }

  
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    const double earthRadius = 6371000.0;
    final dLat = (endLat - startLat) * (pi / 180);
    final dLng = (endLng - startLng) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(startLat * (pi / 180)) * cos(endLat * (pi / 180)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  
  void _handleAutoPauseLogic(double speed) {
    if (autoPaused) {
      if (speed > resumeThreshold) {
        setState(() {
          autoPaused = false;
          stillCounter = 0;
        });
      }
    } else {
      if (speed < pauseThreshold) {
        stillCounter++;
        if (stillCounter >= 5) {
          setState(() => autoPaused = true);
        }
      } else {
        stillCounter = 0;
      }
    }
  }

  
  @override
  void dispose() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    _locationQualityCheckTimer?.cancel();
    super.dispose();
  }
}
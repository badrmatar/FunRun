import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/kalman_filter.dart';

enum LocationQuality { excellent, good, fair, poor, unusable }
enum TrackingMode { standard, battery_saving, high_accuracy }

class LocationService {
  
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  
  final _locationController = StreamController<Position>.broadcast();
  final _qualityController = StreamController<LocationQuality>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastPosition;
  LocationQuality _currentQuality = LocationQuality.unusable;
  TrackingMode _currentMode = TrackingMode.standard;
  bool _isTracking = false;

  
  final Map<LocationQuality, double> _accuracyThresholds = {
    LocationQuality.excellent: 10.0, 
    LocationQuality.good: 20.0,      
    LocationQuality.fair: 35.0,      
    LocationQuality.poor: 50.0,      
    
  };

  
  KalmanFilter2D? _kalmanFilter;

  
  LocationSettings _getLocationSettings() {
    if (Platform.isIOS) {
      
      switch (_currentMode) {
        case TrackingMode.high_accuracy:
          return AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );
        case TrackingMode.battery_saving:
          return AppleSettings(
            accuracy: LocationAccuracy.reduced, 
            distanceFilter: 15,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: true,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );
        case TrackingMode.standard:
        default:
          return AppleSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: false,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
          );
      }
    } else {
      
      switch (_currentMode) {
        case TrackingMode.high_accuracy:
          return AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            forceLocationManager: false,
            intervalDuration: const Duration(seconds: 1),
          );
        case TrackingMode.battery_saving:
          return AndroidSettings(
            accuracy: LocationAccuracy.reduced, 
            distanceFilter: 15,
            forceLocationManager: false,
            intervalDuration: const Duration(seconds: 3),
          );
        case TrackingMode.standard:
        default:
          return AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10,
            forceLocationManager: false,
            intervalDuration: const Duration(seconds: 2),
          );
      }
    }
  }

  
  LocationQuality _assessLocationQuality(Position position) {
    final accuracy = position.accuracy;

    if (accuracy <= _accuracyThresholds[LocationQuality.excellent]!) {
      return LocationQuality.excellent;
    } else if (accuracy <= _accuracyThresholds[LocationQuality.good]!) {
      return LocationQuality.good;
    } else if (accuracy <= _accuracyThresholds[LocationQuality.fair]!) {
      return LocationQuality.fair;
    } else if (accuracy <= _accuracyThresholds[LocationQuality.poor]!) {
      return LocationQuality.poor;
    } else {
      return LocationQuality.unusable;
    }
  }

  
  String getQualityDescription(LocationQuality quality) {
    switch (quality) {
      case LocationQuality.excellent:
        return 'Excellent GPS signal';
      case LocationQuality.good:
        return 'Good GPS signal';
      case LocationQuality.fair:
        return 'Fair GPS signal';
      case LocationQuality.poor:
        return 'Poor GPS signal';
      case LocationQuality.unusable:
        return 'GPS signal too weak';
    }
  }

  
  Color getQualityColor(LocationQuality quality) {
    switch (quality) {
      case LocationQuality.excellent:
        return Colors.green;
      case LocationQuality.good:
        return Colors.lightGreen;
      case LocationQuality.fair:
        return Colors.orange;
      case LocationQuality.poor:
        return Colors.deepOrange;
      case LocationQuality.unusable:
        return Colors.red;
    }
  }

  
  Stream<Position> get positionStream => _locationController.stream;
  Stream<LocationQuality> get qualityStream => _qualityController.stream;
  Stream<String> get statusStream => _statusController.stream;

  
  LocationQuality get currentQuality => _currentQuality;
  Position? get lastPosition => _lastPosition;
  bool get isTracking => _isTracking;

  
  void setTrackingMode(TrackingMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      if (_isTracking) {
        
        _stopTracking();
        _startTracking();
      }
    }
  }

  
  Position _filterPosition(Position position) {
    if (_currentMode != TrackingMode.high_accuracy || _kalmanFilter == null) {
      return position;
    }

    
    _kalmanFilter!.predict(0.1); 
    _kalmanFilter!.update(position.latitude, position.longitude);

    final smoothedPosition = Position(
      longitude: _kalmanFilter!.x.y,
      latitude: _kalmanFilter!.x.x,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
    );

    return smoothedPosition;
  }

  
  void _startTracking() {
    if (_isTracking) return;

    final locationSettings = _getLocationSettings();

    _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings
    ).listen((Position position) {
      
      final quality = _assessLocationQuality(position);

      
      if (quality != LocationQuality.unusable) {
        
        final filteredPosition = _filterPosition(position);
        _lastPosition = filteredPosition;
        _locationController.add(filteredPosition);
      }

      
      if (quality != _currentQuality) {
        _currentQuality = quality;
        _qualityController.add(quality);
        _statusController.add(getQualityDescription(quality));
      }
    });

    _isTracking = true;
  }

  
  void _stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }

  
  Future<void> startQualityMonitoring() async {
    if (_isTracking) return;

    await _checkAndRequestPermission();
    _startTracking();
  }

  
  void stopQualityMonitoring() {
    _stopTracking();
  }

  
  void initializeKalmanFilter(Position position) {
    _kalmanFilter = KalmanFilter2D(
      initialX: position.latitude,
      initialY: position.longitude,
      
      processNoise: 1e-5,      
      measurementNoise: 15.0,   
    );
  }

  
  Future<bool> isAccuracyGoodForRun() async {
    if (_currentQuality == LocationQuality.unusable ||
        _currentQuality == LocationQuality.poor) {
      return false;
    }
    return true;
  }

  
  Future<bool> waitForGoodAccuracy({
    required Duration timeout,
    required Function(int, LocationQuality) onProgress
  }) async {
    if (!_isTracking) {
      await startQualityMonitoring();
    }

    
    if (_currentQuality == LocationQuality.good ||
        _currentQuality == LocationQuality.excellent) {
      return true;
    }

    
    final completer = Completer<bool>();

    
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    
    int secondsElapsed = 0;
    final progressTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      secondsElapsed++;
      onProgress(secondsElapsed, _currentQuality);
    });

    
    final subscription = _qualityController.stream.listen((quality) {
      if (quality == LocationQuality.good || quality == LocationQuality.excellent) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    
    final result = await completer.future;

    
    timer.cancel();
    progressTimer.cancel();
    subscription.cancel();

    return result;
  }

  
  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _statusController.add('Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _statusController.add('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _statusController.add('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      _statusController.add('Error getting location: $e');
      return null;
    }
  }

  
  Stream<Position> trackLocation() {
    if (!_isTracking) {
      startQualityMonitoring();
    }
    return positionStream;
  }

  
  void dispose() {
    _stopTracking();
    _locationController.close();
    _qualityController.close();
    _statusController.close();
  }
}
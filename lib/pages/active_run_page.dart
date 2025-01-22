import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'dart:async';
import '/services/location_service.dart';
import 'dart:math';

class ActiveRunPage extends StatefulWidget {
  const ActiveRunPage({Key? key}) : super(key: key);

  @override
  _ActiveRunPageState createState() => _ActiveRunPageState();
}

class _ActiveRunPageState extends State<ActiveRunPage> {
  final LocationService _locationService = LocationService();

  LocationData? _startLocation;
  LocationData? _currentLocation;
  double _distanceCovered = 0.0; 
  int _secondsElapsed = 0;
  Timer? _timer;

  bool _isTracking = false;

  
  bool _autoPaused = false;    
  int _stillCounter = 0;       

  
  
  
  final double _pauseThreshold = 0.5;   
  final double _resumeThreshold = 1.0;  

  @override
  void initState() {
    super.initState();
    _startRun();
  }

  
  void _startRun() async {
    final location = await _locationService.getCurrentLocation();
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to start tracking. Check location permissions."),
        ),
      );
      return;
    }

    setState(() {
      _startLocation = location;
      _isTracking = true;
      _secondsElapsed = 0;
      _distanceCovered = 0.0;
      _autoPaused = false;
    });

    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      
      if (!_autoPaused) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });

    
    _locationService.trackLocation().listen((newLocation) {
      if (!_isTracking) return; 

      final speed = (newLocation.speed ?? 0.0).clamp(0.0, double.infinity);
      _handleAutoPauseLogic(speed);

      if (_currentLocation != null && !_autoPaused) {
        final distance = _calculateDistance(
          _currentLocation!.latitude!,
          _currentLocation!.longitude!,
          newLocation.latitude!,
          newLocation.longitude!,
        );

        
        if (distance > 3.0) {
          setState(() {
            _distanceCovered += distance;
          });
        }
      }

      
      setState(() {
        _currentLocation = newLocation;
      });
    });
  }

  
  
  
  void _handleAutoPauseLogic(double speed) {
    if (_autoPaused) {
      
      if (speed > _resumeThreshold) {
        setState(() {
          _autoPaused = false;
          _stillCounter = 0; 
        });
      }
    } else {
      
      if (speed < _pauseThreshold) {
        _stillCounter++;
        if (_stillCounter >= 5) {
          
          setState(() {
            _autoPaused = true;
          });
        }
      } else {
        
        _stillCounter = 0;
      }
    }
  }

  
  double _calculateDistance(double startLat, double startLng,
      double endLat, double endLng) {
    const earthRadius = 6371000.0; 
    final dLat = (endLat - startLat) * (pi / 180);
    final dLng = (endLng - startLng) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(startLat * (pi / 180)) *
            cos(endLat * (pi / 180)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _endRun() {
    _timer?.cancel();
    _timer = null;

    setState(() {
      _isTracking = false;
    });
    _saveRunData();
  }

  Future<void> _saveRunData() async {
    debugPrint("Run ended. Distance covered: $_distanceCovered meters");
    
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _distanceCovered / 1000;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Run'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            Text('Time Elapsed: ${_formatTime(_secondsElapsed)}'),
            Text('Distance Covered: ${distanceKm.toStringAsFixed(2)} km'),
            
            const SizedBox(height: 8),
            if (_autoPaused)
              const Text(
                'Auto-Paused',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            const SizedBox(height: 16),

            
            ElevatedButton(
              onPressed: _endRun,
              child: const Text('End Run'),
            ),
          ],
        ),
      ),
    );
  }
}

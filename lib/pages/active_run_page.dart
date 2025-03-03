
import 'dart:async';
import 'dart:convert';
import 'dart:io'; 
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../mixins/run_tracking_mixin.dart';
import '../widgets/run_metrics_card.dart'; 

class ActiveRunPage extends StatefulWidget {
  final String journeyType;
  final int challengeId;

  const ActiveRunPage({
    Key? key,
    required this.journeyType,
    required this.challengeId,
  }) : super(key: key);

  @override
  ActiveRunPageState createState() => ActiveRunPageState();
}

class ActiveRunPageState extends State<ActiveRunPage> with RunTrackingMixin {
  bool _isInitializing = true; 
  int _locationAttempts = 0; 
  String _debugStatus = "Starting location services...";
  List<Position> _positionSamples = []; 
  Timer? _locationSamplingTimer; 

  
  final double _goodAccuracyThreshold = Platform.isIOS ? 65.0 : 20.0;
  final double _acceptableAccuracyThreshold = Platform.isIOS ? 100.0 : 40.0;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  
  bool _isValidAccuracy(double accuracy) {
    
    if (accuracy == 1440.0) return false;

    
    if (accuracy > 500.0) return false;

    return true;
  }

  
  Position _getBestPosition(List<Position> positions) {
    if (positions.isEmpty) throw Exception("No positions to choose from");

    
    final validPositions = positions.where((pos) => _isValidAccuracy(pos.accuracy)).toList();

    if (validPositions.isEmpty) {
      
      positions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
      return positions.first;
    }

    
    validPositions.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return validPositions.first;
  }

  
  Future<void> _initializeLocationTracking() async {
    setState(() {
      _isInitializing = true;
      _debugStatus = "Checking location services...";
      _positionSamples = [];
    });

    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() => _debugStatus = "Location services enabled: $serviceEnabled");

    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable them in Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _isInitializing = false);
      }
      return;
    }

    
    LocationPermission permission = await Geolocator.checkPermission();
    setState(() => _debugStatus = "Initial permission status: $permission");

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      
      setState(() => _debugStatus = "Requesting permission...");
      permission = await Geolocator.requestPermission();
      setState(() => _debugStatus = "After request, permission status: $permission");

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission was denied. Please enable it in Settings.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isInitializing = false);
        }
        return;
      }
    }

    
    _startLocationSampling();

    
    Timer(const Duration(seconds: 30), () {
      if (_isInitializing && mounted) {
        _locationSamplingTimer?.cancel();
        _evaluateAndStartRun(true); 
      }
    });
  }

  
  void _startLocationSampling() {
    _locationSamplingTimer?.cancel();

    
    final LocationSettings locationSettings = Platform.isIOS
        ? AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
    )
        : AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    setState(() => _debugStatus = "Collecting location samples...");

    
    StreamSubscription<Position>? subscription;

    
    _locationSamplingTimer = Timer(const Duration(seconds: 15), () {
      subscription?.cancel();
      if (mounted && _isInitializing) {
        _evaluateAndStartRun(false);
      }
    });

    
    subscription = Geolocator.getPositionStream(
        locationSettings: locationSettings
    ).listen(
            (position) {
          if (!mounted) {
            subscription?.cancel();
            return;
          }

          _locationAttempts++;
          setState(() {
            currentLocation = position;
            _debugStatus = "Sample #$_locationAttempts: ${position.accuracy.toStringAsFixed(1)}m";
          });

          
          if (_isValidAccuracy(position.accuracy)) {
            _positionSamples.add(position);
          }

          
          if (position.accuracy <= _goodAccuracyThreshold) {
            subscription?.cancel();
            _evaluateAndStartRun(false);
            return;
          }

          
          if (_positionSamples.length >= 5 || _locationAttempts >= 10) {
            subscription?.cancel();
            _evaluateAndStartRun(false);
            return;
          }
        },
        onError: (error) {
          setState(() => _debugStatus = "Location error: $error");
          
        }
    );
  }

  
  void _evaluateAndStartRun(bool forceStart) {
    if (!mounted || !_isInitializing) return;

    if (_positionSamples.isEmpty && currentLocation == null) {
      
      setState(() => _debugStatus = "No samples collected, trying direct method...");
      _tryDirectLocationAcquisition();
      return;
    }

    
    if (_positionSamples.isNotEmpty) {
      Position bestPosition = _getBestPosition(_positionSamples);
      setState(() => _debugStatus = "Best accuracy: ${bestPosition.accuracy.toStringAsFixed(1)}m");

      
      if (bestPosition.accuracy <= _acceptableAccuracyThreshold || forceStart) {
        _startRunWithPosition(bestPosition);
        return;
      }
    }

    
    if (currentLocation != null && (forceStart || _positionSamples.isEmpty)) {
      _startRunWithPosition(currentLocation!);
      return;
    }

    
    if (forceStart && currentLocation != null) {
      _startRunWithPosition(currentLocation!);
      return;
    }

    
    setState(() {
      _isInitializing = false;
      _debugStatus = "Could not get accurate location";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not get accurate location. Try again outdoors with clear sky view.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  
  void _tryDirectLocationAcquisition() async {
    try {
      setState(() => _debugStatus = "Trying direct location acquisition...");

      
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 15)
      );

      if (mounted) {
        setState(() {
          currentLocation = position;
          _debugStatus = "Direct method accuracy: ${position.accuracy.toStringAsFixed(1)}m";
        });

        
        if (_isValidAccuracy(position.accuracy) || _locationAttempts > 15) {
          _startRunWithPosition(position);
        } else {
          setState(() {
            _isInitializing = false;
            _debugStatus = "Could not get accurate location";
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS accuracy is poor. Try again in an open area.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _debugStatus = "Location error: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  
  void _startRunWithPosition(Position position) {
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _debugStatus = "Starting run!";
      });
      startRun(position);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Starting run with accuracy: ${position.accuracy.toStringAsFixed(1)}m'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  
  void _endRunAndSave() {
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot end run without a valid location')),
      );
      return;
    }
    endRun();
    _saveRunData();
  }

  Future<void> _saveRunData() async {
    final user = Provider.of<UserModel>(context, listen: false);
    if (user.id == 0 || startLocation == null || endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing required data to save run")),
      );
      return;
    }
    final distance = double.parse(distanceCovered.toStringAsFixed(2));
    final startTime =
    (startLocation!.timestamp ?? DateTime.now()).toUtc().toIso8601String();
    final endTime =
    (endLocation!.timestamp ?? DateTime.now()).toUtc().toIso8601String();
    final routeJson = routePoints
        .map((point) => {'latitude': point.latitude, 'longitude': point.longitude})
        .toList();

    final requestBody = {
      'user_id': user.id,
      'start_time': startTime,
      'end_time': endTime,
      'start_latitude': startLocation!.latitude,
      'start_longitude': startLocation!.longitude,
      'end_latitude': endLocation!.latitude,
      'end_longitude': endLocation!.longitude,
      'distance_covered': distance,
      'route': routeJson,
      'journey_type': widget.journeyType,
    };

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['SUPABASE_URL']}/functions/v1/create_user_contribution'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run saved successfully!')),
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(context, '/challenges');
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save run: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: ${e.toString()}")),
      );
    }
  }

  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _locationSamplingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Run')),
        body: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Waiting for GPS signal...',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                CircularProgressIndicator(
                  color: currentLocation != null ? Colors.green : Colors.white,
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _debugStatus,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                if (currentLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Location: ${currentLocation!.latitude.toStringAsFixed(6)}, ${currentLocation!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                if (currentLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Accuracy: ${currentLocation!.accuracy.toStringAsFixed(1)} meters',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                if (_positionSamples.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Samples collected: ${_positionSamples.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _locationAttempts = 0;
                    _positionSamples.clear();
                    _initializeLocationTracking(); 
                  },
                  child: const Text('Retry Location'),
                ),
                if (Platform.isIOS && currentLocation != null)
                  ElevatedButton(
                    onPressed: () {
                      
                      _startRunWithPosition(currentLocation!);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Force Start with Current Location'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final distanceKm = distanceCovered / 1000;
    return Scaffold(
      appBar: AppBar(title: const Text('Active Run')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLocation != null
                  ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
                  : const LatLng(37.4219999, -122.0840575),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: {routePolyline},
            onMapCreated: (controller) {
              mapController = controller;

              
              if (Platform.isIOS && currentLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(currentLocation!.latitude, currentLocation!.longitude),
                    15,
                  ),
                );
              }
            },
          ),
          
          Positioned(
            top: 20,
            left: 20,
            child: RunMetricsCard(
              time: _formatTime(secondsElapsed),
              distance: '${(distanceKm).toStringAsFixed(2)} km',
            ),
          ),
          
          if (autoPaused)
            const Positioned(
              top: 90,
              left: 20,
              child: Card(
                color: Colors.redAccent,
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Auto-Paused',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton(
        onPressed: _endRunAndSave,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text(
          'End Run',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart';
import '../mixins/run_tracking_mixin.dart';
import '../services/ios_location_bridge.dart';
import '../constants/app_constants.dart';






class DuoActiveRunPage extends StatefulWidget {
  
  final int challengeId;

  const DuoActiveRunPage({Key? key, required this.challengeId})
      : super(key: key);

  @override
  _DuoActiveRunPageState createState() => _DuoActiveRunPageState();
}

class _DuoActiveRunPageState extends State<DuoActiveRunPage>
    with RunTrackingMixin {
  
  Position? _partnerLocation;
  double _partnerDistance = 0.0;
  Timer? _partnerPollingTimer;
  StreamSubscription? _iosLocationSubscription;
  StreamSubscription<Position>? _customLocationSubscription;

  
  final List<LatLng> _partnerRoutePoints = [];
  Polyline _partnerRoutePolyline = const Polyline(
    polylineId: PolylineId('partner_route'),
    color: AppConstants.partnerRouteColor,
    width: 5,
    points: [],
  );

  
  bool _hasEnded = false;
  bool _isRunning = true;
  bool _isInitializing = true;

  
  final Map<CircleId, Circle> _circles = {};

  final supabase = Supabase.instance.client;

  
  final IOSLocationBridge _iosBridge = IOSLocationBridge();

  @override
  void initState() {
    super.initState();

    
    if (Platform.isIOS) {
      _initializeIOSLocationBridge();
    }

    _initializeRun();
    _startPartnerPolling();
  }

  
  Future<void> _initializeIOSLocationBridge() async {
    await _iosBridge.initialize();
    await _iosBridge.startBackgroundLocationUpdates();

    _iosLocationSubscription = _iosBridge.locationStream.listen((position) {
      if (!mounted || _hasEnded) return;

      if (currentLocation == null ||
          position.accuracy < currentLocation!.accuracy) {
        setState(() {
          currentLocation = position;
        });

        _updateDuoWaitingRoom(position);
        _addSelfCircle(position);
      }
    });
  }

  
  void _setupCustomLocationHandling() {
    _customLocationSubscription = locationService.trackLocation().listen((position) {
      if (!isTracking || _hasEnded) return;

      final currentPoint = LatLng(position.latitude, position.longitude);

      
      if (lastRecordedLocation != null) {
        
        final segmentDistance = calculateDistance(
          lastRecordedLocation!.latitude,
          lastRecordedLocation!.longitude,
          currentPoint.latitude,
          currentPoint.longitude,
        );

        
        final speed = position.speed >= 0 ? position.speed : 0.0;
        if (autoPaused) {
          if (speed > AppConstants.kResumeThreshold) {
            setState(() {
              autoPaused = false;
              stillCounter = 0;
            });
          }
        } else {
          if (speed < AppConstants.kPauseThreshold) {
            stillCounter++;
            if (stillCounter >= 5) {
              setState(() => autoPaused = true);
            }
          } else {
            stillCounter = 0;
          }
        }

        
        if (!autoPaused && segmentDistance > 17) {
          setState(() {
            distanceCovered += segmentDistance;
            lastRecordedLocation = currentPoint;
          });
        }
      } else {
        
        setState(() {
          lastRecordedLocation = currentPoint;
        });
      }

      
      setState(() {
        currentLocation = position;
        routePoints.add(currentPoint);
        routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          color: AppConstants.selfRouteColor,
          width: 5,
          points: routePoints,
        );
      });

      
      _updateDuoWaitingRoom(position);

      
      mapController?.animateCamera(CameraUpdate.newLatLng(currentPoint));
    });
  }


  
  void _startPartnerPolling() {
    _partnerPollingTimer?.cancel();
    _partnerPollingTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
          if (!mounted || _hasEnded) {
            timer.cancel();
            return;
          }
          await _pollPartnerStatus();
        });
  }

  
  String _getDistanceGroup(double distance) {
    if (distance < 100) return "<100";
    if (distance < 200) return "100+";
    if (distance < 300) return "200+";
    if (distance < 400) return "300+";
    if (distance < 500) return "400+";
    return "500+";
  }

  
  
  void _addSelfCircle(Position position) {
    
    
  }

  
  void _addPartnerCircle(Position position) {
    final circleId = CircleId('partner');
    final circle = Circle(
      circleId: circleId,
      center: LatLng(position.latitude, position.longitude),
      radius: 15, 
      fillColor: Colors.green.withOpacity(0.5), 
      strokeColor: Colors.white, 
      strokeWidth: 2,
    );

    setState(() {
      _circles[circleId] = circle;

      
      final partnerPoint = LatLng(position.latitude, position.longitude);
      if (_partnerRoutePoints.isEmpty ||
          _partnerRoutePoints.last != partnerPoint) {
        _partnerRoutePoints.add(partnerPoint);
        _partnerRoutePolyline = Polyline(
          polylineId: const PolylineId('partner_route'),
          color: AppConstants.partnerRouteColor,
          width: 5,
          points: _partnerRoutePoints,
        );
      }
    });
  }

  
  Future<void> _updateDuoWaitingRoom(Position position) async {
    if (_hasEnded) return;

    final user = Provider.of<UserModel>(context, listen: false);
    try {
      await supabase
          .from('duo_waiting_room')
          .update({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'last_update': DateTime.now().toIso8601String(),
      })
          .match({
        'team_challenge_id': widget.challengeId,
        'user_id': user.id,
      });
    } catch (e) {
      debugPrint('Error updating duo waiting room: $e');
    }
  }

  
  
  
  
  
  Future<void> _pollPartnerStatus() async {
    if (currentLocation == null || !mounted) return;
    try {
      final user = Provider.of<UserModel>(context, listen: false);
      final results = await supabase
          .from('duo_waiting_room')
          .select('has_ended, current_latitude, current_longitude')
          .eq('team_challenge_id', widget.challengeId)
          .neq('user_id', user.id);

      if (!mounted) return;
      if (results is List && results.isNotEmpty) {
        final data = results.first as Map<String, dynamic>;
        
        if (data['has_ended'] == true) {
          await _endRunDueToPartner();
          return;
        }
        final partnerLat = data['current_latitude'] as num;
        final partnerLng = data['current_longitude'] as num;
        final calculatedDistance = Geolocator.distanceBetween(
          currentLocation!.latitude,
          currentLocation!.longitude,
          partnerLat.toDouble(),
          partnerLng.toDouble(),
        );

        
        final partnerPosition = Position(
          latitude: partnerLat.toDouble(),
          longitude: partnerLng.toDouble(),
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          floor: null,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        
        _addPartnerCircle(partnerPosition);

        setState(() {
          _partnerDistance = calculatedDistance;
          _partnerLocation = partnerPosition;
        });

        if (calculatedDistance > AppConstants.kMaxAllowedDistance && !_hasEnded) {
          await supabase.from('duo_waiting_room').update({
            'has_ended': true,
          }).match({
            'team_challenge_id': widget.challengeId,
            'user_id': user.id,
          });
          await _handleMaxDistanceExceeded();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error in partner polling: $e. Challenge ID: ${widget.challengeId}');
    }
  }

  
  Future<void> _endRunDueToPartner() async {
    await _endRun(
      reason: 'partner_ended',
      notifyPartner: false,
      message: "Your teammate has ended the run. Run completed.",
    );
  }

  
  Future<void> _initializeRun() async {
    try {
      final initialPosition = await locationService.getCurrentLocation();
      if (initialPosition != null && mounted) {
        setState(() {
          currentLocation = initialPosition;
          _isInitializing = false;
        });

        
        _updateDuoWaitingRoom(initialPosition);

        
        startRun(initialPosition);

        
        _setupCustomLocationHandling();
      }

      
      Timer(const Duration(seconds: 30), () {
        if (_isInitializing && mounted && currentLocation != null) {
          setState(() {
            _isInitializing = false;
          });
          startRun(currentLocation!);
          _setupCustomLocationHandling();
        }
      });
    } catch (e) {
      debugPrint('Error initializing run: $e');
    }
  }

  
  Future<void> _handleMaxDistanceExceeded() async {
    await _endRun(
      reason: 'max_distance_exceeded',
      notifyPartner: false,
      message: "Distance between teammates exceeded 500m. The run has ended.",
    );

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Run Ended'),
            content: const Text(
                'Distance between teammates exceeded 500m. The run has ended.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  
  Future<void> _endRunManually() async {
    await _endRun(
      reason: 'manual',
      notifyPartner: true,
      message: "Run ended successfully. Your teammate will be notified.",
    );
  }

  
  
  
  
  
  
  
  
  
  
  Future<void> _endRun({
    required String reason,
    bool notifyPartner = false,
    String? message,
  }) async {
    if (_hasEnded) return;

    final user = Provider.of<UserModel>(context, listen: false);

    try {
      
      _hasEnded = true;
      isTracking = false;

      
      runTimer?.cancel();
      locationSubscription?.cancel();
      _customLocationSubscription?.cancel();
      _partnerPollingTimer?.cancel();

      
      if (Platform.isIOS) {
        _iosLocationSubscription?.cancel();
        await _iosBridge.stopBackgroundLocationUpdates();
      }

      
      await _saveRunData();

      
      final updatePromises = [
        supabase.from('user_contributions').update({
          'active': false,
        }).match({
          'team_challenge_id': widget.challengeId,
          'user_id': user.id,
        })
      ];

      if (notifyPartner) {
        updatePromises.add(
            supabase.from('duo_waiting_room').update({
              'has_ended': true,
            }).match({
              'team_challenge_id': widget.challengeId,
              'user_id': user.id,
            })
        );
      }

      await Future.wait(updatePromises);

      
      if (mounted) {
        setState(() => _isRunning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? "Run ended."),
            duration: AppConstants.kDefaultSnackbarDuration,
          ),
        );
        await Future.delayed(AppConstants.kNavigationDelay);
        Navigator.pushReplacementNamed(context, '/challenges');
      }
    } catch (e) {
      debugPrint('Error ending run ($reason): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error ending run. Please try again.")),
        );
      }
    }
  }

  
  Future<void> _saveRunData() async {
    try {
      final user = Provider.of<UserModel>(context, listen: false);
      if (user.id == 0 || startLocation == null || currentLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Missing required data to save run")),
          );
        }
        return;
      }

      final distance = double.parse(distanceCovered.toStringAsFixed(2));
      final startTime = (startLocation!.timestamp ??
          DateTime.now().subtract(Duration(seconds: secondsElapsed)))
          .toUtc()
          .toIso8601String();
      final endTime = DateTime.now().toUtc().toIso8601String();
      final routeJson = routePoints
          .map((point) => {'latitude': point.latitude, 'longitude': point.longitude})
          .toList();

      final requestBody = jsonEncode({
        'user_id': user.id,
        'start_time': startTime,
        'end_time': endTime,
        'start_latitude': startLocation!.latitude,
        'start_longitude': startLocation!.longitude,
        'end_latitude': currentLocation!.latitude,
        'end_longitude': currentLocation!.longitude,
        'distance_covered': distance,
        'route': routeJson,
        'journey_type': 'duo',
      });

      final response = await http.post(
        Uri.parse('${dotenv.env['SUPABASE_URL']}/functions/v1/create_user_contribution'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: requestBody,
      );

      if (response.statusCode != 201 && mounted) {
        throw Exception("Failed to save run: ${response.body}");
      }
    } catch (e) {
      debugPrint('Error saving run data: $e. Challenge ID: ${widget.challengeId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: ${e.toString()}")),
        );
      }
    }
  }

  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    isTracking = false;
    _hasEnded = true;
    runTimer?.cancel();
    locationSubscription?.cancel();
    _customLocationSubscription?.cancel();
    _partnerPollingTimer?.cancel();

    
    if (Platform.isIOS) {
      _iosLocationSubscription?.cancel();
      _iosBridge.dispose();
    }

    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildInitializingScreen();
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMap(),
          _buildRunMetricsCard(),
          _buildPartnerDistanceCard(),
          if (autoPaused) _buildAutoPausedIndicator(),
          _buildEndRunButton(),
        ],
      ),
    );
  }

  
  Widget _buildInitializingScreen() {
    return Scaffold(
      body: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Waiting for GPS signal...',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(
                color: currentLocation != null ? Colors.green : Colors.white,
              ),
              if (currentLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Accuracy: ${currentLocation!.accuracy.toStringAsFixed(1)} meters',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Duo Active Run'),
      actions: [
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: _endRunManually,
        ),
      ],
    );
  }

  
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: currentLocation != null
            ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
            : const LatLng(37.4219999, -122.0840575),
        zoom: 16,
      ),
      myLocationEnabled: true, 
      myLocationButtonEnabled: true,
      polylines: {routePolyline, _partnerRoutePolyline},
      circles: Set<Circle>.of(_circles.values),
      onMapCreated: (controller) => mapController = controller,
    );
  }

  
  Widget _buildRunMetricsCard() {
    final distanceKm = distanceCovered / 1000;

    return Positioned(
      top: AppConstants.kMapMarginTop,
      left: AppConstants.kMapMarginSide,
      child: Card(
        color: Colors.white.withOpacity(0.9),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.kCardPadding),
          child: Column(
            children: [
              Text(
                'Time: ${_formatTime(secondsElapsed)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Distance: ${distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
  Widget _buildPartnerDistanceCard() {
    return Positioned(
      top: AppConstants.kMapMarginTop,
      right: AppConstants.kMapMarginSide,
      child: Card(
        color: Colors.lightBlueAccent.withOpacity(0.9),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.kCardPadding),
          child: Text(
            'Partner Distance: ${_getDistanceGroup(_partnerDistance)} m',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  
  Widget _buildAutoPausedIndicator() {
    return Positioned(
      top: 90,
      left: AppConstants.kMapMarginSide,
      child: Card(
        color: Colors.redAccent.withOpacity(0.8),
        child: Padding(
          padding: EdgeInsets.all(AppConstants.kCardPadding),
          child: const Text(
            'Auto-Paused',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  
  Widget _buildEndRunButton() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton(
          onPressed: _endRunManually,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'End Run',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
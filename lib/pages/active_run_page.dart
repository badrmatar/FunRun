// lib/pages/active_run_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import '../mixins/run_tracking_mixin.dart';
import '../widgets/run_metrics_card.dart'; // Import the reusable metrics card widget

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
  @override
  void initState() {
    super.initState();
    // Request an initial location and then start the run.
    locationService.getCurrentLocation().then((position) {
      if (position != null && mounted) {
        setState(() {
          currentLocation = position;
        });
        // For example, start the run when the accuracy is good enough:
        if (position.accuracy < 20) {
          startRun(position);
        }
      }
    });

    // Fallback timer in case initialization takes too long.
    Timer(const Duration(seconds: 30), () {
      if (currentLocation != null && mounted && !isTracking) {
        startRun(currentLocation!);
      }
    });
  }

  /// Called when the user taps the "End Run" button.
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
        // Navigate after a delay.
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

  /// Formats seconds into a mm:ss string.
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = distanceCovered / 1000;
    return Scaffold(
      appBar: AppBar(title: const Text('Active Run')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLocation != null
                  ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
                  : const LatLng(0, 0),
              // Default will be immediately replaced when location is available
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            polylines: {routePolyline},
            onMapCreated: (controller) {
              mapController = controller;
              // Immediately move to current location if available
              if (currentLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(currentLocation!.latitude, currentLocation!.longitude),
                      zoom: 16,
                    ),
                  ),
                );
              }
            },
          ),
          // Use the reusable RunMetricsCard widget.
          Positioned(
            top: 20,
            left: 20,
            child: RunMetricsCard(
              time: _formatTime(secondsElapsed),
              distance: '${(distanceKm).toStringAsFixed(2)} km',
            ),
          ),
          // Auto-Paused indicator (kept inline for now)
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
          // Location status indicator
          if (currentLocation == null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Waiting for GPS signal...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          // Debug information card (can be removed in production)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black.withOpacity(0.7),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS Status: ${currentLocation != null ? "Active" : "Searching..."}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (currentLocation != null)
                      Text(
                        'Accuracy: ${currentLocation!.accuracy.toStringAsFixed(1)}m',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    if (currentLocation != null)
                      Text(
                        'Speed: ${(currentLocation!.speed * 3.6).toStringAsFixed(1)} km/h',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    Text(
                      'Points: ${routePoints.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Center the button at the bottom
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

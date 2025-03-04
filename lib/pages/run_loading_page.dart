import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import 'active_run_page.dart';

class RunLoadingPage extends StatefulWidget {
  final String journeyType;
  final int challengeId;

  const RunLoadingPage({
    Key? key,
    required this.journeyType,
    required this.challengeId,
  }) : super(key: key);

  @override
  _RunLoadingPageState createState() => _RunLoadingPageState();
}

class _RunLoadingPageState extends State<RunLoadingPage> {
  final LocationService _locationService = LocationService();

  bool _isWaitingForSignal = true;
  bool _hasGoodSignal = false;
  int _elapsedSeconds = 0;
  int _maxWaitSeconds = 30; 
  String _statusMessage = "Acquiring GPS signal...";
  LocationQuality _currentQuality = LocationQuality.unusable;
  Position? _bestPosition;
  double _signalQualityPercentage = 0;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  Future<void> _initializeLocationTracking() async {
    
    final initialPosition = await _locationService.getCurrentLocation();
    if (initialPosition != null) {
      setState(() {
        _bestPosition = initialPosition;
        _currentQuality = _locationService.currentQuality;
        _updateSignalQuality(_currentQuality);
      });

      
      _locationService.initializeKalmanFilter(initialPosition);

      
      _locationService.startQualityMonitoring();

      
      _waitForAccuracy();
    } else {
      setState(() {
        _statusMessage = "Unable to get initial location";
        _isWaitingForSignal = false;
      });
    }
  }

  void _updateSignalQuality(LocationQuality quality) {
    switch (quality) {
      case LocationQuality.excellent:
        _signalQualityPercentage = 1.0;
        break;
      case LocationQuality.good:
        _signalQualityPercentage = 0.75;
        break;
      case LocationQuality.fair:
        _signalQualityPercentage = 0.5;
        break;
      case LocationQuality.poor:
        _signalQualityPercentage = 0.25;
        break;
      case LocationQuality.unusable:
        _signalQualityPercentage = 0.1;
        break;
    }
  }

  Future<void> _waitForAccuracy() async {
    final result = await _locationService.waitForGoodAccuracy(
        timeout: Duration(seconds: _maxWaitSeconds),
        onProgress: (seconds, quality) {
          if (mounted) {
            setState(() {
              _elapsedSeconds = seconds;
              _currentQuality = quality;
              _updateSignalQuality(quality);
              _statusMessage = _locationService.getQualityDescription(quality);

              
              if (_locationService.lastPosition != null) {
                _bestPosition = _locationService.lastPosition;
              }
            });
          }
        }
    );

    if (mounted) {
      setState(() {
        _isWaitingForSignal = false;
        _hasGoodSignal = result;

        if (result) {
          _statusMessage = "GPS signal acquired! Ready to start.";
        } else {
          _statusMessage = "Unable to get a good GPS signal. Try moving to an open area.";
        }
      });
    }
  }

  void _startRun() {
    if (_bestPosition == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ActiveRunPage(
          initialPosition: _bestPosition!,
          journeyType: widget.journeyType,
          challengeId: widget.challengeId,
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _locationService.stopQualityMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('GPS Signal Check'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[900],
                boxShadow: [
                  BoxShadow(
                    color: _locationService.getQualityColor(_currentQuality).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      size: 48,
                      color: _locationService.getQualityColor(_currentQuality),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isWaitingForSignal
                          ? "${_elapsedSeconds}s / ${_maxWaitSeconds}s"
                          : _hasGoodSignal ? "Ready!" : "Signal Issue",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      width: 120,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey[800],
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _signalQualityPercentage,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _locationService.getQualityColor(_currentQuality),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            if (_bestPosition != null) ...[
              const SizedBox(height: 16),
              Text(
                'Accuracy: ${_bestPosition!.accuracy.toStringAsFixed(1)}m',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 48),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                ElevatedButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                
                ElevatedButton.icon(
                  onPressed: (!_isWaitingForSignal && (_hasGoodSignal || _elapsedSeconds >= _maxWaitSeconds))
                      ? _startRun
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Run'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
            if (!_isWaitingForSignal && !_hasGoodSignal) ...[
              const SizedBox(height: 24),
              const Text(
                'Tip: Move to an open area away from buildings or trees for better GPS signal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
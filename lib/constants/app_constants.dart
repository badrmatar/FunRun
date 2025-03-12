import 'package:flutter/material.dart';

class AppConstants {
  
  static const double kMaxAllowedDistance = 500.0; 
  static const double kPauseThreshold = 0.5; 
  static const double kResumeThreshold = 1.0; 

  
  static const Color partnerRouteColor = Colors.green;
  static const Color selfRouteColor = Colors.orange;

  
  static const double kCardPadding = 8.0;
  static const double kMapMarginTop = 20.0;
  static const double kMapMarginSide = 20.0;
  static const Duration kDefaultSnackbarDuration = Duration(seconds: 3);
  static const Duration kNavigationDelay = Duration(seconds: 2);
}
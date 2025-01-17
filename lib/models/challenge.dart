import 'package:json_annotation/json_annotation.dart';

part 'challenge.g.dart'; 

@JsonSerializable()
class Challenge {
  @JsonKey(name: 'challenge_id') 
  final int challengeId;

  @JsonKey(name: 'start_time') 
  final DateTime startTime;

  final int? duration; 

  @JsonKey(name: 'earning_points') 
  final int? earningPoints; 

  final String difficulty; 

  final int? length; 

  Challenge({
    required this.challengeId,
    required this.startTime,
    this.duration,
    this.earningPoints,
    required this.difficulty,
    this.length,
  });

  
  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);

  
  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}

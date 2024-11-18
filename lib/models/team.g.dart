

part of 'team.dart';





Team _$TeamFromJson(Map<String, dynamic> json) => Team(
      teamId: (json['teamId'] as num).toInt(),
      teamName: json['teamName'] as String,
    );

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
      'teamId': instance.teamId,
      'teamName': instance.teamName,
    };

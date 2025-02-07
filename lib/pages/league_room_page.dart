

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LeagueRoomPage extends StatefulWidget {
  final int userId;

  const LeagueRoomPage({Key? key, required this.userId}) : super(key: key);

  @override
  _LeagueRoomPageState createState() => _LeagueRoomPageState();
}

class _LeagueRoomPageState extends State<LeagueRoomPage> {
  bool _isLoading = true;
  int? _leagueRoomId;
  String? _leagueRoomName;
  List<Map<String, dynamic>> _leagueTeams = [];
  int? _ownerId;

  @override
  void initState() {
    super.initState();
    _fetchLeagueRoomData();
  }

  
  String _getCleanTeamName(String teamName) {
    final regex = RegExp(r'^(.*?)(?:\s*\d+)?$');
    final match = regex.firstMatch(teamName);
    return match != null ? match.group(1)?.trim() ?? teamName : teamName;
  }

  Future<void> _fetchLeagueRoomData() async {
    setState(() => _isLoading = true);

    try {
      print('Debug: Fetching league room for userId ${widget.userId}');
      final leagueRoomId = await _getLeagueRoomId(widget.userId);

      if (leagueRoomId == null) {
        setState(() {
          _isLoading = false;
          _leagueRoomId = null;
        });
        return;
      }

      print('Debug: Found league room ID: $leagueRoomId');

      
      final pointsResponse = await http.post(
        Uri.parse('${dotenv.env['SUPABASE_URL']}/functions/v1/get_team_points'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode({'league_room_id': leagueRoomId}),
      );

      
      final membersResponse = await http.post(
        Uri.parse('${dotenv.env['SUPABASE_URL']}/functions/v1/get_league_teams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode({'league_room_id': leagueRoomId}),
      );

      print('Points response: ${pointsResponse.body}');
      print('Members response: ${membersResponse.body}');

      if (pointsResponse.statusCode == 200 && membersResponse.statusCode == 200) {
        final pointsData = jsonDecode(pointsResponse.body);
        final membersData = jsonDecode(membersResponse.body);

        print('Points data: $pointsData');
        print('Members data: $membersData');

        
        final pointsList = List<Map<String, dynamic>>.from(pointsData['data'] ?? []);
        final membersList = List<Map<String, dynamic>>.from(membersData['teams'] ?? []);

        List<Map<String, dynamic>> teamsWithPoints = [];

        
        if (pointsList.isEmpty) {
          teamsWithPoints = membersList.map((team) {
            return {
              ...team,
              'total_points': 0,
              'completed_challenges': 0,
            };
          }).toList();
        } else {
          teamsWithPoints = pointsList.map((pointsTeam) {
            
            final memberTeam = membersList.firstWhere(
                  (memberTeam) => memberTeam['team_id'] == pointsTeam['team_id'],
              orElse: () => {'members': []},
            );
            return {
              ...pointsTeam,
              'members': memberTeam['members'] ?? [],
            };
          }).toList();
        }

        setState(() {
          _leagueRoomId = leagueRoomId;
          _leagueRoomName = "League Room $leagueRoomId";
          _leagueTeams = teamsWithPoints;
          _isLoading = false;
          _ownerId = membersData['owner_id'];
        });
      } else {
        print('Error in responses:');
        print('Points status: ${pointsResponse.statusCode}');
        print('Members status: ${membersResponse.statusCode}');
        throw Exception('Failed to fetch team data');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Debug: Exception in _fetchLeagueRoomData: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching league room data: $e')),
        );
      }
    }
  }

  Future<int?> _getLeagueRoomId(int userId) async {
    final url = '${dotenv.env['SUPABASE_URL']}/functions/v1/get_active_league_room_id';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']!}',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Debug: League room response: $data');
        return data['league_room_id'] as int?;
      } else {
        print('Error: API returned ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Exception in _getLeagueRoomId: $e');
      return null;
    }
  }

  Future<void> _handleEndLeague() async {
    if (_leagueRoomId == null) return;

    setState(() => _isLoading = true);

    final url = '${dotenv.env['SUPABASE_URL']}/functions/v1/end_league_room';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode({
          'league_room_id': _leagueRoomId,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('League ended successfully!')),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['error'] ?? 'Failed to end league')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending league: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("League Room"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leagueRoomId == null
          ? const Center(
        child: Text(
          "No active league room found.",
          style: TextStyle(fontSize: 18),
        ),
      )
          : _buildLeagueRoomDetails(),
    );
  }

  Widget _buildLeagueRoomDetails() {
    
    final bool isOwner = _ownerId == widget.userId;
    
    _leagueTeams.sort((a, b) => (b['total_points'] ?? 0).compareTo(a['total_points'] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            _leagueRoomName ?? "League Room",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const SizedBox(width: 32), 
              Expanded(
                flex: 3,
                child: Text(
                  "TEAM",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "CHAL",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "PTS",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: ListView.builder(
            itemCount: _leagueTeams.length,
            padding: const EdgeInsets.only(top: 4),
            itemBuilder: (context, index) {
              final team = _leagueTeams[index];
              final bool isTopThree = index < 3;
              
              final members = (team['members'] as List?)
                  ?.map((m) => m['users']?['name']?.toString() ?? '')
                  .where((name) => name.isNotEmpty)
                  .toList() ?? [];
              final memberNames = members.join(', ');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      Row(
                        children: [
                          
                          SizedBox(
                            width: 32,
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isTopThree ? Colors.black : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          
                          Expanded(
                            flex: 3,
                            child: Text(
                              _getCleanTeamName(team['team_name'] ?? ''),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isTopThree ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          
                          Expanded(
                            child: Center(
                              child: Text(
                                "${team['completed_challenges'] ?? 0}",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          
                          Expanded(
                            child: Center(
                              child: Text(
                                "${team['total_points'] ?? 0}",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isTopThree ? Colors.amber.shade700 : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (memberNames.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 32),
                          child: Text(
                            memberNames,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        if (isOwner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Center(
              child: ElevatedButton(
                onPressed: _handleEndLeague,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'End League',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/challenge.dart';
import '../models/user.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({Key? key}) : super(key: key);

  @override
  _ChallengesPageState createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  late Future<Map<String, dynamic>> _challengesData;

  @override
  void initState() {
    super.initState();
    _challengesData = _fetchChallengesAndTeamStatus();
  }

  String _getTimeRemaining(DateTime startTime, int? duration) {
    if (duration == null) return 'N/A';

    final endTime = startTime.add(Duration(minutes: duration));
    final now = DateTime.now().toUtc();

    if (now.isAfter(endTime)) {
      return 'Expired';
    }

    final remaining = endTime.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Future<Map<String, dynamic>> _fetchChallengesAndTeamStatus() async {
    final supabase = Supabase.instance.client;
    final user = Provider.of<UserModel>(context, listen: false);
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      
      final challengesResponse = await supabase
          .from('challenges')
          .select()
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String());

      
      final teamMembershipResponse = await supabase
          .from('team_memberships')
          .select('team_id, teams(team_name)')
          .eq('user_id', user.id)
          .filter('date_left', 'is', null)
          .limit(1)
          .single();

      if (teamMembershipResponse == null) {
        throw Exception('No active team membership found');
      }

      final teamId = teamMembershipResponse['team_id'];

      
      final activeTeamChallenges = await supabase
          .from('team_challenges')
          .select('''
            *,
            user_contributions (
              distance_covered
            )
          ''')
          .eq('team_id', teamId)
          .eq('iscompleted', false)
          .order('team_challenge_id', ascending: false);

      
      final teamChallengesWithDistance = activeTeamChallenges.map((tc) {
        final contributions = tc['user_contributions'] as List;
        final totalDistance = contributions.fold<double>(
          0,
              (sum, contrib) => sum + (contrib['distance_covered'] ?? 0),
        );
        return {...tc, 'total_distance': totalDistance};
      }).toList();

      debugPrint('Found ${challengesResponse.length} challenges for today');
      debugPrint('Team ID: $teamId');
      debugPrint('Active team challenges: ${teamChallengesWithDistance.length}');

      return {
        'challenges': challengesResponse,
        'teamId': teamId,
        'activeTeamChallenge': teamChallengesWithDistance.isNotEmpty
            ? teamChallengesWithDistance.first
            : null,
      };
    } catch (e) {
      debugPrint('Error fetching challenges and team status: $e');
      rethrow;
    }
  }

  Future<void> _handleChallengeAction(Challenge challenge, dynamic activeTeamChallenge, BuildContext context) async {
    if (activeTeamChallenge != null) {
      
      Navigator.pushNamed(context, '/active_run');
      return;
    }

    
    await _assignChallengeToTeam(challenge.challengeId, context);
  }

  Future<void> _assignChallengeToTeam(int challengeId, BuildContext context) async {
    final user = Provider.of<UserModel>(context, listen: false);
    final url = '${dotenv.env['SUPABASE_URL']}/functions/v1/assign_challenge_to_team';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['BEARER_TOKEN']}',
        },
        body: jsonEncode({
          'user_id': user.id,
          'challenge_id': challengeId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _challengesData = _fetchChallengesAndTeamStatus();
        });
        Navigator.pushNamed(context, '/active_run');
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['error'] ?? 'Failed to start challenge')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Challenges")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _challengesData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData ||
              (snapshot.data!['challenges'] as List).isEmpty) {
            return const Center(child: Text('No challenges found for today.'));
          }

          final data = snapshot.data!;
          final challenges = (data['challenges'] as List)
              .map((item) => Challenge.fromJson(item))
              .toList();
          final activeTeamChallenge = data['activeTeamChallenge'];

          return ListView.builder(
            itemCount: challenges.length,
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              final isActiveChallenge = activeTeamChallenge != null &&
                  activeTeamChallenge['challenge_id'] == challenge.challengeId;
              final totalDistance = isActiveChallenge
                  ? (activeTeamChallenge['total_distance'] as double) / 1000 
                  : 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Challenge #${challenge.challengeId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isActiveChallenge)
                        Text(
                          '${totalDistance.toStringAsFixed(2)} km',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: challenge.difficulty.toLowerCase() == 'easy'
                              ? Colors.lightBlue.shade100
                              : challenge.difficulty.toLowerCase() == 'medium'
                              ? Colors.yellow.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Difficulty: ${challenge.difficulty}',
                          style: TextStyle(
                            color: challenge.difficulty.toLowerCase() == 'easy'
                                ? Colors.blue.shade900
                                : challenge.difficulty.toLowerCase() == 'medium'
                                ? Colors.yellow.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Points: ${challenge.earningPoints}'),
                      Text('Time Remaining: ${_getTimeRemaining(challenge.startTime, challenge.duration)}'),
                      Text(challenge.formattedDistance),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: activeTeamChallenge != null && !isActiveChallenge
                        ? null  
                        : () => _handleChallengeAction(challenge, activeTeamChallenge, context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActiveChallenge ? Colors.lightGreen : null,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      isActiveChallenge ? 'Continue Run' : 'Start Run',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../models/challenge.dart';

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final dynamic activeTeamChallenge;
  final dynamic completedTeamChallenge;
  final bool hasChallengeToday;
  final Function(Challenge, dynamic, dynamic, bool, BuildContext) onPressed;

  const ChallengeCard({
    Key? key,
    required this.challenge,
    this.activeTeamChallenge,
    this.completedTeamChallenge,
    this.hasChallengeToday = false,
    required this.onPressed,
  }) : super(key: key);

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.lightBlue.shade100;
      case 'medium':
        return Colors.yellow.shade100;
      case 'hard':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade400;
    }
  }

  String _getTimeRemaining(DateTime startTime, int? duration) {
    if (duration == null) return 'N/A';
    final endTime = startTime.add(Duration(minutes: duration));
    final now = DateTime.now().toUtc();
    if (now.isAfter(endTime)) return 'Expired';
    final remaining = endTime.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final isActiveChallenge = activeTeamChallenge != null &&
        activeTeamChallenge['challenge_id'] == challenge.challengeId;

    final isCompletedChallenge = completedTeamChallenge != null &&
        completedTeamChallenge['challenge_id'] == challenge.challengeId;

    // Determine if button should be disabled
    final bool disableButton = (activeTeamChallenge != null && !isActiveChallenge) ||
        (completedTeamChallenge != null && !isCompletedChallenge) ||
        (hasChallengeToday && !isActiveChallenge && !isCompletedChallenge);

    final totalDistance = isActiveChallenge
        ? (((activeTeamChallenge['total_distance'] as num?)?.toDouble()) ?? 0.0) / 1000
        : isCompletedChallenge
        ? (((completedTeamChallenge['total_distance'] as num?)?.toDouble()) ?? 0.0) / 1000
        : 0.0;

    final duoDistance = isActiveChallenge
        ? (((activeTeamChallenge['duo_distance'] as num?)?.toDouble()) ?? 0.0) / 1000
        : isCompletedChallenge
        ? (((completedTeamChallenge['duo_distance'] as num?)?.toDouble()) ?? 0.0) / 1000
        : 0.0;

    final multiplier = isActiveChallenge
        ? ((activeTeamChallenge['multiplier'] as num?)?.toInt() ?? 1)
        : isCompletedChallenge
        ? ((completedTeamChallenge['multiplier'] as num?)?.toInt() ?? 1)
        : 1;

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Challenge #${challenge.challengeId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            if (isActiveChallenge || isCompletedChallenge)
              Text(
                '${totalDistance.toStringAsFixed(2)} km',
                style: TextStyle(
                  color: isCompletedChallenge ? Colors.green[400] : Colors.blue[400],
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
                color: _getDifficultyColor(challenge.difficulty),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Difficulty: ${challenge.difficulty}',
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Points: ${challenge.earningPoints}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Time Remaining: ${_getTimeRemaining(challenge.startTime, challenge.duration)}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              challenge.formattedDistance,
              style: const TextStyle(color: Colors.white70),
            ),
            if (isActiveChallenge || isCompletedChallenge)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Duo: ${duoDistance.toStringAsFixed(2)} km | Multiplier: $multiplier',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            if (isCompletedChallenge)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Status: Completed',
                  style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: disableButton
              ? null
              : () => onPressed(challenge, activeTeamChallenge, completedTeamChallenge, hasChallengeToday, context),
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompletedChallenge
                ? Colors.green
                : isActiveChallenge
                ? Colors.lightGreen
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(
            isCompletedChallenge
                ? 'Completed'
                : isActiveChallenge
                ? 'Continue Run'
                : 'Start Run',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
import 'dart:math' as math;

import '../models/activity.dart';
import '../models/archery_models.dart';
import '../repositories/archery_repository.dart';

enum ActivityStatsSnapshotKind { latest, monthly, overall }

class ActivityStatsService {
  const ActivityStatsService({required ArcheryRepository repository})
    : _repository = repository;

  final ArcheryRepository _repository;

  Future<ActivityStats> compute(
    List<Activity> activities, {
    DateTime? now,
  }) async {
    final referenceDate = now ?? DateTime.now();
    final latestActivity = activities.isEmpty ? null : activities.first;

    var overall = _StatsAccumulator();
    var monthly = _StatsAccumulator();
    var latest = _StatsAccumulator();
    var monthActivities = 0;

    for (final activity in activities) {
      final rounds = await _repository.loadRounds(activity.id);
      final activityStats = _StatsAccumulator.fromRounds(rounds);
      overall = overall.merge(activityStats);

      final isThisMonth =
          activity.createdAt.year == referenceDate.year &&
          activity.createdAt.month == referenceDate.month;
      if (isThisMonth) {
        monthActivities += 1;
        monthly = monthly.merge(activityStats);
      }

      if (latestActivity != null && activity.id == latestActivity.id) {
        latest = activityStats;
      }
    }

    return ActivityStats(
      latest: latestActivity == null
          ? null
          : ActivityStatsSnapshot(
              kind: ActivityStatsSnapshotKind.latest,
              title: 'Latest session',
              subtitle: latestActivity.name,
              activities: 1,
              rounds: latest.rounds,
              arrows: latest.arrows,
              bestRoundScore: latest.bestRoundScore,
              averageRoundScore: latest.averageRoundScore,
            ),
      monthly: ActivityStatsSnapshot(
        kind: ActivityStatsSnapshotKind.monthly,
        title: 'This month',
        subtitle: '$monthActivities activities',
        activities: monthActivities,
        rounds: monthly.rounds,
        arrows: monthly.arrows,
        bestRoundScore: monthly.bestRoundScore,
        averageRoundScore: monthly.averageRoundScore,
      ),
      overall: ActivityStatsSnapshot(
        kind: ActivityStatsSnapshotKind.overall,
        title: 'All time',
        subtitle: '${activities.length} activities',
        activities: activities.length,
        rounds: overall.rounds,
        arrows: overall.arrows,
        bestRoundScore: overall.bestRoundScore,
        averageRoundScore: overall.averageRoundScore,
      ),
    );
  }
}

class ActivityStats {
  const ActivityStats({
    required this.latest,
    required this.monthly,
    required this.overall,
  });

  final ActivityStatsSnapshot? latest;
  final ActivityStatsSnapshot monthly;
  final ActivityStatsSnapshot overall;

  List<ActivityStatsSnapshot> get snapshots => [
    if (latest != null) latest!,
    monthly,
    overall,
  ];
}

class ActivityStatsSnapshot {
  const ActivityStatsSnapshot({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.activities,
    required this.rounds,
    required this.arrows,
    required this.bestRoundScore,
    required this.averageRoundScore,
  });

  final ActivityStatsSnapshotKind kind;
  final String title;
  final String subtitle;
  final int activities;
  final int rounds;
  final int arrows;
  final int bestRoundScore;
  final double averageRoundScore;
}

class _StatsAccumulator {
  const _StatsAccumulator({
    this.rounds = 0,
    this.arrows = 0,
    this.score = 0,
    this.bestRoundScore = 0,
  });

  factory _StatsAccumulator.fromRounds(List<ArcheryRound> rounds) {
    return _StatsAccumulator(
      rounds: rounds.length,
      arrows: rounds.fold<int>(0, (sum, round) => sum + round.arrows.length),
      score: rounds.fold<int>(0, (sum, round) => sum + round.totalScore),
      bestRoundScore: rounds.fold<int>(
        0,
        (best, round) => math.max(best, round.totalScore),
      ),
    );
  }

  final int rounds;
  final int arrows;
  final int score;
  final int bestRoundScore;

  double get averageRoundScore => rounds == 0 ? 0 : score / rounds;

  _StatsAccumulator merge(_StatsAccumulator other) {
    return _StatsAccumulator(
      rounds: rounds + other.rounds,
      arrows: arrows + other.arrows,
      score: score + other.score,
      bestRoundScore: math.max(bestRoundScore, other.bestRoundScore),
    );
  }
}

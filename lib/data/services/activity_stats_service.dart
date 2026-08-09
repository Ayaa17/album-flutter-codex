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
    final trend = <ActivityTrendPoint>[];

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

      if (rounds.isNotEmpty) {
        trend.add(
          ActivityTrendPoint(
            label: activity.name,
            averageArrowScore: activityStats.averageArrowScore,
          ),
        );
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
      bestRoundScore: overall.bestRoundScore,
      averageArrowScore: overall.averageArrowScore,
      xTenRate: overall.xTenRate,
      scoreDistribution: overall.scoreDistribution,
      recentTrend: trend.take(10).toList().reversed.toList(),
    );
  }
}

class ActivityStats {
  const ActivityStats({
    required this.latest,
    required this.monthly,
    required this.overall,
    required this.bestRoundScore,
    required this.averageArrowScore,
    required this.xTenRate,
    required this.scoreDistribution,
    required this.recentTrend,
  });

  final ActivityStatsSnapshot? latest;
  final ActivityStatsSnapshot monthly;
  final ActivityStatsSnapshot overall;
  final int bestRoundScore;
  final double averageArrowScore;
  final double xTenRate;
  final List<ScoreDistributionEntry> scoreDistribution;
  final List<ActivityTrendPoint> recentTrend;

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

class ScoreDistributionEntry {
  const ScoreDistributionEntry({required this.label, required this.count});

  final String label;
  final int count;
}

class ActivityTrendPoint {
  const ActivityTrendPoint({
    required this.label,
    required this.averageArrowScore,
  });

  final String label;
  final double averageArrowScore;
}

class _StatsAccumulator {
  const _StatsAccumulator({
    this.rounds = 0,
    this.arrows = 0,
    this.score = 0,
    this.bestRoundScore = 0,
    this.xHits = 0,
    this.tenHits = 0,
    this.scoreCounts = const <String, int>{},
  });

  factory _StatsAccumulator.fromRounds(List<ArcheryRound> rounds) {
    final scoreCounts = <String, int>{
      for (final label in _scoreLabels) label: 0,
    };
    var xHits = 0;
    var tenHits = 0;
    for (final round in rounds) {
      for (final arrow in round.arrows) {
        final label = arrow.isX
            ? 'X'
            : arrow.score <= 0
            ? 'Miss'
            : '${arrow.score}';
        scoreCounts[label] = (scoreCounts[label] ?? 0) + 1;
        if (arrow.isX) {
          xHits += 1;
        } else if (arrow.score == 10) {
          tenHits += 1;
        }
      }
    }
    return _StatsAccumulator(
      rounds: rounds.length,
      arrows: rounds.fold<int>(0, (sum, round) => sum + round.arrows.length),
      score: rounds.fold<int>(0, (sum, round) => sum + round.totalScore),
      bestRoundScore: rounds.fold<int>(
        0,
        (best, round) => math.max(best, round.totalScore),
      ),
      xHits: xHits,
      tenHits: tenHits,
      scoreCounts: scoreCounts,
    );
  }

  static const _scoreLabels = ['X', '10', '9', '8', '7', '6', 'Miss'];

  final int rounds;
  final int arrows;
  final int score;
  final int bestRoundScore;
  final int xHits;
  final int tenHits;
  final Map<String, int> scoreCounts;

  double get averageRoundScore => rounds == 0 ? 0 : score / rounds;
  double get averageArrowScore => arrows == 0 ? 0 : score / arrows;
  double get xTenRate => arrows == 0 ? 0 : ((xHits + tenHits) * 100) / arrows;

  List<ScoreDistributionEntry> get scoreDistribution => [
    for (final label in _scoreLabels)
      ScoreDistributionEntry(label: label, count: scoreCounts[label] ?? 0),
  ];

  _StatsAccumulator merge(_StatsAccumulator other) {
    final mergedCounts = <String, int>{
      for (final label in _scoreLabels)
        label: (scoreCounts[label] ?? 0) + (other.scoreCounts[label] ?? 0),
    };
    return _StatsAccumulator(
      rounds: rounds + other.rounds,
      arrows: arrows + other.arrows,
      score: score + other.score,
      bestRoundScore: math.max(bestRoundScore, other.bestRoundScore),
      xHits: xHits + other.xHits,
      tenHits: tenHits + other.tenHits,
      scoreCounts: mergedCounts,
    );
  }
}

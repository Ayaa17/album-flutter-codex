import 'package:equatable/equatable.dart';

import '../../data/models/activity.dart';
import '../../data/models/archery_models.dart';

enum ActivityDetailStatus { initial, loading, success, failure }

class ActivityDetailState extends Equatable {
  const ActivityDetailState({
    required this.activity,
    this.status = ActivityDetailStatus.initial,
    this.rounds = const <ArcheryRound>[],
    this.selectedRoundId,
    this.message,
  });

  final Activity activity;
  final ActivityDetailStatus status;
  final List<ArcheryRound> rounds;
  final String? selectedRoundId;
  final String? message;

  ActivityDetailState copyWith({
    Activity? activity,
    ActivityDetailStatus? status,
    List<ArcheryRound>? rounds,
    String? selectedRoundId,
    String? message,
  }) {
    final nextRounds = rounds ?? this.rounds;
    final nextSelectedId =
        selectedRoundId ??
        this.selectedRoundId ??
        (nextRounds.isNotEmpty ? nextRounds.first.id : null);
    return ActivityDetailState(
      activity: activity ?? this.activity,
      status: status ?? this.status,
      rounds: nextRounds,
      selectedRoundId: nextSelectedId,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    activity,
    status,
    rounds,
    selectedRoundId,
    message,
  ];

  ArcheryRound? get selectedRound {
    if (rounds.isEmpty) return null;
    if (selectedRoundId == null) return rounds.first;
    return rounds.firstWhere(
      (round) => round.id == selectedRoundId,
      orElse: () => rounds.first,
    );
  }
}

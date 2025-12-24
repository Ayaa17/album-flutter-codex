import 'package:equatable/equatable.dart';

import '../../data/models/activity.dart';

enum ActivityStatus { initial, loading, success, failure }

class ActivityState extends Equatable {
  const ActivityState({
    this.status = ActivityStatus.initial,
    this.activities = const <Activity>[],
    this.message,
  });

  final ActivityStatus status;
  final List<Activity> activities;
  final String? message;

  ActivityState copyWith({
    ActivityStatus? status,
    List<Activity>? activities,
    String? message,
  }) {
    return ActivityState(
      status: status ?? this.status,
      activities: activities ?? this.activities,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, activities, message];
}

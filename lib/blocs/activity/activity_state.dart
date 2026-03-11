import 'package:equatable/equatable.dart';

import '../../data/models/activity.dart';

enum ActivityStatus { initial, loading, success, failure }

class ActivityState extends Equatable {
  static const Object _noValue = _NoValue();

  const ActivityState({
    this.status = ActivityStatus.initial,
    this.activities = const <Activity>[],
    this.message,
    this.lastCreatedActivityId,
  });

  final ActivityStatus status;
  final List<Activity> activities;
  final String? message;
  final String? lastCreatedActivityId;

  ActivityState copyWith({
    ActivityStatus? status,
    List<Activity>? activities,
    String? message,
    Object? lastCreatedActivityId = _noValue,
  }) {
    return ActivityState(
      status: status ?? this.status,
      activities: activities ?? this.activities,
      message: message,
      lastCreatedActivityId:
          lastCreatedActivityId == _noValue
              ? this.lastCreatedActivityId
              : lastCreatedActivityId as String?,
    );
  }

  @override
  List<Object?> get props => [status, activities, message, lastCreatedActivityId];
}

class _NoValue {
  const _NoValue();
}

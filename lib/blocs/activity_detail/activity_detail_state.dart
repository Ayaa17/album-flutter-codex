import 'package:equatable/equatable.dart';

import '../../data/models/activity.dart';
import '../../data/models/photo_entry.dart';

enum ActivityDetailStatus { initial, loading, success, failure }

class ActivityDetailState extends Equatable {
  const ActivityDetailState({
    required this.activity,
    this.status = ActivityDetailStatus.initial,
    this.photos = const <PhotoEntry>[],
    this.message,
  });

  final Activity activity;
  final ActivityDetailStatus status;
  final List<PhotoEntry> photos;
  final String? message;

  ActivityDetailState copyWith({
    Activity? activity,
    ActivityDetailStatus? status,
    List<PhotoEntry>? photos,
    String? message,
  }) {
    return ActivityDetailState(
      activity: activity ?? this.activity,
      status: status ?? this.status,
      photos: photos ?? this.photos,
      message: message,
    );
  }

  @override
  List<Object?> get props => [activity, status, photos, message];
}

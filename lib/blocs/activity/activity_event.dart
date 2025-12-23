import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/target_face.dart';

class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => const [];
}

class ActivityStarted extends ActivityEvent {
  const ActivityStarted();
}

class ActivityRefreshed extends ActivityEvent {
  const ActivityRefreshed();
}

class ActivityCreated extends ActivityEvent {
  const ActivityCreated(this.name, this.targetFaceType);

  final String name;
  final TargetFaceType targetFaceType;

  @override
  List<Object?> get props => [name, targetFaceType];
}

class ActivityQuickCaptured extends ActivityEvent {
  const ActivityQuickCaptured(this.defaultName, this.targetFaceType);

  final String defaultName;
  final TargetFaceType targetFaceType;

  @override
  List<Object?> get props => [defaultName, targetFaceType];
}

class ActivityRenamed extends ActivityEvent {
  const ActivityRenamed({required this.id, required this.newName});

  final String id;
  final String newName;

  @override
  List<Object?> get props => [id, newName];
}

class ActivityDeleted extends ActivityEvent {
  const ActivityDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class ActivityPhotoAdded extends ActivityEvent {
  const ActivityPhotoAdded({required this.id, required this.source});

  final String id;
  final ImageSource source;

  @override
  List<Object?> get props => [id, source];
}

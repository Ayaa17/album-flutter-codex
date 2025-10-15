import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

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
  const ActivityCreated(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

class ActivityQuickCaptured extends ActivityEvent {
  const ActivityQuickCaptured(this.defaultName);

  final String defaultName;

  @override
  List<Object?> get props => [defaultName];
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

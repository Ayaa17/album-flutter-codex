import 'package:equatable/equatable.dart';

class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.directoryPath,
    required this.photoCount,
    required this.coverPhotoPath,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String directoryPath;
  final int photoCount;
  final String? coverPhotoPath;

  Activity copyWith({
    String? name,
    DateTime? createdAt,
    String? directoryPath,
    int? photoCount,
    String? coverPhotoPath,
  }) {
    return Activity(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      directoryPath: directoryPath ?? this.directoryPath,
      photoCount: photoCount ?? this.photoCount,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
    );
  }

  @override
  List<Object?> get props => [id, name, createdAt, directoryPath, photoCount, coverPhotoPath];
}

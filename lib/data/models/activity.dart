import 'package:equatable/equatable.dart';

import 'target_face.dart';

class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.directoryPath,
    required this.photoCount,
    required this.coverPhotoPath,
    required this.targetFaceType,
    this.distanceMeters,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String directoryPath;
  final int photoCount;
  final String? coverPhotoPath;
  final TargetFaceType targetFaceType;
  final int? distanceMeters;

  Activity copyWith({
    String? name,
    DateTime? createdAt,
    String? directoryPath,
    int? photoCount,
    String? coverPhotoPath,
    TargetFaceType? targetFaceType,
    int? distanceMeters,
  }) {
    return Activity(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      directoryPath: directoryPath ?? this.directoryPath,
      photoCount: photoCount ?? this.photoCount,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      targetFaceType: targetFaceType ?? this.targetFaceType,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    createdAt,
    directoryPath,
    photoCount,
    coverPhotoPath,
    targetFaceType,
    distanceMeters,
  ];
}

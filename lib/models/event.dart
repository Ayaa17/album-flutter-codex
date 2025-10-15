import 'dart:io';

class Event {
  const Event({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.directory,
    required this.photoCount,
    required this.latestPhotoPath,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final Directory directory;
  final int photoCount;
  final String? latestPhotoPath;

  Event copyWith({
    String? name,
    DateTime? createdAt,
    Directory? directory,
    int? photoCount,
    String? latestPhotoPath,
  }) {
    return Event(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      directory: directory ?? this.directory,
      photoCount: photoCount ?? this.photoCount,
      latestPhotoPath: latestPhotoPath ?? this.latestPhotoPath,
    );
  }
}

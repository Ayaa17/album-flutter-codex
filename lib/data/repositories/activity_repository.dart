import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/activity.dart';
import '../models/target_face.dart';
import '../models/photo_entry.dart';
import '../services/storage_service.dart';

class ActivityRepository {
  ActivityRepository({
    required StorageService storageService,
    ImagePicker? picker,
  }) : _storageService = storageService,
       _picker = picker ?? ImagePicker();

  final StorageService _storageService;
  final ImagePicker _picker;

  static const _metadataFileName = 'metadata.json';

  Future<List<Activity>> loadActivities() async {
    final root = await _storageService.ensureRootDirectory();
    if (!await root.exists()) {
      return const <Activity>[];
    }

    final activities = <Activity>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final activity = await _loadActivityFromDirectory(entity);
      if (activity != null) {
        activities.add(activity);
      }
    }

    activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return activities;
  }

  Future<Activity> createActivity(
    String name, {
    TargetFaceType targetFaceType = TargetFaceType.fullTenRing,
  }) async {
    final sanitized = _sanitizeFileName(name);
    final id = '${DateTime.now().millisecondsSinceEpoch}_$sanitized';
    final directory = await _storageService.ensureActivityDirectory(id);
    final metadata = _ActivityMetadata(
      id: id,
      name: name.trim().isEmpty ? 'Event ${DateTime.now().year}' : name.trim(),
      createdAt: DateTime.now(),
      targetFaceType: targetFaceType,
    );
    await _writeMetadata(directory, metadata);
    return Activity(
      id: id,
      name: metadata.name,
      createdAt: metadata.createdAt,
      directoryPath: directory.path,
      photoCount: 0,
      coverPhotoPath: null,
      targetFaceType: targetFaceType,
    );
  }

  Future<Activity> quickCapture({
    required String defaultName,
    TargetFaceType targetFaceType = TargetFaceType.fullTenRing,
  }) async {
    final activities = await loadActivities();
    final existing = activities
        .where(
          (item) =>
              item.name == defaultName && item.targetFaceType == targetFaceType,
        )
        .toList();
    final target = existing.isNotEmpty
        ? existing.first
        : await createActivity(defaultName, targetFaceType: targetFaceType);
    final captured = await _capturePhotoForActivity(target.id);
    if (captured == null) {
      return target;
    }
    return await _refreshActivity(target.id);
  }

  Future<Activity> renameActivity({
    required String id,
    required String newName,
  }) async {
    final directory = await _storageService.ensureActivityDirectory(id);
    final metadata = await _readMetadata(directory);
    final updatedMetadata = metadata.copyWith(name: newName.trim());
    await _writeMetadata(directory, updatedMetadata);
    return await _refreshActivity(id);
  }

  Future<void> deleteActivity(String id) async {
    final root = await _storageService.ensureRootDirectory();
    final directory = Directory(p.join(root.path, id));
    if (!await directory.exists()) return;
    await directory.delete(recursive: true);
  }

  Future<Activity> addPhotoToActivity(String id, ImageSource source) async {
    final activity = await _refreshActivity(id);
    await _capturePhotoForActivity(activity.id, source: source);
    return await _refreshActivity(id);
  }

  Future<List<PhotoEntry>> loadPhotos(String id) async {
    final directory = await _storageService.ensureActivityDirectory(id);
    final photos = <PhotoEntry>[];
    if (!await directory.exists()) {
      return photos;
    }
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (!_isImageFile(entity.path)) continue;
      final stat = await entity.stat();
      photos.add(PhotoEntry(path: entity.path, createdAt: stat.modified));
    }
    photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return photos;
  }

  Future<Activity> _refreshActivity(String id) async {
    final root = await _storageService.ensureRootDirectory();
    final directory = Directory(p.join(root.path, id));
    final activity = await _loadActivityFromDirectory(directory);
    if (activity == null) {
      throw StateError('Activity not found for id: $id');
    }
    return activity;
  }

  Future<Activity?> _loadActivityFromDirectory(Directory directory) async {
    if (!await directory.exists()) return null;
    final metadata = await _tryReadMetadata(directory);
    if (metadata == null) return null;

    File? capturedCover;
    DateTime? capturedModified;
    File? fallbackCover;
    DateTime? fallbackEarliest;
    var photoCount = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      if (!_isImageFile(entity.path)) continue;
      final stat = await entity.stat();
      photoCount += 1;

      final fileName = p.basename(entity.path);
      if (fileName.startsWith('photo_')) {
        if (capturedCover == null ||
            stat.modified.isAfter(capturedModified ?? DateTime.fromMillisecondsSinceEpoch(0))) {
          capturedCover = entity;
          capturedModified = stat.modified;
        }
      }

      if (fallbackCover == null ||
          stat.modified.isBefore(fallbackEarliest ?? DateTime.now())) {
        fallbackCover = entity;
        fallbackEarliest = stat.modified;
      }
    }

    final cover = capturedCover ?? fallbackCover;

    return Activity(
      id: metadata.id,
      name: metadata.name,
      createdAt: metadata.createdAt,
      directoryPath: directory.path,
      photoCount: photoCount,
      coverPhotoPath: cover?.path,
      targetFaceType: metadata.targetFaceType,
    );
  }

  Future<_ActivityMetadata> _readMetadata(Directory directory) async {
    final metadata = await _tryReadMetadata(directory);
    if (metadata == null) {
      throw StateError('Missing or invalid metadata for ${directory.path}');
    }
    return metadata;
  }

  Future<_ActivityMetadata?> _tryReadMetadata(Directory directory) async {
    final file = File(p.join(directory.path, _metadataFileName));
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final id = (raw['id'] as String?)?.trim();
      final name = (raw['name'] as String?)?.trim();
      final createdAtString = (raw['createdAt'] as String?)?.trim();
      final targetFaceRaw = raw['targetFace'] as String?;
      if (id == null || id.isEmpty) return null;
      if (name == null || name.isEmpty) return null;
      if (createdAtString == null || createdAtString.isEmpty) return null;
      final createdAt = DateTime.tryParse(createdAtString);
      if (createdAt == null) return null;
      return _ActivityMetadata(
        id: id,
        name: name,
        createdAt: createdAt,
        targetFaceType: TargetFaceTypeX.fromStorage(targetFaceRaw),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMetadata(
    Directory directory,
    _ActivityMetadata metadata,
  ) async {
    final file = File(p.join(directory.path, _metadataFileName));
    final payload = jsonEncode({
      'id': metadata.id,
      'name': metadata.name,
      'createdAt': metadata.createdAt.toIso8601String(),
      'targetFace': metadata.targetFaceType.storageKey,
    });
    await file.writeAsString(payload, flush: true);
  }

  Future<File?> _capturePhotoForActivity(
    String id, {
    ImageSource source = ImageSource.camera,
  }) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (pickedFile == null) return null;
    final directory = await _storageService.ensureActivityDirectory(id);
    final extension = p.extension(pickedFile.path).isEmpty
        ? '.jpg'
        : p.extension(pickedFile.path);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}$extension';
    final targetPath = p.join(directory.path, fileName);
    if (Platform.isIOS || Platform.isAndroid) {
      await pickedFile.saveTo(targetPath);
    } else {
      await File(pickedFile.path).copy(targetPath);
    }
    return File(targetPath);
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}

class _ActivityMetadata {
  _ActivityMetadata({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.targetFaceType,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final TargetFaceType targetFaceType;

  _ActivityMetadata copyWith({
    String? name,
    DateTime? createdAt,
    TargetFaceType? targetFaceType,
  }) {
    return _ActivityMetadata(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      targetFaceType: targetFaceType ?? this.targetFaceType,
    );
  }
}

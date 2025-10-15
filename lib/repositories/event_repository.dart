import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/event.dart';

class EventRepository {
  static const String _metadataFileName = 'metadata.json';
  late Directory _root;

  Future<void> init() async {
    final baseDir = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(baseDir.path, 'events'));
    if (!await _root.exists()) {
      await _root.create(recursive: true);
    }
  }

  Future<Event> createEvent(String name) async {
    final sanitized = _sanitizeFolderName(name);
    var folderName = sanitized;
    var directory = Directory(p.join(_root.path, folderName));
    var suffix = 1;

    while (await directory.exists()) {
      folderName = '$sanitized-$suffix';
      directory = Directory(p.join(_root.path, folderName));
      suffix += 1;
    }

    await directory.create(recursive: true);
    final metadata = _EventMetadata(name: name.trim().isEmpty ? folderName : name.trim());
    await _writeMetadata(directory, metadata);

    return Event(
      id: folderName,
      name: metadata.name,
      createdAt: metadata.createdAt,
      directory: directory,
      photoCount: 0,
      latestPhotoPath: null,
    );
  }

  Future<List<Event>> loadEvents() async {
    if (!await _root.exists()) {
      return <Event>[];
    }

    final directories = await _root
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    final events = <Event>[];
    for (final directory in directories) {
      final event = await _eventFromDirectory(directory);
      events.add(event);
    }

    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events;
  }

  Future<List<File>> loadEventPhotos(Event event) async {
    if (!await event.directory.exists()) {
      return <File>[];
    }

    final files = await event.directory
        .list()
        .where((entity) => entity is File && _isImageFile(entity.path))
        .cast<File>()
        .toList();

    final entries = await Future.wait(
      files.map((file) async {
        final stat = await file.stat();
        return _FileEntry(file: file, modified: stat.modified);
      }),
    );

    entries.sort((a, b) => b.modified.compareTo(a.modified));
    return entries.map((entry) => entry.file).toList();
  }

  Future<File> savePhotoToEvent(Event event, XFile source) async {
    final extension = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}$extension';
    final targetPath = p.join(event.directory.path, fileName);

    if (Platform.isIOS || Platform.isAndroid) {
      await source.saveTo(targetPath);
    } else {
      await File(source.path).copy(targetPath);
    }

    return File(targetPath);
  }

  Future<Event> _eventFromDirectory(Directory directory) async {
    final metadata = await _readMetadata(directory);
    final photos = await loadEventPhotos(
      Event(
        id: p.basename(directory.path),
        name: metadata.name,
        createdAt: metadata.createdAt,
        directory: directory,
        photoCount: 0,
        latestPhotoPath: null,
      ),
    );

    return Event(
      id: p.basename(directory.path),
      name: metadata.name,
      createdAt: metadata.createdAt,
      directory: directory,
      photoCount: photos.length,
      latestPhotoPath: photos.isEmpty ? null : photos.first.path,
    );
  }

  Future<_EventMetadata> _readMetadata(Directory directory) async {
    final file = File(p.join(directory.path, _metadataFileName));

    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final name = (raw['name'] as String?)?.trim();
        final rawDate = raw['createdAt'] as String?;
        final parsed = rawDate == null ? null : DateTime.tryParse(rawDate);
        return _EventMetadata(
          name: (name == null || name.isEmpty) ? p.basename(directory.path) : name,
          createdAt: parsed ?? (await directory.stat()).changed,
        );
      } catch (_) {
        // Fallback handled below.
      }
    }

    final stat = await directory.stat();
    final metadata = _EventMetadata(
      name: p.basename(directory.path),
      createdAt: stat.changed,
    );
    await _writeMetadata(directory, metadata);
    return metadata;
  }

  Future<void> _writeMetadata(Directory directory, _EventMetadata metadata) async {
    final file = File(p.join(directory.path, _metadataFileName));
    final payload = jsonEncode({
      'name': metadata.name,
      'createdAt': metadata.createdAt.toIso8601String(),
    });
    await file.writeAsString(payload, flush: true);
  }

  String _sanitizeFolderName(String name) {
    final trimmed = name.trim().isEmpty ? 'event' : name.trim();
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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

class _EventMetadata {
  _EventMetadata({
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String name;
  final DateTime createdAt;
}

class _FileEntry {
  const _FileEntry({required this.file, required this.modified});

  final File file;
  final DateTime modified;
}

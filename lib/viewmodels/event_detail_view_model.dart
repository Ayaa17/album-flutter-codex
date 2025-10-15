import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/event.dart';
import '../repositories/event_repository.dart';

class EventDetailViewModel extends ChangeNotifier {
  EventDetailViewModel({
    required EventRepository repository,
    required Event initialEvent,
  })  : _repository = repository,
        _event = initialEvent;

  final EventRepository _repository;
  final List<File> _photos = <File>[];

  Event _event;
  bool _isLoading = false;
  String? _errorMessage;

  Event get event => _event;
  List<File> get photos => List.unmodifiable(_photos);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPhotos => _photos.isNotEmpty;

  Future<void> loadInitial() async {
    await _loadPhotos(showSpinner: true);
  }

  Future<void> refresh() async {
    await _loadPhotos(showSpinner: false);
  }

  Future<File?> addPhoto(XFile source) async {
    try {
      final saved = await _repository.savePhotoToEvent(_event, source);
      _photos.insert(0, saved);
      _event = _event.copyWith(
        latestPhotoPath: saved.path,
        photoCount: _event.photoCount + 1,
      );
      _errorMessage = null;
      notifyListeners();
      return saved;
    } catch (_) {
      _errorMessage = '新增照片失敗，請檢查權限或儲存空間。';
      notifyListeners();
      return null;
    }
  }

  void clearErrors() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _loadPhotos({required bool showSpinner}) async {
    if (showSpinner) {
      _setLoading(true);
    }
    try {
      final photos = await _repository.loadEventPhotos(_event);
      _photos
        ..clear()
        ..addAll(photos);
      _event = _event.copyWith(
        photoCount: photos.length,
        latestPhotoPath: photos.isEmpty ? null : photos.first.path,
      );
      _errorMessage = null;
    } catch (_) {
      _errorMessage = '載入照片時發生錯誤。';
    } finally {
      if (showSpinner) {
        _setLoading(false);
      } else {
        notifyListeners();
      }
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}

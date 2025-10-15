import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../repositories/event_repository.dart';

class EventListViewModel extends ChangeNotifier {
  EventListViewModel({required EventRepository repository}) : _repository = repository;

  final EventRepository _repository;
  final List<Event> _events = <Event>[];

  bool _isLoading = false;
  bool _initialised = false;
  String? _errorMessage;

  List<Event> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  bool get isInitialLoading => !_initialised && _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInitial() async {
    await _loadEvents(showSpinner: true);
  }

  Future<void> refresh() async {
    await _loadEvents(showSpinner: false);
  }

  Future<Event?> createEvent(String name) async {
    _setLoading(true);
    try {
      final event = await _repository.createEvent(name);
      _events.insert(0, event);
      _errorMessage = null;
      return event;
    } catch (_) {
      _errorMessage = '建立活動時發生錯誤。';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void replaceEvent(Event event) {
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index >= 0) {
      _events[index] = event;
      notifyListeners();
    }
  }

  void clearErrors() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  String defaultEventName() {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    return '${now.year}-${twoDigits(now.month)}-${twoDigits(now.day)}';
  }

  Future<void> _loadEvents({required bool showSpinner}) async {
    if (showSpinner) {
      _setLoading(true);
    }
    try {
      final events = await _repository.loadEvents();
      _events
        ..clear()
        ..addAll(events);
      _errorMessage = null;
    } catch (_) {
      _errorMessage = '載入活動失敗，請稍後再試。';
    } finally {
      _initialised = true;
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

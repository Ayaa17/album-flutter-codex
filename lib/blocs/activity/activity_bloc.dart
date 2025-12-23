import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/activity_repository.dart';
import 'activity_event.dart';
import 'activity_state.dart';

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc({required ActivityRepository repository})
    : _repository = repository,
      super(const ActivityState()) {
    on<ActivityStarted>(_onStarted);
    on<ActivityRefreshed>(_onRefreshed);
    on<ActivityCreated>(_onCreated);
    on<ActivityQuickCaptured>(_onQuickCaptured);
    on<ActivityRenamed>(_onRenamed);
    on<ActivityDeleted>(_onDeleted);
    on<ActivityPhotoAdded>(_onPhotoAdded);
  }

  final ActivityRepository _repository;

  Future<void> _onStarted(
    ActivityStarted event,
    Emitter<ActivityState> emit,
  ) async {
    await _loadActivities(emit, loading: true);
  }

  Future<void> _onRefreshed(
    ActivityRefreshed event,
    Emitter<ActivityState> emit,
  ) async {
    await _loadActivities(
      emit,
      // loading: state.status == ActivityStatus.initial,
      loading: true,
    );
  }

  Future<void> _onCreated(
    ActivityCreated event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading, message: null));
    try {
      await _repository.createActivity(
        event.name,
        targetFaceType: event.targetFaceType,
      );
      await _loadActivities(emit);
      emit(state.copyWith(message: 'Activity created.'));
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityStatus.failure,
          message: 'Failed to create activity.',
        ),
      );
    }
  }

  Future<void> _onQuickCaptured(
    ActivityQuickCaptured event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading, message: null));
    try {
      await _repository.quickCapture(
        defaultName: event.defaultName,
        targetFaceType: event.targetFaceType,
      );
      await _loadActivities(emit);
      emit(state.copyWith(message: 'Quick capture saved.'));
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityStatus.failure,
          message: 'Quick capture failed. Please try again.',
        ),
      );
    }
  }

  Future<void> _onRenamed(
    ActivityRenamed event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading, message: null));
    try {
      await _repository.renameActivity(id: event.id, newName: event.newName);
      await _loadActivities(emit);
      emit(state.copyWith(message: 'Activity name updated.'));
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityStatus.failure,
          message: 'Failed to rename activity.',
        ),
      );
    }
  }

  Future<void> _onDeleted(
    ActivityDeleted event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading, message: null));
    try {
      await _repository.deleteActivity(event.id);
      await _loadActivities(emit);
      emit(state.copyWith(message: 'Activity deleted.'));
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityStatus.failure,
          message: 'Failed to delete activity.',
        ),
      );
    }
  }

  Future<void> _onPhotoAdded(
    ActivityPhotoAdded event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading, message: null));
    try {
      await _repository.addPhotoToActivity(event.id, event.source);
      await _loadActivities(emit);
      emit(state.copyWith(message: 'Photo added.'));
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityStatus.failure,
          message: 'Failed to add photo.',
        ),
      );
    }
  }

  Future<void> _loadActivities(
    Emitter<ActivityState> emit, {
    bool loading = false,
  }) async {
    if (loading) {
      emit(state.copyWith(status: ActivityStatus.loading, message: null));
    }
    try {
      final activities = await _repository.loadActivities();
      emit(
        state.copyWith(status: ActivityStatus.success, activities: activities),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityStatus.failure,
          message: 'Failed to load activities. Please try again.',
        ),
      );
    }
  }
}

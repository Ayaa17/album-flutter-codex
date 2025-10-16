import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/activity.dart';
import '../../data/repositories/archery_repository.dart';
import 'activity_detail_state.dart';

class ActivityDetailCubit extends Cubit<ActivityDetailState> {
  ActivityDetailCubit({
    required Activity activity,
    required ArcheryRepository repository,
  }) : _repository = repository,
       super(ActivityDetailState(activity: activity));

  final ArcheryRepository _repository;

  Future<void> loadInitial() async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final rounds = await _repository.loadRounds(state.activity.id);
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: rounds,
          selectedRoundId: rounds.isEmpty ? null : rounds.first.id,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Failed to load rounds.',
        ),
      );
    }
  }

  Future<void> refresh() async => loadInitial();

  void selectRound(String roundId) {
    if (state.selectedRoundId == roundId) return;
    emit(state.copyWith(selectedRoundId: roundId));
  }

  Future<void> addRound() async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.addRound(
        state.activity.id,
        state.rounds,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: updated.isEmpty ? null : updated.first.id,
          message: 'Round added.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to add round.',
        ),
      );
    }
  }

  Future<void> addArrow(Offset localPosition, Size targetSize) async {
    final round = state.selectedRound;
    if (round == null) {
      emit(state.copyWith(message: 'Add a round to start recording arrows.'));
      return;
    }
    if (round.arrows.length >= 6) {
      emit(state.copyWith(message: 'Round already contains 6 arrows.'));
      return;
    }

    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.addArrow(
        activityId: state.activity.id,
        rounds: state.rounds,
        roundId: round.id,
        localPosition: localPosition,
        targetSize: targetSize,
      );
      final latestRound = updated.firstWhere(
        (element) => element.id == round.id,
      );
      final addedArrow = latestRound.arrows.first;
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: round.id,
          message: 'Arrow added: ${addedArrow.score} pts.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to add arrow.',
        ),
      );
    }
  }

  Future<void> removeArrow(String roundId, String arrowId) async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.removeArrow(
        activityId: state.activity.id,
        rounds: state.rounds,
        roundId: roundId,
        arrowId: arrowId,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: updated.isEmpty
              ? null
              : (state.selectedRoundId ?? updated.first.id),
          message: 'Arrow removed.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to remove arrow.',
        ),
      );
    }
  }

  Future<void> deleteRound(String roundId) async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.deleteRound(
        state.activity.id,
        state.rounds,
        roundId,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: updated.isEmpty ? null : updated.first.id,
          message: 'Round deleted.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to delete round.',
        ),
      );
    }
  }

  Future<void> attachPhoto(String roundId) async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.attachPhoto(
        state.activity.id,
        state.rounds,
        roundId,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: roundId,
          message: 'Round photo updated.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to update photo.',
        ),
      );
    }
  }
}

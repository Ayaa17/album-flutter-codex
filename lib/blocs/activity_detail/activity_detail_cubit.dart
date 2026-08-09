import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/activity.dart';
import '../../data/models/archery_models.dart';
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
    final hasExistingRounds = state.rounds.isNotEmpty;
    if (hasExistingRounds) {
      emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    } else {
      emit(state.copyWith(message: null));
    }
    try {
      final updated = await _repository.addRound(
        state.activity.id,
        state.rounds,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: updated.isEmpty ? null : updated.last.id,
          // message: 'Round added.',
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

  Future<void> addRoundWithPhoto() async {
    if (state.rounds.isNotEmpty) {
      emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    } else {
      emit(state.copyWith(message: null));
    }
    try {
      final updated = await _repository.addRoundWithPhoto(
        state.activity.id,
        state.rounds,
      );
      if (identical(updated, state.rounds) ||
          updated.length == state.rounds.length) {
        emit(
          state.copyWith(
            status: ActivityDetailStatus.success,
            rounds: updated,
            selectedRoundId: state.selectedRoundId,
            message: 'Photo capture cancelled.',
          ),
        );
        return;
      }
      final newRound = updated.last;
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: newRound.id,
          // message: 'Round added with photo.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to add round with photo.',
        ),
      );
    }
  }

  Future<ArrowHit?> addArrow(Offset localPosition, Size targetSize) async {
    final round = state.selectedRound;
    if (round == null) {
      emit(state.copyWith(message: 'Add a round to start recording arrows.'));
      return null;
    }
    if (round.arrows.length >= 6) {
      emit(state.copyWith(message: 'Round already contains 6 arrows.'));
      return null;
    }

    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final previousArrowIds = round.arrows.map((arrow) => arrow.id).toSet();
      final updated = await _repository.addArrow(
        activityId: state.activity.id,
        rounds: state.rounds,
        roundId: round.id,
        localPosition: localPosition,
        targetSize: targetSize,
        targetFaceType: state.activity.targetFaceType,
      );
      final updatedRound = updated.firstWhere(
        (candidate) => candidate.id == round.id,
        orElse: () => round,
      );
      ArrowHit? addedArrow;
      for (final arrow in updatedRound.arrows) {
        if (!previousArrowIds.contains(arrow.id)) {
          addedArrow = arrow;
          break;
        }
      }
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: round.id,
          // message: 'Arrow added: ${addedArrow.score} pts.',
        ),
      );
      return addedArrow;
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to add arrow.',
        ),
      );
      return null;
    }
  }

  Future<ArrowHit?> undoLastArrow() async {
    final round = state.selectedRound;
    if (round == null || round.arrows.isEmpty) {
      emit(state.copyWith(message: 'No arrow to undo.'));
      return null;
    }

    final removedArrow = round.arrows.first;
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.removeArrow(
        activityId: state.activity.id,
        rounds: state.rounds,
        roundId: round.id,
        arrowId: removedArrow.id,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: round.id,
          message: 'Last arrow undone.',
        ),
      );
      return removedArrow;
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to undo last arrow.',
        ),
      );
      return null;
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

  Future<void> updateArrowScore({
    required String roundId,
    required String arrowId,
    required int newScore,
  }) async {
    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.updateArrowScore(
        activityId: state.activity.id,
        rounds: state.rounds,
        roundId: roundId,
        arrowId: arrowId,
        newScore: newScore,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: updated.isEmpty
              ? null
              : (state.selectedRoundId ?? updated.first.id),
          message: 'Arrow score updated.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to update arrow score.',
        ),
      );
    }
  }

  Future<void> nudgeArrow({
    required String roundId,
    required String arrowId,
    required Offset delta,
    bool persist = true,
  }) async {
    if (!persist) {
      final updated = _repository.previewNudgeArrow(
        rounds: state.rounds,
        roundId: roundId,
        arrowId: arrowId,
        delta: delta,
        targetFaceType: state.activity.targetFaceType,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: roundId,
          message: null,
        ),
      );
      return;
    }

    emit(state.copyWith(status: ActivityDetailStatus.loading, message: null));
    try {
      final updated = await _repository.nudgeArrow(
        activityId: state.activity.id,
        rounds: state.rounds,
        roundId: roundId,
        arrowId: arrowId,
        delta: delta,
        targetFaceType: state.activity.targetFaceType,
      );
      emit(
        state.copyWith(
          status: ActivityDetailStatus.success,
          rounds: updated,
          selectedRoundId: roundId,
          message: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to adjust arrow.',
        ),
      );
    }
  }

  Future<void> saveCurrentRounds() async {
    try {
      await _repository.saveRounds(state.activity.id, state.rounds);
    } catch (_) {
      emit(
        state.copyWith(
          status: ActivityDetailStatus.failure,
          message: 'Unable to save arrow adjustment.',
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

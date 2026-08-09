import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository repository,
    required AppSettings initialSettings,
  }) : _repository = repository,
       super(SettingsState(settings: initialSettings));

  final SettingsRepository _repository;

  Future<void> refresh() async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      final settings = await _repository.loadSettings();
      emit(state.copyWith(settings: settings, status: SettingsStatus.success));
    } catch (_) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'Failed to load settings.',
        ),
      );
    }
  }

  Future<void> toggleTheme(ThemeMode mode) async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      await _repository.updateThemeMode(mode);
      emit(
        state.copyWith(
          settings: state.settings.copyWith(themeMode: mode),
          status: SettingsStatus.success,
          message: 'Theme updated.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'Unable to update theme.',
        ),
      );
    }
  }

  Future<void> updateDefaultNaming(String value) async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      await _repository.updateDefaultNaming(value);
      emit(
        state.copyWith(
          settings: state.settings.copyWith(defaultActivityNameFormat: value),
          status: SettingsStatus.success,
          message: 'Default name updated.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'Unable to update default name.',
        ),
      );
    }
  }

  Future<void> updateDefaultDistance(int meters) async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      await _repository.updateDefaultDistance(meters);
      emit(
        state.copyWith(
          settings: state.settings.copyWith(defaultDistanceMeters: meters),
          status: SettingsStatus.success,
          message: 'Default distance updated.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'Unable to update default distance.',
        ),
      );
    }
  }

  Future<void> rememberDefaultDistance(int meters) async {
    try {
      await _repository.updateDefaultDistance(meters);
      emit(
        state.copyWith(
          settings: state.settings.copyWith(defaultDistanceMeters: meters),
          status: SettingsStatus.success,
          message: null,
        ),
      );
    } catch (_) {}
  }

  Future<void> updateStoragePath(String path) async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      final updatedPath = await _repository.updateStoragePath(path);
      emit(
        state.copyWith(
          settings: state.settings.copyWith(storagePath: updatedPath),
          status: SettingsStatus.success,
          message: 'Storage path updated.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: SettingsStatus.failure,
          message: 'Unable to update storage path.',
        ),
      );
    }
  }
}

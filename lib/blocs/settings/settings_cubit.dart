import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository repository,
    required AppSettings initialSettings,
  })  : _repository = repository,
        super(SettingsState(settings: initialSettings));

  final SettingsRepository _repository;

  Future<void> refresh() async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      final settings = await _repository.loadSettings();
      emit(state.copyWith(settings: settings, status: SettingsStatus.success));
    } catch (_) {
      emit(state.copyWith(status: SettingsStatus.failure, message: '載入設定失敗。'));
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
          message: '主題已更新',
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: SettingsStatus.failure, message: '更新主題失敗。'));
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
          message: '預設名稱已更新',
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: SettingsStatus.failure, message: '更新預設名稱失敗。'));
    }
  }

  Future<void> updateStoragePath(String path) async {
    emit(state.copyWith(status: SettingsStatus.loading, message: null));
    try {
      final updatedPath = await _repository.updateStoragePath(path);
      emit(
        state.copyWith(
          settings: state.settings.copyWith(storagePath: updatedPath),
          status: SettingsStatus.success,
          message: '儲存路徑已更新',
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: SettingsStatus.failure, message: '更新儲存路徑失敗。'));
    }
  }
}

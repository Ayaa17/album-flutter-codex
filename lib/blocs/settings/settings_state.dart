import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../data/models/app_settings.dart';

enum SettingsStatus { initial, loading, success, failure }

class SettingsState extends Equatable {
  const SettingsState({
    required this.settings,
    this.status = SettingsStatus.initial,
    this.message,
  });

  final AppSettings settings;
  final SettingsStatus status;
  final String? message;

  SettingsState copyWith({
    AppSettings? settings,
    SettingsStatus? status,
    String? message,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      status: status ?? this.status,
      message: message,
    );
  }

  ThemeMode get themeMode => settings.themeMode;

  @override
  List<Object?> get props => [settings, status, message];
}

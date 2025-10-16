import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.themeMode,
    required this.defaultActivityNameFormat,
    required this.storagePath,
  });

  final ThemeMode themeMode;
  final String defaultActivityNameFormat;
  final String storagePath;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultActivityNameFormat,
    String? storagePath,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultActivityNameFormat:
          defaultActivityNameFormat ?? this.defaultActivityNameFormat,
      storagePath: storagePath ?? this.storagePath,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    defaultActivityNameFormat,
    storagePath,
  ];
}

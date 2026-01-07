import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.themeMode,
    required this.defaultActivityNameFormat,
    required this.storagePath,
    required this.version,
  });

  final ThemeMode themeMode;
  final String defaultActivityNameFormat;
  final String storagePath;
  final String version;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultActivityNameFormat,
    String? storagePath,
    String? version,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultActivityNameFormat:
          defaultActivityNameFormat ?? this.defaultActivityNameFormat,
      storagePath: storagePath ?? this.storagePath,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    defaultActivityNameFormat,
    storagePath,
  ];
}

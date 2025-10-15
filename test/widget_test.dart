import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_album_codex/blocs/activity/activity_bloc.dart';
import 'package:flutter_album_codex/blocs/activity/activity_event.dart';
import 'package:flutter_album_codex/blocs/settings/settings_cubit.dart';
import 'package:flutter_album_codex/data/models/app_settings.dart';
import 'package:flutter_album_codex/data/repositories/activity_repository.dart';
import 'package:flutter_album_codex/data/repositories/settings_repository.dart';
import 'package:flutter_album_codex/data/services/storage_service.dart';
import 'package:flutter_album_codex/ui/root/event_album_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders Home tab headline', (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('event_album_test');
    final storageService = StorageService(overrideRoot: tempDir);
    final activityRepository = ActivityRepository(storageService: storageService);
    final settingsRepository = SettingsRepository(storageService: storageService);

    final initialSettings = AppSettings(
      themeMode: ThemeMode.system,
      defaultActivityNameFormat: 'Event {date}',
      storagePath: tempDir.path,
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: storageService),
          RepositoryProvider.value(value: activityRepository),
          RepositoryProvider.value(value: settingsRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ActivityBloc(repository: activityRepository)..add(const ActivityStarted()),
            ),
            BlocProvider(
              create: (_) => SettingsCubit(
                repository: settingsRepository,
                initialSettings: initialSettings,
              ),
            ),
          ],
          child: const EventAlbumApp(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('最近活動'), findsOneWidget);
  });
}

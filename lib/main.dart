import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/activity/activity_bloc.dart';
import 'blocs/activity/activity_event.dart';
import 'blocs/settings/settings_cubit.dart';
import 'data/repositories/activity_repository.dart';
import 'data/repositories/archery_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/storage_service.dart';
import 'ui/root/event_album_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  final activityRepository = ActivityRepository(storageService: storageService);
  final settingsRepository = SettingsRepository(storageService: storageService);
  final archeryRepository = ArcheryRepository(storageService: storageService);
  final initialSettings = await settingsRepository.loadSettings();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: storageService),
        RepositoryProvider.value(value: activityRepository),
        RepositoryProvider.value(value: settingsRepository),
        RepositoryProvider.value(value: archeryRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                ActivityBloc(repository: activityRepository)
                  ..add(const ActivityStarted()),
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
}

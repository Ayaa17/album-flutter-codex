import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_album_codex/blocs/activity/activity_bloc.dart';
import 'package:flutter_album_codex/blocs/activity/activity_state.dart';
import 'package:flutter_album_codex/blocs/navigation/navigation_cubit.dart';
import 'package:flutter_album_codex/blocs/settings/settings_cubit.dart';
import 'package:flutter_album_codex/data/models/activity.dart';
import 'package:flutter_album_codex/data/models/app_settings.dart';
import 'package:flutter_album_codex/data/repositories/activity_repository.dart';
import 'package:flutter_album_codex/data/repositories/settings_repository.dart';
import 'package:flutter_album_codex/data/services/storage_service.dart';
import 'package:flutter_album_codex/ui/home/home_page.dart';

class _FakeActivityRepository extends ActivityRepository {
  _FakeActivityRepository(List<Activity> seed)
    : _seed = seed,
      super(
        storageService: StorageService(
          overrideRoot: Directory.systemTemp.createTempSync(),
        ),
      );

  final List<Activity> _seed;

  @override
  Future<List<Activity>> loadActivities() async => _seed;
}

class _TestingActivityBloc extends ActivityBloc {
  _TestingActivityBloc(ActivityRepository repository)
    : super(repository: repository);

  void seed(ActivityState state) => emit(state);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  testWidgets('renders Home tab headline', (tester) async {
    final mockActivities = [
      Activity(
        id: 'session-1',
        name: 'Mock Session',
        createdAt: DateTime(2025, 1, 1, 9, 30),
        directoryPath: Directory.systemTemp.path,
        photoCount: 0,
        coverPhotoPath: null,
      ),
    ];

    final activityBloc =
        _TestingActivityBloc(_FakeActivityRepository(mockActivities))..seed(
          ActivityState(
            activities: mockActivities,
            status: ActivityStatus.success,
          ),
        );

    final settingsCubit = SettingsCubit(
      repository: SettingsRepository(
        storageService: StorageService(
          overrideRoot: Directory.systemTemp.createTempSync(),
        ),
      ),
      initialSettings: const AppSettings(
        themeMode: ThemeMode.system,
        defaultActivityNameFormat: 'Event {date}',
        storagePath: '',
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ActivityBloc>.value(value: activityBloc),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
          BlocProvider(create: (_) => NavigationCubit()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pump();

    expect(find.text('Recent sessions'), findsOneWidget);
  });
}

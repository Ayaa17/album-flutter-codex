import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/activity/activity_bloc.dart';
import '../../blocs/activity/activity_event.dart';
import '../../blocs/settings/settings_cubit.dart';
import '../../blocs/settings/settings_state.dart';
import '../../blocs/navigation/navigation_cubit.dart';
import '../../theme/app_theme.dart';
import '../activities/activities_page.dart';
import '../home/home_page.dart';
import '../settings/settings_page.dart';

class EventAlbumApp extends StatelessWidget {
  const EventAlbumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final themeMode = settingsState.settings.themeMode;
        return MaterialApp(
          title: 'Event Album',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const _EventAlbumShell(),
        );
      },
    );
  }
}

class _EventAlbumShell extends StatelessWidget {
  const _EventAlbumShell();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NavigationCubit(),
      child: BlocBuilder<NavigationCubit, int>(
        builder: (context, index) {
          final pages = [
            const HomePage(),
            const ActivitiesPage(),
            const SettingsPage(),
          ];

          return Scaffold(
            body: IndexedStack(
              index: index,
              children: pages,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) {
                context.read<NavigationCubit>().selectIndex(value);
                if (value == 0) {
                  context.read<ActivityBloc>().add(const ActivityRefreshed());
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '首頁',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_album_outlined),
                  selectedIcon: Icon(Icons.photo_album),
                  label: '活動',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '設定',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

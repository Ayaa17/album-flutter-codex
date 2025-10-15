import 'package:flutter/material.dart';

import '../repositories/event_repository.dart';
import '../views/event_list_page.dart';

class EventAlbumApp extends StatelessWidget {
  const EventAlbumApp({super.key, required this.repository});

  final EventRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '活動相簿',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A5BF6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F6FB),
        cardTheme: CardThemeData(
          elevation: 4,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: EventListPage(repository: repository),
    );
  }
}

import 'package:flutter/material.dart';

import 'app/event_album_app.dart';
import 'repositories/event_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = EventRepository();
  await repository.init();
  runApp(EventAlbumApp(repository: repository));
}

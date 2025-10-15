// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_album_codex/app/event_album_app.dart';
import 'package:flutter_album_codex/models/event.dart';
import 'package:flutter_album_codex/repositories/event_repository.dart';

void main() {
  testWidgets('顯示活動列表標題', (WidgetTester tester) async {
    final repository = _FakeEventRepository();

    await tester.pumpWidget(EventAlbumApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('活動相簿'), findsOneWidget);
  });
}

class _FakeEventRepository extends EventRepository {
  @override
  Future<void> init() async {}

  @override
  Future<Event> createEvent(String name) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Event>> loadEvents() async => <Event>[];

  @override
  Future<List<File>> loadEventPhotos(Event event) async => <File>[];

  @override
  Future<File> savePhotoToEvent(Event event, XFile source) async {
    throw UnimplementedError();
  }
}

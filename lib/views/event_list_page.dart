import 'package:flutter/material.dart';

import '../models/event.dart';
import '../repositories/event_repository.dart';
import '../viewmodels/event_list_view_model.dart';
import '../widgets/event_card.dart';
import 'event_detail_page.dart';

class EventListPage extends StatefulWidget {
  const EventListPage({super.key, required this.repository});

  final EventRepository repository;

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  late final EventListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = EventListViewModel(repository: widget.repository)
      ..addListener(_onViewModelUpdate);
    _viewModel.loadInitial();
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelUpdate)
      ..dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    if (!mounted) return;
    setState(() {});
    final message = _viewModel.errorMessage;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        _viewModel.clearErrors();
      });
    }
  }

  Future<void> _createEvent() async {
    final defaultName = _viewModel.defaultEventName();
    final controller = TextEditingController(text: defaultName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增活動'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '活動名稱',
              hintText: '請輸入活動名稱',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? defaultName : value);
              },
              child: const Text('建立'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
    final created = await _viewModel.createEvent(newName);
    if (!mounted) return;
    if (created != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已建立活動「${created.name}」。')),
      );
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.errorMessage!)),
      );
      _viewModel.clearErrors();
    }
  }

  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => EventDetailPage(
          repository: widget.repository,
          initialEvent: event,
        ),
      ),
    );
    await _viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final events = _viewModel.events;
    final isInitialLoading = _viewModel.isInitialLoading;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('活動相簿'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _viewModel.isLoading ? null : _createEvent,
        icon: const Icon(Icons.add),
        label: const Text('新增活動'),
      ),
      body: isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _viewModel.refresh,
              child: events.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 160),
                        Icon(
                          Icons.photo_album_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.onSurface.withValues(
                                alpha: 0.18,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            '還沒有任何活動，點擊右下角新增吧！',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return EventCard(
                          event: event,
                          onTap: () => _openEvent(event),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemCount: events.length,
                    ),
            ),
    );
  }
}

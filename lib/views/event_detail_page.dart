import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/event.dart';
import '../repositories/event_repository.dart';
import '../viewmodels/event_detail_view_model.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.repository, required this.initialEvent});

  final EventRepository repository;
  final Event initialEvent;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late final EventDetailViewModel _viewModel;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _viewModel = EventDetailViewModel(
      repository: widget.repository,
      initialEvent: widget.initialEvent,
    )..addListener(_onViewModelUpdate);
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

  Future<void> _pickAndAddPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('拍照新增'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('從相簿選擇'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (picked == null) return;

    await _viewModel.addPhoto(picked);
  }

  Future<void> _openPhoto(File photo, int index) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Hero(
              tag: 'photo_${_viewModel.event.id}_$index',
              child: InteractiveViewer(
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(photo),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _viewModel.isLoading;
    final photos = _viewModel.photos;
    final event = _viewModel.event;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _pickAndAddPhoto,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('新增照片'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _viewModel.refresh,
              child: photos.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        const SizedBox(height: 140),
                        Icon(
                          Icons.photo_outlined,
                          size: 72,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            '這個活動還沒有任何照片，先拍一張吧！',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: _pickAndAddPhoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('新增照片'),
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        return GestureDetector(
                          onTap: () => _openPhoto(photo, index),
                          child: Hero(
                            tag: 'photo_${event.id}_$index',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                photo,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

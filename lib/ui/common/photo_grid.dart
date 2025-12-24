import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/photo_entry.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.photos, required this.onOpen});

  final List<PhotoEntry> photos;
  final void Function(PhotoEntry, int) onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
          onTap: () => onOpen(photo, index),
          child: Hero(
            tag: 'photo_${photo.path}_$index',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(File(photo.path), fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

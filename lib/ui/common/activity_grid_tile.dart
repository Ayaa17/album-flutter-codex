import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/activity.dart';

class ActivityGridTile extends StatelessWidget {
  const ActivityGridTile({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onLongPress,
  });

  final Activity activity;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: activity.coverPhotoPath == null
                  ? Container(
                      width: double.infinity,
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      child: Icon(
                        Icons.photo_album_outlined,
                        color: colorScheme.primary,
                        size: 48,
                      ),
                    )
                  : Hero(
                      tag: 'activity_cover_${activity.id}',
                      child: Image.file(
                        File(activity.coverPhotoPath!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${activity.photoCount} photos',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

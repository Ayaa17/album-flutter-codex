import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/activity.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
    this.onMorePressed,
  });

  final Activity activity;
  final VoidCallback onTap;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (onMorePressed != null)
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: onMorePressed,
                            splashRadius: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created ${_formatDate(activity.createdAt)} · ${activity.photoCount} photos',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: activity.coverPhotoPath == null
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                          ),
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: colorScheme.primary,
                            size: 36,
                          ),
                        )
                      : Hero(
                          tag: 'activity_cover_${activity.id}',
                          child: Image.file(
                            File(activity.coverPhotoPath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/activity_detail/activity_detail_cubit.dart';
import '../../../blocs/activity_detail/activity_detail_state.dart';
import '../../../data/models/archery_models.dart';
import '../../common/empty_state.dart';
import 'round_summary.dart';

class RoundList extends StatefulWidget {
  const RoundList({
    super.key,
    required this.showAllRoundsOnTarget,
    required this.onAllRoundsToggle,
    required this.onRoundSelected,
  });

  final bool showAllRoundsOnTarget;
  final ValueChanged<bool> onAllRoundsToggle;
  final VoidCallback onRoundSelected;

  @override
  State<RoundList> createState() => _RoundListState();
}

class _RoundListState extends State<RoundList> {
  bool _isSummaryExpanded = false;

  @override
  void initState() {
    super.initState();
    _isSummaryExpanded = widget.showAllRoundsOnTarget;
  }

  @override
  void didUpdateWidget(covariant RoundList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showAllRoundsOnTarget != widget.showAllRoundsOnTarget) {
      _isSummaryExpanded = widget.showAllRoundsOnTarget;
    }
  }

  Future<void> _handlePhotoAction(
    BuildContext context,
    ActivityDetailCubit cubit,
    ArcheryRound round,
  ) async {
    final photoPath = round.photoPath;
    if (photoPath == null) {
      await cubit.attachPhoto(round.id);
      return;
    }

    final file = File(photoPath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo not found. Please capture a new one.'),
          duration: Duration(milliseconds: 300),
        ),
      );
      await cubit.attachPhoto(round.id);
      return;
    }

    final shouldReplace =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Round photo'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                  maxHeight: 480,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Replace photo'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldReplace) {
      await cubit.attachPhoto(round.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityDetailCubit, ActivityDetailState>(
      builder: (context, state) {
        if (state.rounds.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.flag_outlined,
              title: 'No rounds yet',
              message: 'Tap the Add Round button to start a new set.',
            ),
          );
        }

        final cubit = context.read<ActivityDetailCubit>();
        final rounds = state.rounds;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rounds.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return AllRoundsSummaryCard(
                rounds: rounds,
                isExpanded: _isSummaryExpanded,
                onToggle: () {
                  final next = !_isSummaryExpanded;
                  setState(() => _isSummaryExpanded = next);
                  widget.onAllRoundsToggle(next);
                },
              );
            }
            final round = rounds[index - 1];
            final isSelected = round.id == state.selectedRoundId;
            final roundNumber = index;

            return AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.02 : 1.0,
              child: Card(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.45)
                    : null,
                child: ListTile(
                  onTap: () {
                    setState(() => _isSummaryExpanded = false);
                    widget.onAllRoundsToggle(false);
                    widget.onRoundSelected();
                    cubit.selectRound(round.id);
                  },
                  leading: round.photoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(round.photoPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(child: Text('$roundNumber')),
                  title: Text('Round $roundNumber'),
                  subtitle: Text(
                    'Score: ${round.totalScore} - Arrows: ${round.arrows.length}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: round.photoPath == null
                            ? 'Attach photo'
                            : 'View photo',
                        onPressed: () =>
                            _handlePhotoAction(context, cubit, round),
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete round',
                        onPressed: () => cubit.deleteRound(round.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

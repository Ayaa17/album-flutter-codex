import 'package:flutter/material.dart';

import '../../../data/models/archery_models.dart';

class AllRoundsSummaryCard extends StatelessWidget {
  const AllRoundsSummaryCard({
    super.key,
    required this.rounds,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<ArcheryRound> rounds;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final totalRounds = rounds.length;
    final totalScore = rounds.fold<int>(
      0,
      (sum, round) => sum + round.totalScore,
    );
    final arrowCount = rounds.fold<int>(
      0,
      (sum, round) => sum + round.arrows.length,
    );
    final xCount = rounds.fold<int>(
      0,
      (sum, round) => sum + round.arrows.where((a) => a.isX).length,
    );
    final tenCount = rounds.fold<int>(
      0,
      (sum, round) =>
          sum + round.arrows.where((a) => a.score == 10 && !a.isX).length,
    );
    final totalTenCount = xCount + tenCount;

    final averageArrow = arrowCount == 0
        ? 0.0
        : totalScore.toDouble() / arrowCount;
    final tenRate = arrowCount == 0
        ? 0.0
        : (tenCount * 100.0) / arrowCount.toDouble();

    var bestScore = 0.0;
    var bestRoundIndex = 0;
    var worstScore = rounds.first.totalScore.toDouble();
    var worstRoundIndex = 0;

    for (var i = 0; i < rounds.length; i++) {
      final roundScore = rounds[i].averageScore;
      if (roundScore >= bestScore) {
        bestScore = roundScore;
        bestRoundIndex = i;
      }
      if (roundScore <= worstScore && rounds[i].arrows.isNotEmpty) {
        worstScore = roundScore;
        worstRoundIndex = i;
      }
    }

    return Card(
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'All rounds summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryStatChip(
                    label: 'Total score',
                    value: '$totalScore pts',
                  ),
                  _SummaryStatChip(label: 'X hits', value: '$xCount'),
                  _SummaryStatChip(label: 'X+10', value: '$totalTenCount'),
                  _SummaryStatChip(
                    label: 'Avg / arrow',
                    value: averageArrow.toStringAsFixed(2),
                  ),
                  _SummaryStatChip(label: 'Arrows', value: '$arrowCount'),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _DetailRow(label: 'Rounds logged', value: '$totalRounds'),
                _DetailRow(
                  label: '10s hit rate',
                  value:
                      '${tenRate.toStringAsFixed(1)}% ($tenCount / $arrowCount)',
                ),
                _DetailRow(label: 'X hits', value: '$xCount'),
                _DetailRow(label: 'X+10', value: '$totalTenCount'),
                _DetailRow(
                  label: 'Best round',
                  value:
                      'R${bestRoundIndex + 1} / ${bestScore.toStringAsFixed(2)} pts',
                ),
                _DetailRow(
                  label: 'Lowest round',
                  value:
                      'R${worstRoundIndex + 1} / ${worstScore.toStringAsFixed(2)} pts',
                ),
                _DetailRow(
                  label: 'Score spread',
                  value:
                      '${rounds[bestRoundIndex].totalScore - rounds[worstRoundIndex].totalScore} pts',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  const _SummaryStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

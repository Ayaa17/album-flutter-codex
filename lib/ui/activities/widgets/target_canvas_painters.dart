import 'package:flutter/material.dart';

import '../../../data/models/archery_models.dart';
import '../../../data/models/target_face.dart';
import '../../../data/repositories/archery_repository.dart';

class TargetCanvasArrow {
  const TargetCanvasArrow({required this.arrow, required this.isSelectedRound});

  final ArrowHit arrow;
  final bool isSelectedRound;
}

class ArcheryTargetPainter extends CustomPainter {
  ArcheryTargetPainter({
    required this.arrows,
    this.highlightedArrowId,
    required this.targetFaceType,
  });

  final List<TargetCanvasArrow> arrows;
  final String? highlightedArrowId;
  final TargetFaceType targetFaceType;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final spots = targetFaceType.layoutSpots(size);
    if (spots.isEmpty) return;

    final rings = _ringsFor(targetFaceType);
    final ringCount = rings.length;

    for (final spot in spots) {
      paint
        ..style = PaintingStyle.fill
        ..strokeWidth = 1.0;
      for (var i = ringCount; i >= 1; i--) {
        final ringRadius = spot.radius * (i / ringCount);
        paint.color = rings[i - 1];
        canvas.drawCircle(spot.center, ringRadius, paint);
      }

      paint
        ..color = Colors.black54
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(spot.center, spot.radius, paint);

      final xRatio = _xRingRatio(targetFaceType);
      if (xRatio != null) {
        paint
          ..color = Colors.black45
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(spot.center, spot.radius * xRatio, paint);
      }
    }

    for (final targetArrow in arrows) {
      final arrow = targetArrow.arrow;
      final isHighlighted = arrow.id == highlightedArrowId;
      final spotIndex = arrow.targetIndex.clamp(0, spots.length - 1);
      final spot = spots[spotIndex];
      final scale = spot.radius / ArcheryRepository.targetRadius;
      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isHighlighted
            ? Colors.orange
            : targetArrow.isSelectedRound
            ? Colors.deepPurple
            : Colors.deepPurple.withValues(alpha: 0.55);
      final absolute = spot.center + arrow.position * scale;
      canvas.drawCircle(absolute, isHighlighted ? 8 : 6, arrowPaint);
      if (isHighlighted) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.orangeAccent.withValues(alpha: 0.9);
        canvas.drawCircle(absolute, 14, ring);
      }
      final textPainter = TextPainter(
        text: TextSpan(
          text: arrow.isX ? 'X' : '${arrow.score}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: 24);
      textPainter.paint(
        canvas,
        absolute.translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ArcheryTargetPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.highlightedArrowId != highlightedArrowId ||
        oldDelegate.targetFaceType != targetFaceType;
  }

  List<Color> _ringsFor(TargetFaceType type) {
    switch (type) {
      case TargetFaceType.half80cmSixRing:
        return [
          Colors.yellow,
          Colors.yellow.shade700,
          Colors.red,
          Colors.red.shade900,
          Colors.blue,
        ];
      case TargetFaceType.verticalTripleSixRing:
        return [
          Colors.yellow,
          Colors.yellow.shade700,
          Colors.red,
          Colors.red.shade900,
          Colors.blue,
        ];
      case TargetFaceType.triangularTripleSixRing:
        return [
          Colors.yellow,
          Colors.yellow.shade700,
          Colors.red,
          Colors.red.shade900,
          Colors.blue,
        ];
      case TargetFaceType.fullTenRing:
        return [
          Colors.yellow,
          Colors.yellow.shade700,
          Colors.red,
          Colors.red.shade900,
          Colors.blue,
          Colors.blue.shade900,
          Colors.black,
          Colors.black87,
          Colors.white,
          Colors.white,
        ];
    }
  }

  double? _xRingRatio(TargetFaceType type) {
    switch (type) {
      case TargetFaceType.fullTenRing:
        return 0.05;
      case TargetFaceType.half80cmSixRing:
      case TargetFaceType.verticalTripleSixRing:
      case TargetFaceType.triangularTripleSixRing:
        return 0.10;
    }
  }
}

class CrosshairPainter extends CustomPainter {
  const CrosshairPainter({required this.position});

  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(position.dx, 0),
      Offset(position.dx, size.height),
      guidePaint,
    );
    canvas.drawLine(
      Offset(0, position.dy),
      Offset(size.width, position.dy),
      guidePaint,
    );

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.orangeAccent;
    canvas.drawCircle(position, 12, circlePaint);

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.orangeAccent;
    canvas.drawCircle(position, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CrosshairPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

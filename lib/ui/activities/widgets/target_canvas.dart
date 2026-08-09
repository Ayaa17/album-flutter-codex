import 'package:flutter/material.dart';

import '../../../data/models/target_face.dart';
import 'target_canvas_painters.dart';

class TargetCanvas extends StatelessWidget {
  const TargetCanvas({
    super.key,
    required this.targetSize,
    required this.arrows,
    required this.targetFaceType,
    required this.highlightedArrowId,
    required this.crosshairPosition,
    required this.onTapPreview,
    required this.onTapCommit,
    required this.onDragPreview,
    required this.onDragCommit,
    required this.onCancel,
  });

  final Size targetSize;
  final List<TargetCanvasArrow> arrows;
  final TargetFaceType targetFaceType;
  final String? highlightedArrowId;
  final Offset? crosshairPosition;
  final ValueChanged<Offset> onTapPreview;
  final ValueChanged<Offset> onTapCommit;
  final ValueChanged<Offset> onDragPreview;
  final VoidCallback onDragCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => onTapPreview(details.localPosition),
      onTapUp: (details) => onTapCommit(details.localPosition),
      onTapCancel: onCancel,
      onPanStart: (details) => onDragPreview(details.localPosition),
      onPanUpdate: (details) => onDragPreview(details.localPosition),
      onPanEnd: (_) => onDragCommit(),
      onPanCancel: onCancel,
      child: SizedBox(
        width: targetSize.width,
        height: targetSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: ArcheryTargetPainter(
                arrows: arrows,
                highlightedArrowId: highlightedArrowId,
                targetFaceType: targetFaceType,
              ),
            ),
            if (crosshairPosition != null)
              CustomPaint(
                painter: CrosshairPainter(position: crosshairPosition!),
              ),
          ],
        ),
      ),
    );
  }
}

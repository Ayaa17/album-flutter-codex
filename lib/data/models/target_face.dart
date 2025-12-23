import 'dart:math' as math;
import 'dart:ui';

enum TargetFaceType {
  fullTenRing,
  half80cmSixRing,
  verticalTripleSixRing,
}

extension TargetFaceTypeX on TargetFaceType {
  String get label {
    switch (this) {
      case TargetFaceType.fullTenRing:
        return 'Full 10-ring';
      case TargetFaceType.half80cmSixRing:
        return '80cm 6-ring (6-10 only)';
      case TargetFaceType.verticalTripleSixRing:
        return '40cm vertical triple (6-10)';
    }
  }

  String get description {
    switch (this) {
      case TargetFaceType.fullTenRing:
        return 'Standard 1-10 scoring rings.';
      case TargetFaceType.half80cmSixRing:
        return '80cm target face with only 6-10 rings; outside is 0.';
      case TargetFaceType.verticalTripleSixRing:
        return 'Three stacked 40cm faces (6-10 only), vertical strip.';
    }
  }

  String get storageKey {
    switch (this) {
      case TargetFaceType.fullTenRing:
        return 'full_ten';
      case TargetFaceType.half80cmSixRing:
        return 'half_80cm_6ring';
      case TargetFaceType.verticalTripleSixRing:
        return 'vertical_triple_6ring';
    }
  }

  static TargetFaceType fromStorage(String? raw) {
    switch (raw) {
      case 'half_80cm_6ring':
        return TargetFaceType.half80cmSixRing;
      case 'vertical_triple_6ring':
        return TargetFaceType.verticalTripleSixRing;
      case 'full_ten':
      default:
        return TargetFaceType.fullTenRing;
    }
  }

  List<TargetSpot> layoutSpots(Size size) {
    switch (this) {
      case TargetFaceType.fullTenRing:
      case TargetFaceType.half80cmSixRing:
        final radius = math.min(size.width, size.height) / 2;
        return [
          TargetSpot(center: Offset(size.width / 2, size.height / 2), radius: radius),
        ];
      case TargetFaceType.verticalTripleSixRing:
        final radius = math.min(size.width / 2, size.height / 6);
        return [
          TargetSpot(center: Offset(size.width / 2, radius), radius: radius),
          TargetSpot(center: Offset(size.width / 2, size.height / 2), radius: radius),
          TargetSpot(center: Offset(size.width / 2, size.height - radius), radius: radius),
        ];
    }
  }
}

class TargetSpot {
  const TargetSpot({required this.center, required this.radius});

  final Offset center;
  final double radius;
}

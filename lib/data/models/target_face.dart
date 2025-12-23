enum TargetFaceType {
  fullTenRing,
  half80cmSixRing,
}

extension TargetFaceTypeX on TargetFaceType {
  String get label {
    switch (this) {
      case TargetFaceType.fullTenRing:
        return 'Full 10-ring';
      case TargetFaceType.half80cmSixRing:
        return '80cm 6-ring (6-10 only)';
    }
  }

  String get description {
    switch (this) {
      case TargetFaceType.fullTenRing:
        return 'Standard 1-10 scoring rings.';
      case TargetFaceType.half80cmSixRing:
        return '80cm target face with only 6-10 rings; outside is 0.';
    }
  }

  String get storageKey {
    switch (this) {
      case TargetFaceType.fullTenRing:
        return 'full_ten';
      case TargetFaceType.half80cmSixRing:
        return 'half_80cm_6ring';
    }
  }

  static TargetFaceType fromStorage(String? raw) {
    switch (raw) {
      case 'half_80cm_6ring':
        return TargetFaceType.half80cmSixRing;
      case 'full_ten':
      default:
        return TargetFaceType.fullTenRing;
    }
  }
}

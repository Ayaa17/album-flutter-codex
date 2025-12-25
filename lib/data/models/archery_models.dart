import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ArrowHit extends Equatable {
  const ArrowHit({
    required this.id,
    required this.position,
    required this.score,
    required this.createdAt,
    required this.targetIndex,
  });

  ArrowHit createCopy({Offset? position, int? score, int? targetIndex}) {
    return ArrowHit(
      id: id,
      position: position ?? this.position,
      score: score ?? this.score,
      createdAt: createdAt,
      targetIndex: targetIndex ?? this.targetIndex,
    );
  }

  factory ArrowHit.fromMap(Map<String, dynamic> map) {
    return ArrowHit(
      id: map['id'] as String? ?? _uuid.v4(),
      position: Offset(
        (map['dx'] as num?)?.toDouble() ?? 0,
        (map['dy'] as num?)?.toDouble() ?? 0,
      ),
      score: map['score'] as int? ?? 0,
      targetIndex: map['targetIndex'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dx': position.dx,
      'dy': position.dy,
      'score': score,
      'targetIndex': targetIndex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  final String id;
  final Offset position;
  final int score;
  final DateTime createdAt;
  final int targetIndex;

  @override
  List<Object?> get props => [
    id,
    position.dx,
    position.dy,
    score,
    createdAt,
    targetIndex,
  ];
}

class ArcheryRound extends Equatable {
  const ArcheryRound({
    required this.id,
    required this.createdAt,
    this.photoPath,
    this.arrows = const <ArrowHit>[],
  });

  ArcheryRound copyWith({List<ArrowHit>? arrows, String? photoPath}) {
    return ArcheryRound(
      id: id,
      createdAt: createdAt,
      photoPath: photoPath ?? this.photoPath,
      arrows: arrows ?? this.arrows,
    );
  }

  int get totalScore => arrows.fold(0, (sum, arrow) => sum + arrow.score);
  double get averageScore {
    if (arrows.isEmpty) return 0.0;
    return totalScore / arrows.length;
  }
  factory ArcheryRound.create() {
    return ArcheryRound(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      arrows: const [],
    );
  }

  factory ArcheryRound.fromMap(Map<String, dynamic> map) {
    final arrowList = (map['arrows'] as List<dynamic>? ?? [])
        .map((raw) => ArrowHit.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();
    return ArcheryRound(
      id: map['id'] as String? ?? _uuid.v4(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      photoPath: map['photoPath'] as String?,
      arrows: arrowList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'photoPath': photoPath,
      'arrows': arrows.map((arrow) => arrow.toMap()).toList(),
    };
  }

  final String id;
  final DateTime createdAt;
  final String? photoPath;
  final List<ArrowHit> arrows;

  @override
  List<Object?> get props => [
    id,
    createdAt,
    photoPath,
    jsonEncode(arrows.map((a) => a.toMap())),
  ];
}

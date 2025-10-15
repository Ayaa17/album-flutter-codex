import 'package:equatable/equatable.dart';

class PhotoEntry extends Equatable {
  const PhotoEntry({
    required this.path,
    required this.createdAt,
  });

  final String path;
  final DateTime createdAt;

  @override
  List<Object?> get props => [path, createdAt];
}

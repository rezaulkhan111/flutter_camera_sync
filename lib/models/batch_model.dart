class ImageBatch {
  final int? id;
  final String name;
  final DateTime createdAt;
  final String status; // 'pending', 'syncing', 'synced', 'failed'

  ImageBatch({
    this.id,
    required this.name,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory ImageBatch.fromMap(Map<String, dynamic> map) {
    return ImageBatch(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      status: map['status'] as String,
    );
  }
}

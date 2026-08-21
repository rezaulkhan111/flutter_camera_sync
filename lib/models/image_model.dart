class ImageModel {
  final int? id;
  final String path;
  final int batchId;
  final String status; // 'pending', 'syncing', 'synced', 'failed'
  final int retryCount;

  ImageModel({
    this.id,
    required this.path,
    required this.batchId,
    this.status = 'pending',
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'batchId': batchId,
      'status': status,
      'retryCount': retryCount,
    };
  }

  factory ImageModel.fromMap(Map<String, dynamic> map) {
    return ImageModel(
      id: map['id'] as int?,
      path: map['path'] as String,
      batchId: map['batchId'] as int,
      status: map['status'] as String,
      retryCount: map['retryCount'] as int,
    );
  }
}

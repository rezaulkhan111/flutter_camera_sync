import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/batch_model.dart';
import '../models/image_model.dart';
import '../services/sync_service.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

class UploadManagerScreen extends StatefulWidget {
  const UploadManagerScreen({super.key});

  @override
  State<UploadManagerScreen> createState() => _UploadManagerScreenState();
}

class _UploadManagerScreenState extends State<UploadManagerScreen> {
  List<ImageBatch> _batches = [];
  Map<int, List<ImageModel>> _batchImages = {};
  bool _isOnline = true;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkConnectivity();
    _checkPauseStatus();
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() {
          _isOnline = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkPauseStatus() async {
    final paused = await DatabaseService.instance.isSyncPaused();
    if (mounted) {
      setState(() {
        _isPaused = paused;
      });
    }
  }

  Future<void> _togglePause() async {
    await SyncService.togglePause();
    await _checkPauseStatus();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _loadData() async {
    final db = DatabaseService.instance;
    final batches = await db.getAllBatches();
    Map<int, List<ImageModel>> batchImagesMap = {};
    for (var batch in batches) {
      final images = await db.getImagesForBatch(batch.id!);
      batchImagesMap[batch.id!] = images;
    }
    if (mounted) {
      setState(() {
        _batches = batches;
        _batchImages = batchImagesMap;
      });
    }

    await _checkPauseStatus();

    if (batches.any((b) => b.status != 'synced') && mounted) {
      Future.delayed(const Duration(seconds: 2), _loadData);
    }
  }

  @override
  Widget build(BuildContext context) {
    int pendingCount = 0;
    _batchImages.forEach((key, value) {
      pendingCount += value.where((img) => img.status != 'synced').length;
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Upload Manager",
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline ? "STABLE LINK" : "OFFLINE",
                  style: TextStyle(
                    color: _isOnline ? Colors.green : Colors.red,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "BATCH SYNC PROGRESS",
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              value: 0.74,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "2.4 GB / 3.2 GB Uploaded",
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: _togglePause,
                  child: Text(
                    _isPaused ? "RESUME ALL" : "PAUSE ALL",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "PENDING UPLOADS ($pendingCount)",
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _batches.length,
                itemBuilder: (context, index) {
                  final batch = _batches[index];
                  final images = _batchImages[batch.id!] ?? [];
                  return Column(
                    children: images
                        .map((img) => _buildUploadItem(img))
                        .toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SafeArea(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("START NEW UPLOAD BATCH"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadItem(ImageModel image) {
    String statusText = "";
    Color statusColor = Colors.grey;
    Widget? trailing;

    switch (image.status) {
      case 'pending':
        statusText = "WAITING FOR CONNECTION";
        statusColor = Colors.orange;
        break;
      case 'syncing':
        statusText = "UPLOADING...";
        statusColor = Colors.blue;
        trailing = const Text(
          "42 MB/s",
          style: TextStyle(color: Colors.blue, fontSize: 10),
        );
        break;
      case 'synced':
        statusText = "SYNCED";
        statusColor = Colors.green;
        trailing = const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 16,
        );
        break;
      case 'failed':
        statusText = "RETRYING... (ATTEMPT ${image.retryCount}/5)";
        statusColor = Colors.redAccent;
        break;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: isDark ? null : Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(File(image.path)),
                fit: BoxFit.cover,
                opacity: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.basename(image.path),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[trailing],
                  ],
                ),
                Text(
                  "85 MB",
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (image.status == 'syncing') ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    value: 0.65,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 2,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

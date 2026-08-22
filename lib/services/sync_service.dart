import 'package:workmanager/workmanager.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    debugPrint("Native called background task: $task");

    try {
      final dbService = DatabaseService.instance;

      if (await dbService.isSyncPaused()) {
        debugPrint("Sync is paused. Skipping background task.");
        return true;
      }

      final pendingImages = await dbService.getPendingImages();

      if (pendingImages.isEmpty) return true;

      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      for (var image in pendingImages) {
        try {
          await dbService.updateImageStatus(image.id!, 'syncing');
          bool success = await ApiService.uploadImage(image.path);

          if (success) {
            await dbService.updateImageStatus(image.id!, 'synced');
          } else {
            await dbService.updateImageStatus(
              image.id!,
              'failed',
              retryCount: image.retryCount + 1,
            );
          }
        } catch (e) {
          debugPrint("Error uploading image ${image.id}: $e");
        }
      }

      final batches = await dbService.getAllBatches();
      for (var batch in batches) {
        final batchImages = await dbService.getImagesForBatch(batch.id!);
        if (batchImages.isNotEmpty &&
            batchImages.every((img) => img.status == 'synced')) {
          await dbService.updateBatchStatus(batch.id!, 'synced');
        }
      }
    } catch (e) {
      debugPrint("Background task error: $e");
      return false;
    }

    return true;
  });
}

class SyncService {
  static void init() {
    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  static void scheduleSync() {
    Workmanager().registerOneOffTask(
      "syncTask",
      "syncImages",
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> togglePause() async {
    final db = DatabaseService.instance;
    final isPaused = await db.isSyncPaused();
    await db.setSyncPaused(!isPaused);
    if (isPaused) {
      scheduleSync();
    } else {
      Workmanager().cancelAll();
    }
  }
}

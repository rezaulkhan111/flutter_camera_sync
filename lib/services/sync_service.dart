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
      final pendingImages = await dbService.getPendingImages();

      if (pendingImages.isEmpty) return true;

      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false; // Retry later
      }

      for (var image in pendingImages) {
        try {
          // Update status to syncing
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

      // Check batches and update their status if all images are synced
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
}

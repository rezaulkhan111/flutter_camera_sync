import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/database_service.dart';
import '../models/batch_model.dart';
import '../models/image_model.dart';
import 'upload_manager_screen.dart';
import '../services/sync_service.dart';

class CameraPreviewScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final VoidCallback onThemeToggle;

  const CameraPreviewScreen({
    super.key,
    required this.cameras,
    required this.onThemeToggle,
  });

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _baseScale = 1.0;
  int _pointers = 0;

  Offset? _focusPoint;

  final List<XFile> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isEmpty) {
      _initializeControllerFuture = Future.error("No cameras available");
      return;
    }
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);

    _initializeControllerFuture = _controller.initialize().then((_) async {
      _minAvailableZoom = await _controller.getMinZoomLevel();
      _maxAvailableZoom = await _controller.getMaxZoomLevel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoomLevel;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not 2 pointers on screen, no scaling happens
    if (_pointers != 2) {
      return;
    }

    _currentZoomLevel = (_baseScale * details.scale).clamp(
      _minAvailableZoom,
      _maxAvailableZoom,
    );

    await _controller.setZoomLevel(_currentZoomLevel);
    setState(() {});
  }

  void _onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    _controller.setFocusPoint(offset);
    _controller.setExposurePoint(offset);

    setState(() {
      _focusPoint = details.localPosition;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _focusPoint = null;
        });
      }
    });
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      setState(() {
        _capturedImages.add(image);
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _uploadBatch() async {
    if (_capturedImages.isEmpty) return;

    final db = DatabaseService.instance;
    final batchId = await db.insertBatch(
      ImageBatch(
        name: "Batch ${DateTime.now().millisecondsSinceEpoch}",
        createdAt: DateTime.now(),
      ),
    );

    for (var file in _capturedImages) {
      // Move file to permanent storage
      final directory = await getApplicationDocumentsDirectory();
      final name = p.basename(file.path);
      final newPath = p.join(directory.path, name);
      await file.saveTo(newPath);

      await db.insertImage(ImageModel(path: newPath, batchId: batchId));
    }

    setState(() {
      _capturedImages.clear();
    });

    SyncService.scheduleSync();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              UploadManagerScreen(onThemeToggle: widget.onThemeToggle),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Camera Preview
                    Listener(
                      onPointerDown: (_) => _pointers++,
                      onPointerUp: (_) => _pointers--,
                      child: GestureDetector(
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onTapDown: (details) =>
                            _onViewFinderTap(details, constraints),
                        child: Center(child: CameraPreview(_controller)),
                      ),
                    ),

                    // Focus Indicator
                    if (_focusPoint != null)
                      Positioned(
                        left: _focusPoint!.dx - 30,
                        top: _focusPoint!.dy - 30,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),

                    // Top Controls
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text(
                              "VISUAL",
                              style: TextStyle(
                                color: Colors.white,
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.flash_on,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: Icon(
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Icons.light_mode
                                        : Icons.dark_mode,
                                    color: Colors.white,
                                  ),
                                  onPressed: widget.onThemeToggle,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Zoom Slider (Right side)
                    Positioned(
                      right: 16,
                      top: constraints.maxHeight * 0.3,
                      bottom: constraints.maxHeight * 0.3,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _currentZoomLevel,
                            min: _minAvailableZoom,
                            max: _maxAvailableZoom,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white30,
                            onChanged: (value) async {
                              setState(() {
                                _currentZoomLevel = value;
                              });
                              await _controller.setZoomLevel(value);
                            },
                          ),
                        ),
                      ),
                    ),

                    // Zoom Buttons
                    Positioned(
                      bottom: 180,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_minAvailableZoom < 1.0) ...[
                            _zoomButton(_minAvailableZoom, label: "0.5"),
                            const SizedBox(width: 16),
                          ],
                          _zoomButton(1.0),
                          if (_maxAvailableZoom >= 2.0) ...[
                            const SizedBox(width: 16),
                            _zoomButton(2.0),
                          ],
                        ],
                      ),
                    ),

                    // Bottom Controls
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Gallery/Last Image Preview
                              Stack(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_capturedImages.isNotEmpty)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          "${_capturedImages.length}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              // Shutter Button
                              GestureDetector(
                                onTap: _takePicture,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Switch Camera
                              IconButton(
                                icon: const Icon(
                                  Icons.sync,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_capturedImages.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _uploadBatch,
                                icon: const Icon(Icons.upload),
                                label: Text(
                                  "UPLOAD BATCH (${_capturedImages.length})",
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _zoomButton(double zoom, {String? label}) {
    bool isSelected = (_currentZoomLevel - zoom).abs() < 0.1;
    return GestureDetector(
      onTap: () async {
        double targetZoom = zoom.clamp(_minAvailableZoom, _maxAvailableZoom);
        await _controller.setZoomLevel(targetZoom);
        setState(() {
          _currentZoomLevel = targetZoom;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            "${label ?? zoom.toInt()}x",
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

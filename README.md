# Flutter Camera Sync

A resilient and feature-rich Flutter application for capturing image batches with an advanced camera UI and a background synchronization engine designed to handle intermittent connectivity gracefully.

## Project Description
This application provides a robust solution for batch image capture and synchronization. It features a custom-built camera interface with professional-grade controls, including pinch-to-zoom and manual tap-to-focus with visual feedback. Captured batches are queued in a local SQLite database and synchronized to a mock API via a resilient background worker. The sync engine is designed to monitor network states and automatically retry failed uploads without requiring user intervention, ensuring reliable performance in areas with poor connectivity.

## Project Structure / Approaches
The project follows a **Layered Architecture** (Models, Services, Screens, and Widgets) for clear separation of concerns:

- **Service Pattern**: Business logic is decoupled from the UI. `SyncService` coordinates background tasks via `Workmanager`, while `DatabaseService` manages persistence.
- **State Management**: Uses `StatefulWidget` lifecycle methods and a service-oriented approach to maintain consistency between local storage and remote sync status.
- **Robust Persistence**: Employs `sqflite` for a transaction-safe local queue, ensuring that image metadata and sync attempts are preserved even if the application process is terminated.

## Technical Highlights
- **Resilient Sync Engine**: Specifically engineered to handle "dead zones" by using Workmanager constraints. It only triggers synchronization when the device detects a stable network link.
- **Advanced Camera Gestures**: Implements manual focus/exposure point calculations and a smooth pinch-to-zoom experience using `ScaleGestureDetector` and native camera APIs.
- **Adaptive UI**: A modern Material 3 implementation that dynamically responds to system theme changes or manual toggles, maintaining high contrast and readability in both Light and Dark modes.

## How to Run
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/rezaulkhan111/flutter_camera_sync.git
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Ensure Environment Readiness:**
    - Connect an Android device (Physical device recommended for camera testing).
    - Minimum Android SDK: 21.
    - Android Gradle Plugin: 8.9.1.
4.  **Run the application:**
    ```bash
    flutter run --android-skip-build-dependency-validation
    ```

## Screenshots
<html>
<table border="0">
  <tr>
    <td align="center">Camera UI<br/><img src="https://raw.githubusercontent.com/rezaulkhan111/flutter_camera_sync/refs/heads/master/photo/camera.jpeg" width="200" /></td>
    <td align="center">Upload Manager<br/><img src="https://raw.githubusercontent.com/rezaulkhan111/flutter_camera_sync/refs/heads/master/photo/upload.jpeg" width="200" /></td>
  </tr>
<tr>
<td align="center">Live App Demo<br/><img src="https://raw.githubusercontent.com/rezaulkhan111/flutter_camera_sync/refs/heads/master/photo/camera_sync.gif" width="200" /></td>
</tr>
</table>
</html>

## APK Submission

The release APK can be downloaded from the following link:
[Link to Release APK](https://raw.githubusercontent.com/rezaulkhan111/flutter_camera_sync/refs/heads/master/photo/camera_sync_app_release.apk)

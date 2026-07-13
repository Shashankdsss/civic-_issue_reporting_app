import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// Simulates automatic status progression for civic issue reports.
/// After a report is submitted, it progresses:
///   Reported → Verified → In Progress → Resolved
/// with configurable time delays between each stage.
class StatusSimulationService {
  // Time delays between status transitions (seconds)
  static const int _verifiedDelay = 30;
  static const int _inProgressDelay = 60;
  static const int _resolvedDelay = 90;

  /// Starts automatic status progression for a given report.
  /// 1. Immediately schedules offline OS notifications.
  /// 2. Schedules in-memory Firestore updates for real-time UI.
  static void startProgression(String reportId, String category) {
    debugPrint('[StatusSim] Starting progression for report: $reportId');

    // Generate unique numerical IDs for the 3 notifications based on report string
    final int baseId = reportId.hashCode.abs() % 100000;

    // --- 1. Schedule OS-level Background Notifications ---
    // These are registered with the OS immediately and will fire even if app dies.
    NotificationService.scheduleOSNotification(
      id: baseId + 1,
      title: 'Report Verified ✅',
      body: 'Your $category report has been verified by an official.',
      delaySeconds: _verifiedDelay,
    );
    NotificationService.scheduleOSNotification(
      id: baseId + 2,
      title: 'Work In Progress 🔧',
      body: 'Repair/construction work has started on your $category issue.',
      delaySeconds: _inProgressDelay,
    );
    NotificationService.scheduleOSNotification(
      id: baseId + 3,
      title: 'Issue Resolved 🎉',
      body: 'Your $category issue has been officially resolved!',
      delaySeconds: _resolvedDelay,
    );

    // --- 2. Real-time Firebase Updates (if app stays open) ---
    Future.delayed(const Duration(seconds: _verifiedDelay), () async {
      try {
        await FirestoreService.updateReportStatusWithTimestamp(reportId, 'Verified');
        await FirestoreService.insertNotification('Status: Verified ✅', 'Your $category report has been verified by an official.');
      } catch (_) {}
    });

    Future.delayed(const Duration(seconds: _inProgressDelay), () async {
      try {
        await FirestoreService.updateReportStatusWithTimestamp(reportId, 'In Progress');
        await FirestoreService.insertNotification('Status: In Progress 🔧', 'Work has begun on your $category report.');
      } catch (_) {}
    });

    Future.delayed(const Duration(seconds: _resolvedDelay), () async {
      try {
        await FirestoreService.updateReportStatusWithTimestamp(reportId, 'Resolved');
        await FirestoreService.insertNotification('Status: Resolved 🎉', 'Your $category report has been resolved! Please provide feedback.');
      } catch (_) {}
    });
  }

  /// Called on app startup to retroactively update Firestore for simulated reports
  /// in case the user submitted a report and then completely killed the app.
  static Future<void> catchUpMissedUpdates() async {
    try {
      final reports = await FirestoreService.getReports();
      final now = DateTime.now();

      for (var report in reports) {
        final String? timestampStr = report['timestamp'];
        final String status = report['status'] ?? 'Pending';
        if (timestampStr == null) continue;
        
        // Skip already fully resolved reports
        if (status == 'Resolved') continue;

        final createdAt = DateTime.parse(timestampStr);
        final elapsedSeconds = now.difference(createdAt).inSeconds;
        final reportId = report['id'] as String;

        // Retroactively progress status based on elapsed time since creation
        if (elapsedSeconds >= _resolvedDelay && status != 'Resolved') {
          await FirestoreService.updateReportStatusWithTimestamp(reportId, 'Resolved');
        } else if (elapsedSeconds >= _inProgressDelay && status == 'Verified' && status != 'In Progress') {
          await FirestoreService.updateReportStatusWithTimestamp(reportId, 'In Progress');
        } else if (elapsedSeconds >= _verifiedDelay && status == 'Reported' && status != 'Verified') {
          await FirestoreService.updateReportStatusWithTimestamp(reportId, 'Verified');
        }
      }
    } catch (_) {}
  }
}

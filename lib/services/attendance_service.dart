import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final ImagePicker _picker = ImagePicker();

  final Set<String> _notifiedSessionIds = {};
  bool _notificationsReady = false;

  Future<void> initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'attendance_alerts',
      'Attendance Alerts',
      description: 'Notifies when an attendance session is starting soon',
      importance: Importance.high,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();

    _notificationsReady = true;
  }

  Future<void> triggerNearTimeAlert(
      String sessionId, String title, int minutesLeft) async {
    if (!_notificationsReady || _notifiedSessionIds.contains(sessionId)) return;
    _notifiedSessionIds.add(sessionId);

    const details = AndroidNotificationDetails(
      'attendance_alerts',
      'Attendance Alerts',
      channelDescription: 'Notifies when an attendance session is starting soon',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      sessionId.hashCode,
      'Log Pose Alert: Starting Soon!',
      '$title begins in $minutesLeft minute${minutesLeft == 1 ? '' : 's'}. Head to the location.',
      const NotificationDetails(android: details),
    );
  }

  Future<Map<String, String>> fetchStudentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'name': 'Crew Member', 'id': '', 'yearLevel': ''};
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, student_id, year_level')
          .eq('id', user.id)
          .maybeSingle();

      final name = profile?['full_name']?.toString().trim() ?? '';
      return {
        'name': name.isNotEmpty ? name : 'Crew Member',
        'id': profile?['student_id']?.toString().trim() ??
            (user.userMetadata?['id_number']?.toString() ?? ''),
        'yearLevel': profile?['year_level']?.toString().trim() ?? '',
      };
    } catch (_) {
      return {
        'name': 'Crew Member',
        'id': user.userMetadata?['id_number']?.toString() ?? '',
        'yearLevel': '',
      };
    }
  }

  Future<Set<String>> fetchCheckedInSessionIds() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final logs = await _supabase
        .from('attendance_logs')
        .select('session_id')
        .eq('student_id', userId);

    return logs.map<String>((row) => row['session_id'].toString()).toSet();
  }

  Future<LatLng?> getCurrentLatLng() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  /// Captures a live front-camera selfie, validates GPS/geofence, and uploads verification photo
  Future<({bool success, String message})> submitCheckIn(
      String sessionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('You must be logged in to check in.');
    }

    // 1. Require a live front-camera selfie (gallery uploads are not permitted)
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 65,
      maxWidth: 720,
    );

    if (photo == null) {
      throw Exception('Live selfie photo is required to verify attendance.');
    }

    // 2. Verify Location Services & Permissions
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please enable GPS / Location Services.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to check in.');
    }

    // 3. Get High-Accuracy Position & Block Mock Locations
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10),
      ),
    );

    if (position.isMocked) {
      throw Exception(
        'Mock location detected! Disable fake GPS apps to register attendance.',
      );
    }

    // 4. Validate Geofence via PostGIS RPC
    final response = await _supabase.rpc(
      'submit_attendance',
      params: {
        'p_session_id': sessionId,
        'p_lat': position.latitude,
        'p_lng': position.longitude,
      },
    );

    if (response is! Map) {
      throw Exception('Unexpected response from attendance service.');
    }

    final result = Map<String, dynamic>.from(response);
    final success = result['success'] == true;
    final message = result['message']?.toString() ?? 'Unknown response';

    // 5. If inside geofence, upload live selfie & attach URL to attendance_logs
    if (success) {
      try {
        final filePath =
            '$sessionId/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await File(photo.path).readAsBytes();

        await _supabase.storage.from('attendance-selfies').uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        final publicUrl = _supabase.storage
            .from('attendance-selfies')
            .getPublicUrl(filePath);

        await _supabase
            .from('attendance_logs')
            .update({'selfie_url': publicUrl})
            .eq('session_id', sessionId)
            .eq('student_id', userId);
      } catch (_) {
        // Check-in already succeeded; ignore storage error if network blips
      }
    }

    return (success: success, message: message);
  }
}
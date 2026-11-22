import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentAttendanceRecord {
  final String idNumber;
  final String fullName;
  final String yearLevel;
  final bool isPresent;
  final DateTime? checkedInAt;
  final String? selfieUrl;

  const StudentAttendanceRecord({
    required this.idNumber,
    required this.fullName,
    required this.yearLevel,
    required this.isPresent,
    this.checkedInAt,
    this.selfieUrl,
  });
}

class AdminSessionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<LatLng?> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    }
    return null;
  }

  Future<void> publishSession({
    required String title,
    required DateTime date,
    required TimeOfDay time,
    required int durationMinutes,
    required LatLng center,
    required int radiusMeters,
  }) async {
    final localStart = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final localEnd = localStart.add(Duration(minutes: durationMinutes));

    await _supabase.rpc(
      'create_attendance_session',
      params: {
        'p_title': title.trim(),
        'p_start_time': localStart.toUtc().toIso8601String(),
        'p_end_time': localEnd.toUtc().toIso8601String(),
        'p_lat': center.latitude,
        'p_lng': center.longitude,
        'p_radius_meters': radiusMeters,
      },
    );
  }

  Future<void> updateSession({
    required String sessionId,
    required String title,
    required DateTime date,
    required TimeOfDay time,
    required int durationMinutes,
    required LatLng center,
    required int radiusMeters,
  }) async {
    final localStart = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final localEnd = localStart.add(Duration(minutes: durationMinutes));

    await _supabase.rpc(
      'update_attendance_session',
      params: {
        'p_session_id': sessionId,
        'p_title': title.trim(),
        'p_start_time': localStart.toUtc().toIso8601String(),
        'p_end_time': localEnd.toUtc().toIso8601String(),
        'p_lat': center.latitude,
        'p_lng': center.longitude,
        'p_radius_meters': radiusMeters,
      },
    );
  }

  Future<void> deleteSession(String sessionId) async {
    // Delete associated attendance logs first in case foreign key lacks ON DELETE CASCADE
    await _supabase
        .from('attendance_logs')
        .delete()
        .eq('session_id', sessionId);

    await _supabase
        .from('attendance_sessions')
        .delete()
        .eq('id', sessionId);
  }

  Future<List<Map<String, dynamic>>> fetchAllSessions() async {
    final rows = await _supabase
        .from('attendance_sessions')
        .select('id, title, start_time, end_time, radius_meters, lat, lng')
        .order('start_time', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  String normalizeYearLevel(dynamic raw) {
    final s = (raw?.toString() ?? '').trim().toLowerCase();
    if (s.contains('1') || s.contains('first') || s == 'i') return '1st Year';
    if (s.contains('2') || s.contains('second') || s == 'ii') return '2nd Year';
    if (s.contains('3') || s.contains('third') || s == 'iii') return '3rd Year';
    if (s.contains('4') || s.contains('fourth') || s == 'iv') return '4th Year';
    return 'Other';
  }

  Future<List<StudentAttendanceRecord>> fetchSessionAnalytics(
      String sessionId) async {
    final response = await _supabase.rpc(
      'get_session_analytics',
      params: {'p_session_id': sessionId},
    );

    final rows = List<Map<String, dynamic>>.from(response as List);
    final records = rows.map((row) {
      final idNum = row['id_number']?.toString().trim() ?? '';
      final timestampRaw = row['checked_in_at']?.toString();
      return StudentAttendanceRecord(
        idNumber: idNum,
        fullName: row['full_name']?.toString().trim() ?? 'Student $idNum',
        yearLevel: normalizeYearLevel(row['year_level']),
        isPresent: row['is_present'] == true,
        checkedInAt: timestampRaw != null
            ? DateTime.tryParse(timestampRaw)?.toLocal()
            : null,
        selfieUrl: row['selfie_url']?.toString().trim(),
      );
    }).toList();

    records.sort((a, b) {
      final yrCmp = a.yearLevel.compareTo(b.yearLevel);
      if (yrCmp != 0) return yrCmp;
      if (a.isPresent != b.isPresent) return a.isPresent ? -1 : 1;
      return a.fullName.compareTo(b.fullName);
    });

    return records;
  }
}
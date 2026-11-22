import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _sessions = [];
  Set<String> _checkedInSessionIds = {};
  final Set<String> _notifiedSessionIds = {};

  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSubscription;
  Timer? _countdownTimer;

  bool _isLoading = true;
  String? _submittingSessionId;
  bool _notificationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _fetchCheckedInLogs();
    _listenToSessions();

    // Re-evaluate time windows & "starting soon" alerts every 15 seconds
    _countdownTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
        _checkUpcomingAlerts(_sessions);
      }
    });
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Initialize local notifications for "Near Time" alerts
  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'attendance_alerts',
      'Attendance Alerts',
      description: 'Notifies when an attendance session is starting soon',
      importance: Importance.high,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request Android 13+ notification permission
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (mounted) {
      _notificationsInitialized = true;
    }
  }

  /// Trigger a system notification when a session is <= 15 mins away
  Future<void> _triggerNearTimeNotification(
      String sessionId, String title, int minutesLeft) async {
    if (!_notificationsInitialized || _notifiedSessionIds.contains(sessionId)) {
      return;
    }
    _notifiedSessionIds.add(sessionId);

    const androidDetails = AndroidNotificationDetails(
      'attendance_alerts',
      'Attendance Alerts',
      channelDescription: 'Notifies when an attendance session is starting soon',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      sessionId.hashCode,
      'Attendance Starting Soon!',
      '$title begins in $minutesLeft minute${minutesLeft == 1 ? '' : 's'}. Head to the location.',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Fetch sessions the student has already checked into
  Future<void> _fetchCheckedInLogs() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final logs = await _supabase
          .from('attendance_logs')
          .select('session_id')
          .eq('student_id', userId);

      if (mounted) {
        setState(() {
          _checkedInSessionIds = logs
              .map<String>((row) => row['session_id'].toString())
              .toSet();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh checked-in sessions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Subscribe to Supabase Realtime updates on attendance_sessions
  void _listenToSessions() {
    _sessionsSubscription?.cancel();
    _sessionsSubscription = _supabase
        .from('attendance_sessions')
        .stream(primaryKey: ['id'])
        .order('start_time', ascending: true)
        .listen((data) {
      // Filter out sessions that ended more than 2 hours ago
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      final activeOrUpcoming = data.where((session) {
        final endTime = DateTime.tryParse(session['end_time']?.toString() ?? '');
        return endTime != null && endTime.isAfter(cutoff);
      }).toList();

      if (mounted) {
        setState(() {
          _sessions = activeOrUpcoming;
          _isLoading = false;
        });
        _checkUpcomingAlerts(activeOrUpcoming);
      }
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load attendance sessions: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  /// Checks if any session starts within the next 15 minutes
  void _checkUpcomingAlerts(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    for (final session in sessions) {
      final id = session['id'] as String;
      if (_checkedInSessionIds.contains(id)) continue;

      final start = DateTime.parse(session['start_time']).toLocal();
      final diffMinutes = (start.difference(now).inSeconds / 60).ceil();

      if (diffMinutes >= 0 && diffMinutes <= 15) {
        _triggerNearTimeNotification(
          id,
          session['title'] ?? 'Class Attendance',
          diffMinutes == 0 ? 1 : diffMinutes,
        );
      }
    }
  }

  /// Verifies GPS permissions, blocks mock locations, and calls submit_attendance RPC
  Future<void> _registerAttendance(String sessionId) async {
    setState(() => _submittingSessionId = sessionId);

    try {
      // 1. Check Location Services & Permissions
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable GPS / Location Services.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to check in.');
      }

      // 2. Get High-Accuracy Position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 3. Anti-Cheat: Block Fake GPS / Mock Locations
      if (position.isMocked) {
        throw Exception(
          'Mock location detected! Disable fake GPS apps to register attendance.',
        );
      }

      // 4. Call PostGIS Validation RPC
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

      if (!mounted) return;

      if (success) {
        setState(() => _checkedInSessionIds.add(sessionId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final cleanError = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleanError), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submittingSessionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Find any session starting within 15 minutes for the top alert banner
    final nearSessions = _sessions.where((s) {
      final start = DateTime.parse(s['start_time']).toLocal();
      final diff = (start.difference(now).inSeconds / 60).ceil();
      return diff >= 0 &&
          diff <= 15 &&
          !_checkedInSessionIds.contains(s['id']);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _fetchCheckedInLogs();
              _listenToSessions();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // In-App "Near Time" Alert Banner
                if (nearSessions.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active,
                            color: Colors.amber.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Upcoming soon: "${nearSessions.first['title']}" starts in ${((DateTime.parse(nearSessions.first['start_time']).toLocal().difference(now).inSeconds / 60).ceil()).clamp(1, 15)} min!',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Session List
                Expanded(
                  child: _sessions.isEmpty
                      ? const Center(
                          child: Text('No scheduled attendance sessions.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return _buildSessionCard(session, now);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, DateTime now) {
    final id = session['id'] as String;
    final title = session['title']?.toString() ?? 'Class Attendance';
    final radius = session['radius_meters'] is int
        ? session['radius_meters'] as int
        : int.tryParse(session['radius_meters']?.toString() ?? '') ?? 0;
    final startLocal = DateTime.parse(session['start_time']).toLocal();
    final endLocal = DateTime.parse(session['end_time']).toLocal();

    final isCheckedIn = _checkedInSessionIds.contains(id);
    final isOngoing = now.isAfter(startLocal) && now.isBefore(endLocal);
    final isUpcoming = now.isBefore(startLocal);
    final isExpired = now.isAfter(endLocal);
    final isStartingSoon =
        isUpcoming &&
        (startLocal.difference(now).inSeconds / 60).ceil() >= 0 &&
        (startLocal.difference(now).inSeconds / 60).ceil() <= 15;

    final timeRange =
        '${DateFormat('MMM d, h:mm a').format(startLocal)} - ${DateFormat('h:mm a').format(endLocal)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOngoing
              ? Colors.green
              : (isStartingSoon ? Colors.amber : Colors.grey.shade300),
          width: isOngoing || isStartingSoon ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(
                    isCheckedIn, isOngoing, isStartingSoon, isExpired),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(timeRange, style: const TextStyle(color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.radar, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Required Geofence: within ${radius}m'),
              ],
            ),
            const SizedBox(height: 16),

            // Check-In Action Button
            SizedBox(
              width: double.infinity,
              child: isCheckedIn
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text(
                        'Attendance Recorded',
                        style: TextStyle(color: Colors.green),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: (isOngoing && _submittingSessionId == null)
                          ? () => _registerAttendance(id)
                          : null,
                      icon: _submittingSessionId == id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(
                        _submittingSessionId == id
                            ? 'Verifying Location...'
                            : isOngoing
                                ? 'Check In Now'
                                : isUpcoming
                                    ? 'Starts in ${((startLocal.difference(now).inSeconds / 60).ceil()).clamp(1, double.infinity).toInt()}m'
                                    : 'Window Closed',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
      bool checkedIn, bool ongoing, bool startingSoon, bool expired) {
    if (checkedIn) {
      return _badge('Present', Colors.green);
    } else if (ongoing) {
      return _badge('Active Now', Colors.blue);
    } else if (startingSoon) {
      return _badge('Starting Soon', Colors.amber.shade800);
    } else if (expired) {
      return _badge('Closed', Colors.grey);
    }
    return _badge('Scheduled', Colors.indigo);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
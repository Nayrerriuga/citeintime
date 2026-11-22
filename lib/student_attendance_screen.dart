import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/attendance_service.dart';
import 'theme/grand_line_theme.dart';
import 'widgets/student_geofence_map.dart';
import 'widgets/student_session_card.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _attendanceService = AttendanceService();

  List<Map<String, dynamic>> _sessions = [];
  Set<String> _checkedInSessionIds = {};

  String _studentName = 'Crew Member';
  String _studentId = '';
  String _yearLevel = '';

  LatLng? _studentLocation;
  bool _isLocatingStudent = false;

  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSubscription;
  Timer? _countdownTimer;

  late final AnimationController _compassController;
  late final AnimationController _waveController;

  bool _isLoading = true;
  String? _submittingSessionId;

  @override
  void initState() {
    super.initState();

    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _initializeScreen();

    _countdownTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
        _checkUpcomingAlerts(_sessions);
        _updateStudentLocation();
      }
    });
  }

  Future<void> _initializeScreen() async {
    await _attendanceService.initNotifications();
    await _refreshAllData();
  }

  Future<void> _refreshAllData() async {
    final profile = await _attendanceService.fetchStudentProfile();
    Set<String> checkedIn = _checkedInSessionIds;
    try {
      checkedIn = await _attendanceService.fetchCheckedInSessionIds();
    } catch (e) {
      _showSnack('Could not refresh logs: $e', GrandLinePalette.strawHatRed);
    }

    if (mounted) {
      setState(() {
        _studentName = profile['name'] ?? 'Crew Member';
        _studentId = profile['id'] ?? '';
        _yearLevel = profile['yearLevel'] ?? '';
        _checkedInSessionIds = checkedIn;
      });
    }

    _updateStudentLocation();
    _listenToSessions();
  }

  Future<void> _updateStudentLocation() async {
    if (_isLocatingStudent) return;
    setState(() => _isLocatingStudent = true);
    try {
      final loc = await _attendanceService.getCurrentLatLng();
      if (loc != null && mounted) {
        setState(() => _studentLocation = loc);
      }
    } finally {
      if (mounted) setState(() => _isLocatingStudent = false);
    }
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _countdownTimer?.cancel();
    _compassController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _listenToSessions() {
    _sessionsSubscription?.cancel();
    _sessionsSubscription = _supabase
        .from('attendance_sessions')
        .stream(primaryKey: ['id'])
        .order('start_time', ascending: true)
        .listen(
          (data) {
            final cutoff = DateTime.now().toUtc().subtract(
              const Duration(hours: 2),
            );
            final activeOrUpcoming = data.where((session) {
              final endTime = DateTime.tryParse(
                session['end_time']?.toString() ?? '',
              );
              return endTime != null && endTime.isAfter(cutoff);
            }).toList();

            if (mounted) {
              setState(() {
                _sessions = activeOrUpcoming;
                _isLoading = false;
              });
              _checkUpcomingAlerts(activeOrUpcoming);
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showSnack(
              'Could not load attendance sessions: $error',
              GrandLinePalette.strawHatRed,
            );
          },
        );
  }

  /// Priority rank: 0 = Active Now, 1 = Scheduled, 2 = Closed
  int _sessionPriority(Map<String, dynamic> session, DateTime now) {
    final start = DateTime.parse(session['start_time']).toLocal();
    final end = DateTime.parse(session['end_time']).toLocal();
    if (!now.isBefore(start) && now.isBefore(end)) return 0; // Active
    if (now.isBefore(start)) return 1; // Scheduled
    return 2; // Closed
  }

  /// Returns sessions sorted: Active -> Scheduled (soonest first) -> Closed (most recent first)
  List<Map<String, dynamic>> _getSortedSessions(DateTime now) {
    final sorted = List<Map<String, dynamic>>.from(_sessions);
    sorted.sort((a, b) {
      final rankA = _sessionPriority(a, now);
      final rankB = _sessionPriority(b, now);
      if (rankA != rankB) return rankA.compareTo(rankB);

      final startA = DateTime.parse(a['start_time']).toLocal();
      final startB = DateTime.parse(b['start_time']).toLocal();

      // For Closed sessions, show the most recently closed one first
      if (rankA == 2) {
        return startB.compareTo(startA);
      }
      // For Active & Scheduled sessions, show the earliest start time first
      return startA.compareTo(startB);
    });
    return sorted;
  }

  void _checkUpcomingAlerts(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    for (final session in sessions) {
      final id = session['id'] as String;
      if (_checkedInSessionIds.contains(id)) continue;

      final start = DateTime.parse(session['start_time']).toLocal();
      final diffMinutes = (start.difference(now).inSeconds / 60).ceil();

      if (diffMinutes >= 0 && diffMinutes <= 15) {
        _attendanceService.triggerNearTimeAlert(
          id,
          session['title'] ?? 'Class Attendance',
          diffMinutes == 0 ? 1 : diffMinutes,
        );
      }
    }
  }

  Future<void> _handleCheckIn(String sessionId) async {
    setState(() => _submittingSessionId = sessionId);
    try {
      final result = await _attendanceService.submitCheckIn(sessionId);
      if (!mounted) return;

      if (result.success) {
        setState(() => _checkedInSessionIds.add(sessionId));
        _showSnack(result.message, Colors.green.shade700);
      } else {
        _showSnack(result.message, Colors.orange.shade800);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        GrandLinePalette.strawHatRed,
      );
    } finally {
      if (mounted) setState(() => _submittingSessionId = null);
    }
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GrandLinePalette.oceanMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.sailing_rounded, color: GrandLinePalette.treasureGold),
            SizedBox(width: 10),
            Text(
              'Abandon Ship?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of CiteInTime, $_studentName?',
          style: TextStyle(
            color: GrandLinePalette.parchmentCream.withValues(alpha: 0.9),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GrandLinePalette.strawHatRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _supabase.auth.signOut();
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sortedSessions = _getSortedSessions(now);

    final nearSessions = sortedSessions.where((s) {
      final start = DateTime.parse(s['start_time']).toLocal();
      final diff = (start.difference(now).inSeconds / 60).ceil();
      return diff >= 0 && diff <= 15 && !_checkedInSessionIds.contains(s['id']);
    }).toList();

    // Only select a session that is currently active (start_time <= now < end_time)
    final activeSessions = sortedSessions
        .where((s) => _sessionPriority(s, now) == 0)
        .toList();

    final activeSession = activeSessions.isEmpty ? null : activeSessions.first;

    return Scaffold(
      backgroundColor: GrandLinePalette.oceanDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _waveController,
                _compassController,
              ]),
              builder: (context, _) => CustomPaint(
                painter: GrandLineBackgroundPainter(
                  waveProgress: _waveController.value,
                  compassAngle: _compassController.value * 2 * math.pi,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildCrewIdentityCard(),
                if (activeSession != null)
                  StudentGeofenceMap(
                    session: activeSession,
                    studentLocation: _studentLocation,
                    isLocating: _isLocatingStudent,
                    onRefreshLocation: _updateStudentLocation,
                  ),
                const SizedBox(height: 4),
                if (nearSessions.isNotEmpty)
                  _buildNearTimeBanner(nearSessions.first, now),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: GrandLinePalette.treasureGold,
                          ),
                        )
                      : RefreshIndicator(
                          color: GrandLinePalette.treasureGold,
                          backgroundColor: GrandLinePalette.oceanMid,
                          onRefresh: _refreshAllData,
                          child: sortedSessions.isEmpty
                              ? _buildEmptyScrollableState()
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  itemCount: sortedSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = sortedSessions[index];
                                    final id = session['id'] as String;
                                    return StudentSessionCard(
                                      session: session,
                                      now: now,
                                      isCheckedIn: _checkedInSessionIds
                                          .contains(id),
                                      isSubmitting: _submittingSessionId == id,
                                      isAnySubmitting:
                                          _submittingSessionId != null,
                                      onCheckIn: () => _handleCheckIn(id),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GrandLinePalette.oceanMid,
              border: Border.all(
                color: GrandLinePalette.treasureGold,
                width: 1.8,
              ),
            ),
            child: CustomPaint(painter: MiniStrawHatPainter()),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFE082),
                    GrandLinePalette.treasureGold,
                    Color(0xFFFF8F00),
                  ],
                ).createShader(bounds),
                child: const Text(
                  'CiteInTime',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'LOG POSE ATTENDANCE',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: GrandLinePalette.treasureGold.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: _confirmAndLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildCrewIdentityCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GrandLinePalette.oceanMid.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.45),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _compassController,
              builder: (context, _) => Transform.rotate(
                angle: _compassController.value * 2 * math.pi,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: GrandLinePalette.treasureGold,
                      width: 2,
                    ),
                    color: GrandLinePalette.oceanDeep,
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: GrandLinePalette.treasureGold,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE CREW MEMBER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: GrandLinePalette.treasureGold.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (_studentId.isNotEmpty) ...[
                        Icon(
                          Icons.badge_outlined,
                          size: 13,
                          color: GrandLinePalette.parchmentCream.withValues(
                            alpha: 0.75,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ID: $_studentId',
                          style: TextStyle(
                            color: GrandLinePalette.parchmentCream.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_studentId.isNotEmpty && _yearLevel.isNotEmpty)
                        Text(
                          '  •  ',
                          style: TextStyle(
                            color: GrandLinePalette.treasureGold.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      if (_yearLevel.isNotEmpty)
                        Text(
                          _yearLevel,
                          style: TextStyle(
                            color: GrandLinePalette.parchmentCream.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearTimeBanner(Map<String, dynamic> session, DateTime now) {
    final mins =
        ((DateTime.parse(
                      session['start_time'],
                    ).toLocal().difference(now).inSeconds /
                    60)
                .ceil())
            .clamp(1, 15);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GrandLinePalette.treasureGold),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: GrandLinePalette.treasureGold,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Log Pose Alert: "${session['title']}" starts in $mins min!',
                style: const TextStyle(
                  color: GrandLinePalette.parchmentCream,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyScrollableState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sailing_rounded,
                    size: 56,
                    color: GrandLinePalette.treasureGold.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Scheduled Sessions Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pull down to refresh or wait for an Admin to open a session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/admin_session_service.dart';
import 'theme/grand_line_theme.dart';
import 'widgets/admin_analytics_view.dart';
import 'widgets/admin_geofence_map.dart';
import 'widgets/admin_manage_sessions_view.dart';

class AdminCreateSessionScreen extends StatefulWidget {
  const AdminCreateSessionScreen({super.key});

  @override
  State<AdminCreateSessionScreen> createState() =>
      _AdminCreateSessionScreenState();
}

class _AdminCreateSessionScreenState extends State<AdminCreateSessionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _mapController = MapController();
  final _sessionService = AdminSessionService();

  int _activeTabIndex = 0; // 0 = Create, 1 = Manage, 2 = Analytics

  LatLng _selectedLocation = const LatLng(8.7458, 124.7764);
  double _radiusMeters = 50.0;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationMinutes = 30;

  bool _isSubmitting = false;
  bool _isLocating = false;

  late final AnimationController _compassController;
  late final AnimationController _waveController;

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

    _moveToCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mapController.dispose();
    _compassController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final current = await _sessionService.getCurrentPosition();
      if (current != null && mounted) {
        setState(() => _selectedLocation = current);
        _mapController.move(current, 17.0);
      }
    } catch (e) {
      debugPrint('Location error: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _sessionService.publishSession(
        title: _titleController.text,
        date: _selectedDate,
        time: _selectedTime,
        durationMinutes: _durationMinutes,
        center: _selectedLocation,
        radiusMeters: _radiusMeters.round(),
      );

      if (!mounted) return;
      _showSnack('Attendance session published!', Colors.green.shade700);
      _titleController.clear();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showSnack('Database error: ${e.message}', GrandLinePalette.strawHatRed);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unexpected error: $e', GrandLinePalette.strawHatRed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            Icon(Icons.anchor_rounded, color: GrandLinePalette.treasureGold),
            SizedBox(width: 10),
            Text(
              'Confirm Logout?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of Admin Page?',
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
      await Supabase.instance.client.auth.signOut();
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

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
                _buildTabSwitcher(),
                const SizedBox(height: 8),
                Expanded(
                  child: _activeTabIndex == 0
                      ? Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: AdminGeofenceMap(
                                  mapController: _mapController,
                                  selectedLocation: _selectedLocation,
                                  radiusMeters: _radiusMeters,
                                  isLocating: _isLocating,
                                  onLocationSelected: (pt) =>
                                      setState(() => _selectedLocation = pt),
                                  onLocateMe: _moveToCurrentLocation,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 6,
                                child: _buildSessionFormCard(
                                  formattedDate,
                                  formattedTime,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _activeTabIndex == 1
                      ? AdminManageSessionsView(service: _sessionService)
                      : AdminAnalyticsView(service: _sessionService),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: GrandLinePalette.oceanMid.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            _tabButton(
              index: 0,
              icon: Icons.add_location_alt_rounded,
              label: 'Create',
            ),
            _tabButton(
              index: 1,
              icon: Icons.edit_calendar_rounded,
              label: 'Manage',
            ),
            _tabButton(
              index: 2,
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? GrandLinePalette.strawHatRed : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(
                    color: GrandLinePalette.treasureGold.withValues(alpha: 0.7),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive
                    ? GrandLinePalette.treasureGold
                    : Colors.white60,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final subtitle = _activeTabIndex == 0
        ? 'CREATE SESSION'
        : _activeTabIndex == 1
        ? 'MANAGE SESSIONS'
        : 'ATTENDANCE ANALYTICS';

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
                subtitle,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: GrandLinePalette.treasureGold.withValues(alpha: 0.85),
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

  Widget _buildSessionFormCard(String formattedDate, String formattedTime) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _titleController,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: _inputDecoration(
                label: 'Session / Class Name',
                hint: 'e.g., Cite Day 2026 Day 1',
                icon: Icons.class_rounded,
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please enter a session name'
                  : null,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log Pose Geofence Radius',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: GrandLinePalette.treasureGold.withValues(
                      alpha: 0.16,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: GrandLinePalette.treasureGold.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    '${_radiusMeters.round()} meters',
                    style: const TextStyle(
                      color: GrandLinePalette.treasureGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: GrandLinePalette.treasureGold,
                inactiveTrackColor: GrandLinePalette.oceanDeep,
                thumbColor: GrandLinePalette.strawHatRed,
                overlayColor: GrandLinePalette.treasureGold.withValues(
                  alpha: 0.2,
                ),
                valueIndicatorColor: GrandLinePalette.strawHatRed,
              ),
              child: Slider(
                value: _radiusMeters,
                min: 15,
                max: 300,
                divisions: 57,
                label: '${_radiusMeters.round()}m',
                onChanged: (val) => setState(() => _radiusMeters = val),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.calendar_today_rounded,
                    label: formattedDate,
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPickerButton(
                    icon: Icons.access_time_rounded,
                    label: formattedTime,
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              dropdownColor: GrandLinePalette.oceanDeep,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: _inputDecoration(
                label: 'Attendance Window Duration',
                icon: Icons.timer_rounded,
              ),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10 Minutes')),
                DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                DropdownMenuItem(value: 60, child: Text('1 Hour')),
                DropdownMenuItem(value: 120, child: Text('2 Hours')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _durationMinutes = val);
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createSession,
              style: FilledButton.styleFrom(
                backgroundColor: GrandLinePalette.strawHatRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: GrandLinePalette.treasureGold.withValues(alpha: 0.7),
                  ),
                ),
                elevation: 6,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: GrandLinePalette.treasureGold,
                      ),
                    )
                  : const Icon(
                      Icons.explore_rounded,
                      color: GrandLinePalette.treasureGold,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Setting Log Pose...'
                    : 'Publish Attendance Session',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: GrandLinePalette.parchmentCream,
        backgroundColor: GrandLinePalette.oceanDeep.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        side: BorderSide(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 17, color: GrandLinePalette.treasureGold),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, color: GrandLinePalette.treasureGold),
      filled: true,
      fillColor: GrandLinePalette.oceanDeep.withValues(alpha: 0.7),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: GrandLinePalette.treasureGold,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GrandLinePalette.strawHatRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: GrandLinePalette.strawHatRed,
          width: 2,
        ),
      ),
    );
  }
}

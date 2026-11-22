import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_session_service.dart';
import '../theme/grand_line_theme.dart';

class AdminManageSessionsView extends StatefulWidget {
  final AdminSessionService service;

  const AdminManageSessionsView({super.key, required this.service});

  @override
  State<AdminManageSessionsView> createState() =>
      _AdminManageSessionsViewState();
}

class _AdminManageSessionsViewState extends State<AdminManageSessionsView> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await widget.service.fetchAllSessions();
      final now = DateTime.now();

      // Sort: Active Now -> Scheduled -> Closed
      sessions.sort((a, b) {
        final rankA = _statusRank(a, now);
        final rankB = _statusRank(b, now);
        if (rankA != rankB) return rankA.compareTo(rankB);
        final startA = DateTime.parse(a['start_time']).toLocal();
        final startB = DateTime.parse(b['start_time']).toLocal();
        return rankA == 2 ? startB.compareTo(startA) : startA.compareTo(startB);
      });

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Failed to load sessions: $e', GrandLinePalette.strawHatRed);
      }
    }
  }

  int _statusRank(Map<String, dynamic> session, DateTime now) {
    final start = DateTime.parse(session['start_time']).toLocal();
    final end = DateTime.parse(session['end_time']).toLocal();
    if (!now.isBefore(start) && now.isBefore(end)) return 0; // Active
    if (now.isBefore(start)) return 1; // Scheduled
    return 2; // Closed
  }

  Future<void> _confirmDelete(Map<String, dynamic> session) async {
    final id = session['id'].toString();
    final title = session['title']?.toString() ?? 'this session';

    final confirm = await showDialog<bool>(
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
            Icon(Icons.delete_forever_rounded,
                color: GrandLinePalette.strawHatRed),
            SizedBox(width: 8),
            Text(
              'Delete Session?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "$title" and all its attendance logs?',
          style: TextStyle(
            color: GrandLinePalette.parchmentCream.withValues(alpha: 0.9),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: GrandLinePalette.strawHatRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingId = id);
    try {
      await widget.service.deleteSession(id);
      if (!mounted) return;
      _showSnack('Session "$title" deleted.', Colors.green.shade700);
      await _loadSessions();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _showSnack('Database error: ${e.message}', GrandLinePalette.strawHatRed);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to delete: $e', GrandLinePalette.strawHatRed);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<void> _openEditModal(Map<String, dynamic> session) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSessionBottomSheet(
        service: widget.service,
        session: session,
      ),
    );

    if (updated == true) {
      _showSnack('Session updated successfully!', Colors.green.shade700);
      await _loadSessions();
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: GrandLinePalette.treasureGold),
      );
    }

    return RefreshIndicator(
      color: GrandLinePalette.treasureGold,
      backgroundColor: GrandLinePalette.oceanMid,
      onRefresh: _loadSessions,
      child: _sessions.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 54,
                          color: GrandLinePalette.treasureGold
                              .withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No Sessions Found',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create an attendance session first to manage it here.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return _buildSessionCard(session, now);
              },
            ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, DateTime now) {
    final id = session['id'].toString();
    final title = session['title']?.toString() ?? 'Untitled Session';
    final start = DateTime.parse(session['start_time']).toLocal();
    final end = DateTime.parse(session['end_time']).toLocal();
    final radius = session['radius_meters'] ?? 50;

    final rank = _statusRank(session, now);
    final statusLabel = rank == 0
        ? 'Active Now'
        : rank == 1
            ? 'Scheduled'
            : 'Closed';
    final statusColor = rank == 0
        ? Colors.greenAccent
        : rank == 1
            ? GrandLinePalette.treasureGold
            : Colors.white54;

    final dateRange =
        '${DateFormat('MMM d, yyyy').format(start)} • ${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    final isDeleting = _deletingId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rank == 0
              ? Colors.greenAccent.withValues(alpha: 0.65)
              : GrandLinePalette.treasureGold.withValues(alpha: 0.35),
          width: rank == 0 ? 1.6 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: GrandLinePalette.treasureGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateRange,
                  style: TextStyle(
                    color: GrandLinePalette.parchmentCream.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.radar_rounded,
                  size: 14, color: GrandLinePalette.treasureGold),
              const SizedBox(width: 6),
              Text(
                'Geofence Radius: ${radius}m',
                style: TextStyle(
                  color: GrandLinePalette.parchmentCream.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : () => _openEditModal(session),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GrandLinePalette.treasureGold,
                    side: BorderSide(
                      color:
                          GrandLinePalette.treasureGold.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: const Text(
                    'Edit Session',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isDeleting ? null : () => _confirmDelete(session),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        GrandLinePalette.strawHatRed.withValues(alpha: 0.9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    isDeleting ? 'Deleting...' : 'Delete',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditSessionBottomSheet extends StatefulWidget {
  final AdminSessionService service;
  final Map<String, dynamic> session;

  const _EditSessionBottomSheet({
    required this.service,
    required this.session,
  });

  @override
  State<_EditSessionBottomSheet> createState() =>
      _EditSessionBottomSheetState();
}

class _EditSessionBottomSheetState extends State<_EditSessionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final MapController _mapController = MapController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late int _durationMinutes;
  late double _radiusMeters;
  late LatLng _selectedLocation;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.session['title']?.toString() ?? '',
    );

    final start = DateTime.parse(widget.session['start_time']).toLocal();
    final end = DateTime.parse(widget.session['end_time']).toLocal();

    _selectedDate = DateTime(start.year, start.month, start.day);
    _selectedTime = TimeOfDay(hour: start.hour, minute: start.minute);

    final diff = end.difference(start).inMinutes;
    _durationMinutes = diff > 0 ? diff : 30;

    final rawRadius = widget.session['radius_meters'];
    _radiusMeters = (rawRadius is int)
        ? rawRadius.toDouble().clamp(15.0, 300.0)
        : (double.tryParse(rawRadius?.toString() ?? '') ?? 50.0)
            .clamp(15.0, 300.0);

    final lat =
        double.tryParse(widget.session['lat']?.toString() ?? '') ?? 8.7458;
    final lng =
        double.tryParse(widget.session['lng']?.toString() ?? '') ?? 124.7764;
    _selectedLocation = LatLng(lat, lng);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.service.updateSession(
        sessionId: widget.session['id'].toString(),
        title: _titleController.text,
        date: _selectedDate,
        time: _selectedTime,
        durationMinutes: _durationMinutes,
        center: _selectedLocation,
        radiusMeters: _radiusMeters.round(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database error: ${e.message}'),
          backgroundColor: GrandLinePalette.strawHatRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating session: $e'),
          backgroundColor: GrandLinePalette.strawHatRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    // Ensure current duration is in dropdown options
    final durationOptions = <int>{10, 15, 30, 45, 60, 120, _durationMinutes}
        .toList()
      ..sort();

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Attendance Session',
                    style: TextStyle(
                      color: GrandLinePalette.treasureGold,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Mini Interactive Map to adjust geofence pin
              SizedBox(
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 17.0,
                      onTap: (_, pt) => setState(() => _selectedLocation = pt),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.attendance_app',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedLocation,
                            radius: _radiusMeters,
                            useRadiusInMeter: true,
                            color: GrandLinePalette.treasureGold
                                .withValues(alpha: 0.25),
                            borderColor: GrandLinePalette.strawHatRed,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: GrandLinePalette.strawHatRed,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap anywhere on the map above to move the geofence pin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Session Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.class_rounded,
                      color: GrandLinePalette.treasureGold),
                  filled: true,
                  fillColor: GrandLinePalette.oceanDeep.withValues(alpha: 0.7),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          GrandLinePalette.treasureGold.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: GrandLinePalette.treasureGold,
                      width: 1.8,
                    ),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Session name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Geofence Radius',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${_radiusMeters.round()}m',
                    style: const TextStyle(
                      color: GrandLinePalette.treasureGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radiusMeters,
                min: 15,
                max: 300,
                divisions: 57,
                activeColor: GrandLinePalette.treasureGold,
                inactiveColor: GrandLinePalette.oceanDeep,
                thumbColor: GrandLinePalette.strawHatRed,
                onChanged: (val) => setState(() => _radiusMeters = val),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GrandLinePalette.parchmentCream,
                        backgroundColor:
                            GrandLinePalette.oceanDeep.withValues(alpha: 0.65),
                        side: BorderSide(
                          color: GrandLinePalette.treasureGold
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_today_rounded,
                          size: 16, color: GrandLinePalette.treasureGold),
                      label: Text(formattedDate,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GrandLinePalette.parchmentCream,
                        backgroundColor:
                            GrandLinePalette.oceanDeep.withValues(alpha: 0.65),
                        side: BorderSide(
                          color: GrandLinePalette.treasureGold
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.access_time_rounded,
                          size: 16, color: GrandLinePalette.treasureGold),
                      label: Text(formattedTime,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                dropdownColor: GrandLinePalette.oceanDeep,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Duration',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.timer_rounded,
                      color: GrandLinePalette.treasureGold),
                  filled: true,
                  fillColor: GrandLinePalette.oceanDeep.withValues(alpha: 0.7),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color:
                          GrandLinePalette.treasureGold.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                items: durationOptions
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m Minutes'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _durationMinutes = val);
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                style: FilledButton.styleFrom(
                  backgroundColor: GrandLinePalette.strawHatRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color:
                          GrandLinePalette.treasureGold.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: GrandLinePalette.treasureGold,
                        ),
                      )
                    : const Icon(Icons.save_rounded,
                        color: GrandLinePalette.treasureGold),
                label: Text(
                  _isSaving ? 'Saving Changes...' : 'Save Session Changes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
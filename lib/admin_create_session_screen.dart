import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCreateSessionScreen extends StatefulWidget {
  const AdminCreateSessionScreen({super.key});

  @override
  State<AdminCreateSessionScreen> createState() =>
      _AdminCreateSessionScreenState();
}

class _AdminCreateSessionScreenState extends State<AdminCreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final MapController _mapController = MapController();

  // Default coordinates (updates automatically if GPS permission is granted)
  LatLng _selectedLocation = const LatLng(8.7458, 124.7764);
  double _radiusMeters = 50.0;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationMinutes = 30;

  bool _isSubmitting = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _moveToCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Centers the map on the Admin's current GPS position
  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
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
        final currentLatLng = LatLng(pos.latitude, pos.longitude);
        setState(() => _selectedLocation = currentLatLng);
        _mapController.move(currentLatLng, 17.0);
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

  /// Calls the Supabase PostGIS RPC to save the session
  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Combine chosen date and start time in local timezone
      final localStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final localEnd = localStart.add(Duration(minutes: _durationMinutes));

      // Call the SQL RPC created in Step 1
      await Supabase.instance.client.rpc(
        'create_attendance_session',
        params: {
          'p_title': _titleController.text.trim(),
          // Always send ISO-8601 UTC strings to Postgres TIMESTAMPTZ
          'p_start_time': localStart.toUtc().toIso8601String(),
          'p_end_time': localEnd.toUtc().toIso8601String(),
          'p_lat': _selectedLocation.latitude,
          'p_lng': _selectedLocation.longitude,
          'p_radius_meters': _radiusMeters.round(),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance session published!'),
          backgroundColor: Colors.green,
        ),
      );
      _titleController.clear();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Attendance Session'),
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Use My Current Location',
            onPressed: _isLocating ? null : _moveToCurrentLocation,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // 1. Interactive Geofence Map Picker
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 17.0,
                      onTap: (tapPosition, point) {
                        setState(() => _selectedLocation = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.attendance_app',
                      ),
                      // Visual Geofence Circle (uses real meters!)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedLocation,
                            radius: _radiusMeters,
                            useRadiusInMeter: true,
                            color: Colors.blue.withValues(alpha: 0.25),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      // Center Pin Marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Card(
                      color: Colors.black.withValues(alpha: 0.75),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        child: Text(
                          'Tap anywhere on the map to set the geofence center',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Session Details & Controls Form
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Session Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Session / Class Name',
                        hintText: 'e.g., CS101 - Morning Lecture',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.class_),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter a session name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Geofence Radius Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Geofence Radius',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_radiusMeters.round()} meters',
                          style: const TextStyle(
                            color: Colors.blue,
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
                      label: '${_radiusMeters.round()}m',
                      onChanged: (val) => setState(() => _radiusMeters = val),
                    ),
                    const SizedBox(height: 8),

                    // Date & Start Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(formattedDate),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(formattedTime),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Duration Selector
                    DropdownButtonFormField<int>(
                      initialValue: _durationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Attendance Window Duration',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
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
                    const SizedBox(height: 20),

                    // Publish Button
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _createSession,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.publish),
                      label: Text(
                        _isSubmitting
                            ? 'Publishing...'
                            : 'Publish Attendance Session',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

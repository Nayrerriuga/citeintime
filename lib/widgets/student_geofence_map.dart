import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/grand_line_theme.dart';

class StudentGeofenceMap extends StatefulWidget {
  final Map<String, dynamic> session;
  final LatLng? studentLocation;
  final bool isLocating;
  final VoidCallback onRefreshLocation;

  const StudentGeofenceMap({
    super.key,
    required this.session,
    required this.studentLocation,
    required this.isLocating,
    required this.onRefreshLocation,
  });

  @override
  State<StudentGeofenceMap> createState() => _StudentGeofenceMapState();
}

class _StudentGeofenceMapState extends State<StudentGeofenceMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant StudentGeofenceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session['id'] != widget.session['id']) {
      final newCenter = _extractSessionCenter();
      if (newCenter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(newCenter, 17.2);
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Checks whether the session is currently Active Now (neither Scheduled nor Closed)
  bool _isSessionActive() {
    final start = DateTime.tryParse(
      widget.session['start_time']?.toString() ?? '',
    )?.toLocal();
    final end = DateTime.tryParse(
      widget.session['end_time']?.toString() ?? '',
    )?.toLocal();
    if (start == null || end == null) return false;

    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  LatLng? _extractSessionCenter() {
    final lat = double.tryParse(widget.session['lat']?.toString() ?? '');
    final lng = double.tryParse(widget.session['lng']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    // Only render the geofence map when the session is actively running
    if (!_isSessionActive()) return const SizedBox.shrink();

    final center = _extractSessionCenter();
    if (center == null) return const SizedBox.shrink();

    final radiusMeters = (widget.session['radius_meters'] is int)
        ? (widget.session['radius_meters'] as int).toDouble()
        : double.tryParse(widget.session['radius_meters']?.toString() ?? '') ??
              50.0;

    final studentPos = widget.studentLocation;
    double? distanceMeters;
    bool isInside = false;

    if (studentPos != null) {
      distanceMeters = Geolocator.distanceBetween(
        studentPos.latitude,
        studentPos.longitude,
        center.latitude,
        center.longitude,
      );
      isInside = distanceMeters <= radiusMeters;
    }

    final statusColor = studentPos == null
        ? GrandLinePalette.treasureGold
        : isInside
        ? Colors.greenAccent
        : Colors.orangeAccent;

    final statusText = studentPos == null
        ? 'Locating your GPS...'
        : isInside
        ? 'Inside Geofence (${distanceMeters!.round()}m / ${radiusMeters.round()}m)'
        : '${(distanceMeters! - radiusMeters).ceil()}m outside geofence';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      height: 215,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.75),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 17.2),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.attendance_app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radiusMeters,
                      useRadiusInMeter: true,
                      color:
                          (isInside
                                  ? Colors.greenAccent
                                  : GrandLinePalette.treasureGold)
                              .withValues(alpha: 0.25),
                      borderColor: isInside
                          ? Colors.greenAccent
                          : GrandLinePalette.strawHatRed,
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Admin Geofence Center Pin
                    Marker(
                      point: center,
                      width: 38,
                      height: 38,
                      child: const Icon(
                        Icons.flag_circle_rounded,
                        color: GrandLinePalette.strawHatRed,
                        size: 36,
                      ),
                    ),
                    // Live Student GPS Dot
                    if (studentPos != null)
                      Marker(
                        point: studentPos,
                        width: 34,
                        height: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.lightBlueAccent.withValues(
                              alpha: 0.3,
                            ),
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isInside
                                    ? Colors.greenAccent
                                    : Colors.lightBlueAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Top Geofence Proximity Pill
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: GrandLinePalette.oceanDeep.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isInside ? Icons.verified_rounded : Icons.explore_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.session['title']}: $statusText',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Map Controls (Center on Me / Center on Geofence)
            Positioned(
              bottom: 10,
              right: 10,
              child: Row(
                children: [
                  _miniMapButton(
                    tooltip: 'Center on Geofence',
                    icon: Icons.flag_rounded,
                    onTap: () => _mapController.move(center, 17.2),
                  ),
                  const SizedBox(width: 8),
                  _miniMapButton(
                    tooltip: 'Update My GPS',
                    icon: Icons.my_location_rounded,
                    isLoading: widget.isLocating,
                    onTap: () {
                      widget.onRefreshLocation();
                      if (studentPos != null) {
                        _mapController.move(studentPos, 17.5);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMapButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: GrandLinePalette.oceanMid.withValues(alpha: 0.92),
      shape: CircleBorder(
        side: BorderSide(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.7),
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 38,
            height: 38,
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GrandLinePalette.treasureGold,
                    ),
                  )
                : Icon(icon, size: 19, color: GrandLinePalette.treasureGold),
          ),
        ),
      ),
    );
  }
}

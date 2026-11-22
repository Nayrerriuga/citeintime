import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/grand_line_theme.dart';

class AdminGeofenceMap extends StatelessWidget {
  final MapController mapController;
  final LatLng selectedLocation;
  final double radiusMeters;
  final bool isLocating;
  final ValueChanged<LatLng> onLocationSelected;
  final VoidCallback onLocateMe;

  const AdminGeofenceMap({
    super.key,
    required this.mapController,
    required this.selectedLocation,
    required this.radiusMeters,
    required this.isLocating,
    required this.onLocationSelected,
    required this.onLocateMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.65),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: selectedLocation,
                initialZoom: 17.0,
                onTap: (_, point) => onLocationSelected(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.attendance_app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: selectedLocation,
                      radius: radiusMeters,
                      useRadiusInMeter: true,
                      color: GrandLinePalette.treasureGold.withValues(
                        alpha: 0.25,
                      ),
                      borderColor: GrandLinePalette.strawHatRed,
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: GrandLinePalette.strawHatRed,
                        size: 44,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top Instruction Pill
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: GrandLinePalette.oceanDeep.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GrandLinePalette.treasureGold.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.explore_rounded,
                      size: 15,
                      color: GrandLinePalette.treasureGold,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tap map to anchor Log Pose geofence center',
                        style: TextStyle(
                          color: GrandLinePalette.parchmentCream,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Coordinates + GPS Center FAB
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: GrandLinePalette.oceanDeep.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: GrandLinePalette.treasureGold.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Text(
                      '${selectedLocation.latitude.toStringAsFixed(5)}, ${selectedLocation.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: GrandLinePalette.treasureGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FloatingActionButton.small(
                    heroTag: 'admin_locate_btn',
                    backgroundColor: GrandLinePalette.oceanMid,
                    foregroundColor: GrandLinePalette.treasureGold,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: GrandLinePalette.treasureGold.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    onPressed: isLocating ? null : onLocateMe,
                    child: isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GrandLinePalette.treasureGold,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

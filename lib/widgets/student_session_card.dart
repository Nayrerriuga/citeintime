import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/grand_line_theme.dart';

class StudentSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final DateTime now;
  final bool isCheckedIn;
  final bool isSubmitting;
  final bool isAnySubmitting;
  final VoidCallback onCheckIn;

  const StudentSessionCard({
    super.key,
    required this.session,
    required this.now,
    required this.isCheckedIn,
    required this.isSubmitting,
    required this.isAnySubmitting,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final title = session['title']?.toString() ?? 'Class Attendance';
    final radius = session['radius_meters'] is int
        ? session['radius_meters'] as int
        : int.tryParse(session['radius_meters']?.toString() ?? '') ?? 0;
    final startLocal = DateTime.parse(session['start_time']).toLocal();
    final endLocal = DateTime.parse(session['end_time']).toLocal();

    final isOngoing = now.isAfter(startLocal) && now.isBefore(endLocal);
    final isUpcoming = now.isBefore(startLocal);
    final isExpired = now.isAfter(endLocal);
    final minutesUntilStart = (startLocal.difference(now).inSeconds / 60)
        .ceil();
    final isStartingSoon =
        isUpcoming && minutesUntilStart >= 0 && minutesUntilStart <= 15;

    final timeRange =
        '${DateFormat('MMM d, h:mm a').format(startLocal)} - ${DateFormat('h:mm a').format(endLocal)}';

    final borderColor = isCheckedIn
        ? Colors.greenAccent
        : isOngoing
        ? GrandLinePalette.treasureGold
        : isStartingSoon
        ? Colors.orangeAccent
        : GrandLinePalette.treasureGold.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isOngoing || isCheckedIn ? 1.8 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(
                  isCheckedIn,
                  isOngoing,
                  isStartingSoon,
                  isExpired,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: GrandLinePalette.treasureGold,
                ),
                const SizedBox(width: 8),
                Text(
                  timeRange,
                  style: TextStyle(
                    color: GrandLinePalette.parchmentCream.withValues(
                      alpha: 0.9,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.radar_rounded,
                  size: 16,
                  color: GrandLinePalette.treasureGold,
                ),
                const SizedBox(width: 8),
                Text(
                  'Log Pose Geofence: within ${radius}m',
                  style: TextStyle(
                    color: GrandLinePalette.parchmentCream.withValues(
                      alpha: 0.8,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isCheckedIn
                  ? _buildCheckedInBanner()
                  : FilledButton.icon(
                      onPressed: (isOngoing && !isAnySubmitting)
                          ? onCheckIn
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: GrandLinePalette.strawHatRed,
                        disabledBackgroundColor: GrandLinePalette.oceanDeep
                            .withValues(alpha: 0.7),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isOngoing
                                ? GrandLinePalette.treasureGold
                                : GrandLinePalette.treasureGold.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                        ),
                      ),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GrandLinePalette.treasureGold,
                              ),
                            )
                          : Icon(
                              Icons.my_location_rounded,
                              color: isOngoing
                                  ? GrandLinePalette.treasureGold
                                  : Colors.white38,
                            ),
                      label: Text(
                        isSubmitting
                            ? 'Locking Log Pose GPS...'
                            : isOngoing
                            ? 'Check In Now'
                            : isUpcoming
                            ? 'Starts in ${minutesUntilStart.clamp(1, 99999)}m'
                            : 'Window Closed',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckedInBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
          SizedBox(width: 8),
          Text(
            'Attendance Recorded',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    bool checkedIn,
    bool ongoing,
    bool startingSoon,
    bool expired,
  ) {
    if (checkedIn) return _badge('Present', Colors.greenAccent);
    if (ongoing) return _badge('Active Now', GrandLinePalette.treasureGold);
    if (startingSoon) return _badge('Starting Soon', Colors.orangeAccent);
    if (expired) return _badge('Closed', Colors.grey);
    return _badge('Scheduled', Colors.lightBlueAccent);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

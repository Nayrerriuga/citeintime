import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_session_service.dart';
import '../theme/grand_line_theme.dart';

class AdminAnalyticsView extends StatefulWidget {
  final AdminSessionService service;

  const AdminAnalyticsView({super.key, required this.service});

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  List<Map<String, dynamic>> _sessions = [];
  String? _selectedSessionId;
  List<StudentAttendanceRecord> _records = [];

  String _selectedYearFilter = 'All';
  String _selectedStatusFilter = 'All'; // 'All', 'Present', 'Absent'
  String _searchQuery = '';

  bool _isLoading = true;

  static const List<String> _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await widget.service.fetchAllSessions();
      String? activeId = _selectedSessionId;
      if (sessions.isNotEmpty &&
          (activeId == null || !sessions.any((s) => s['id'] == activeId))) {
        activeId = sessions.first['id'].toString();
      }

      List<StudentAttendanceRecord> records = [];
      if (activeId != null) {
        records = await widget.service.fetchSessionAnalytics(activeId);
      }

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _selectedSessionId = activeId;
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: $e'),
            backgroundColor: GrandLinePalette.strawHatRed,
          ),
        );
      }
    }
  }

  Future<void> _onSessionChanged(String? sessionId) async {
    if (sessionId == null) return;
    setState(() {
      _selectedSessionId = sessionId;
      _isLoading = true;
    });
    try {
      final records = await widget.service.fetchSessionAnalytics(sessionId);
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSelfieDialog(StudentAttendanceRecord record) {
    final url = record.selfieUrl;
    if (url == null || url.isEmpty) return;

    final timeStr = record.checkedInAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(record.checkedInAt!)
        : 'Verified Check-In';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: GrandLinePalette.oceanMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      record.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${record.idNumber}  •  ${record.yearLevel}',
                style: TextStyle(
                  color: GrandLinePalette.parchmentCream.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(
                  color: GrandLinePalette.treasureGold.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  url,
                  height: 310,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 310,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: GrandLinePalette.treasureGold,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'Could not load verification photo.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: GrandLinePalette.strawHatRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close Photo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = _records.length;
    final totalPresent = _records.where((r) => r.isPresent).length;
    final totalAbsent = totalStudents - totalPresent;
    final attendanceRate =
        totalStudents == 0 ? 0.0 : (totalPresent / totalStudents) * 100;

    final filteredRecords = _records.where((r) {
      if (_selectedYearFilter != 'All' && r.yearLevel != _selectedYearFilter) {
        return false;
      }
      if (_selectedStatusFilter == 'Present' && !r.isPresent) return false;
      if (_selectedStatusFilter == 'Absent' && r.isPresent) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return r.fullName.toLowerCase().contains(q) ||
            r.idNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return RefreshIndicator(
      color: GrandLinePalette.treasureGold,
      backgroundColor: GrandLinePalette.oceanMid,
      onRefresh: _loadInitialData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _buildSessionDropdown(),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(
                  color: GrandLinePalette.treasureGold,
                ),
              ),
            )
          else if (_sessions.isEmpty)
            _buildEmptySessionsNotice()
          else ...[
            _buildOverallSummaryCard(
              totalStudents: totalStudents,
              present: totalPresent,
              absent: totalAbsent,
              rate: attendanceRate,
            ),
            const SizedBox(height: 12),
            _buildYearLevelBreakdownGrid(),
            const SizedBox(height: 14),
            _buildSearchAndStatusFilters(),
            const SizedBox(height: 10),
            if (filteredRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No students match the selected filter.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ...filteredRecords.map(_buildStudentRow),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSessionId,
          isExpanded: true,
          dropdownColor: GrandLinePalette.oceanDeep,
          icon: const Icon(
            Icons.expand_more_rounded,
            color: GrandLinePalette.treasureGold,
          ),
          hint: const Text(
            'Select Attendance Session',
            style: TextStyle(color: Colors.white70),
          ),
          items: _sessions.map((s) {
            final start = DateTime.tryParse(s['start_time']?.toString() ?? '')
                ?.toLocal();
            final dateLabel = start != null
                ? DateFormat('MMM d • h:mm a').format(start)
                : '';
            return DropdownMenuItem<String>(
              value: s['id'].toString(),
              child: Text(
                '${s['title']} ($dateLabel)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _onSessionChanged,
        ),
      ),
    );
  }

  Widget _buildOverallSummaryCard({
    required int totalStudents,
    required int present,
    required int absent,
    required double rate,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CREW ATTENDANCE OVERVIEW',
                style: TextStyle(
                  color: GrandLinePalette.treasureGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}% Present',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statPill('Total', totalStudents, Colors.lightBlueAccent),
              const SizedBox(width: 8),
              _statPill('Present', present, Colors.greenAccent),
              const SizedBox(width: 8),
              _statPill('Absent', absent, GrandLinePalette.strawHatRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: GrandLinePalette.oceanDeep.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: GrandLinePalette.parchmentCream.withValues(alpha: 0.85),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearLevelBreakdownGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _yearLevels.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.75,
      ),
      itemBuilder: (context, index) {
        final year = _yearLevels[index];
        final yearStudents =
            _records.where((r) => r.yearLevel == year).toList();
        final presentCount = yearStudents.where((r) => r.isPresent).length;
        final absentCount = yearStudents.length - presentCount;
        final progress =
            yearStudents.isEmpty ? 0.0 : presentCount / yearStudents.length;
        final isSelected = _selectedYearFilter == year;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedYearFilter = isSelected ? 'All' : year;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? GrandLinePalette.treasureGold.withValues(alpha: 0.18)
                  : GrandLinePalette.oceanMid.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? GrandLinePalette.treasureGold
                    : GrandLinePalette.treasureGold.withValues(alpha: 0.3),
                width: isSelected ? 1.8 : 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      year,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${yearStudents.length} total',
                      style: TextStyle(
                        color: GrandLinePalette.parchmentCream
                            .withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: GrandLinePalette.oceanDeep,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.greenAccent,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Present: $presentCount',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Absent: $absentCount',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchAndStatusFilters() {
    return Column(
      children: [
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: const TextStyle(color: Colors.white, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Search student name or ID...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: GrandLinePalette.treasureGold,
              size: 20,
            ),
            filled: true,
            fillColor: GrandLinePalette.oceanMid.withValues(alpha: 0.85),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _filterChip('All', _selectedStatusFilter == 'All', () {
              setState(() => _selectedStatusFilter = 'All');
            }),
            const SizedBox(width: 8),
            _filterChip('Present', _selectedStatusFilter == 'Present', () {
              setState(() => _selectedStatusFilter = 'Present');
            }),
            const SizedBox(width: 8),
            _filterChip('Absent', _selectedStatusFilter == 'Absent', () {
              setState(() => _selectedStatusFilter = 'Absent');
            }),
            const Spacer(),
            if (_selectedYearFilter != 'All')
              GestureDetector(
                onTap: () => setState(() => _selectedYearFilter = 'All'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: GrandLinePalette.strawHatRed.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_selectedYearFilter ✕',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? GrandLinePalette.treasureGold
              : GrandLinePalette.oceanMid.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? GrandLinePalette.oceanDeep : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRow(StudentAttendanceRecord record) {
    final badgeColor =
        record.isPresent ? Colors.greenAccent : GrandLinePalette.strawHatRed;
    final timeStr = record.checkedInAt != null
        ? DateFormat('h:mm a').format(record.checkedInAt!)
        : null;
    final hasSelfie =
        record.selfieUrl != null && record.selfieUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: hasSelfie ? () => _showSelfieDialog(record) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: badgeColor.withValues(alpha: 0.18),
                  child: Icon(
                    record.isPresent
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: badgeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${record.idNumber}  •  ${record.yearLevel}',
                        style: TextStyle(
                          color: GrandLinePalette.parchmentCream
                              .withValues(alpha: 0.75),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasSelfie) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          GrandLinePalette.treasureGold.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            GrandLinePalette.treasureGold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera_front_rounded,
                      color: GrandLinePalette.treasureGold,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: badgeColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        record.isPresent ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (timeStr != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySessionsNotice() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 52,
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 10),
          const Text(
            'No Sessions Created Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create an attendance session first to view 1st–4th Year analytics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
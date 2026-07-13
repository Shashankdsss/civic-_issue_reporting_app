import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class StatusTrackingScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const StatusTrackingScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Track Progress",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(report),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final String status = data['status'] ?? 'Pending';
    final Map<String, dynamic> statusHistory =
        (data['statusHistory'] as Map<String, dynamic>?) ?? {};
    final Map<String, dynamic> expectedStages =
        (data['expectedStages'] as Map<String, dynamic>?) ?? {};
    final String? rawDeadline = data['expectedResolutionDate'] as String?;
    final int slaDays = (data['slaDays'] as int?) ?? 7;
    DateTime? deadline;
    try { deadline = rawDeadline != null ? DateTime.parse(rawDeadline) : null; } catch (_) {}

    int currentStep = 0;
    if (status == 'Reported') {
      currentStep = 0;
    } else if (status == 'Verified') {
      currentStep = 1;
    } else if (status == 'In Progress') {
      currentStep = 2;
    } else if (status == 'Resolved') {
      currentStep = 3;
    }

    // Build stage expected-date labels from expectedStages
    DateTime? parseStageDate(String key) {
      try {
        final v = expectedStages[key] as String?;
        return v != null ? DateTime.parse(v) : null;
      } catch (_) {
        return null;
      }
    }

    final List<_TimelineStage> stages = [
      _TimelineStage(
        title: 'Reported',
        subtitle: 'Issue logged securely in the system',
        icon: Icons.flag_rounded,
        activeColor: const Color(0xFFE11D48),
        timestamp: statusHistory['Reported'],
        expectedDate: null, // always day 0, already done
      ),
      _TimelineStage(
        title: 'Verified',
        subtitle: 'An official has visited and verified the site',
        icon: Icons.verified_rounded,
        activeColor: const Color(0xFF3B82F6),
        timestamp: statusHistory['Verified'],
        expectedDate: parseStageDate('Verified'),
      ),
      _TimelineStage(
        title: 'In Progress',
        subtitle: 'Construction/Repair work is currently underway',
        icon: Icons.engineering_rounded,
        activeColor: const Color(0xFFD97706),
        timestamp: statusHistory['In Progress'],
        expectedDate: parseStageDate('In Progress'),
      ),
      _TimelineStage(
        title: 'Resolved',
        subtitle: 'The civic issue has been officially fixed',
        icon: Icons.check_circle_rounded,
        activeColor: const Color(0xFF059669),
        timestamp: statusHistory['Resolved'],
        expectedDate: parseStageDate('Resolved'),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Issue Info Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.description,
                      size: 30, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['category'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Status: $status",
                          style: GoogleFonts.poppins(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Department Routing Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance,
                      size: 22, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Forwarded To",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (data['department'] != null &&
                                data['department'].toString().isNotEmpty)
                            ? data['department']
                            : 'Municipal Authority',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Resolution ETA Banner ──
          if (deadline != null) _buildEtaBanner(deadline, slaDays, status),
          if (deadline != null) const SizedBox(height: 16),
          const SizedBox(height: 14),

          // ── Progress Bar ──
          Row(
            children: [
              Text(
                "Timeline",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentStep + 1}/4 stages',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (currentStep + 1) / 4,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                  stages[currentStep].activeColor),
            ),
          ),
          const SizedBox(height: 20),

          // ── Custom Timeline ──
          ...List.generate(stages.length, (index) {
            final stage = stages[index];
            final bool isCompleted = index <= currentStep;
            final bool isCurrent = index == currentStep;
            final bool isLast = index == stages.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Icon + connector line
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? stage.activeColor
                            : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color:
                                      stage.activeColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        isCompleted ? stage.icon : Icons.circle_outlined,
                        color: isCompleted
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 3,
                        height: 60,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isCompleted && index < currentStep
                              ? stage.activeColor.withValues(alpha: 0.4)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Right: Text content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stage.title,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: isCompleted
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCompleted
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stage.activeColor
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'CURRENT',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: stage.activeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stage.subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        if (stage.timestamp != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 12, color: stage.activeColor),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(stage.timestamp!),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: stage.activeColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Expected date hint for pending/current stages
                        if (!isCompleted && stage.expectedDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.event_outlined,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                'Expected by ${DateFormat('MMM d').format(stage.expectedDate!)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: isLast ? 0 : 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── ETA Banner ────────────────────────────────────────────────────────────
  Widget _buildEtaBanner(DateTime deadline, int slaDays, String status) {
    final now = DateTime.now();
    final int daysLeft = deadline.difference(now).inDays;
    final bool isResolved = status == 'Resolved';
    final bool isOverdue = !isResolved && daysLeft < 0;
    final bool isWarning = !isResolved && !isOverdue && daysLeft <= 2;

    final Color bannerBg = isResolved
        ? const Color(0xFFDCFCE7)
        : (isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFF0F9FF));
    final Color bannerBorder = isResolved
        ? const Color(0xFF86EFAC)
        : (isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFBAE6FD));
    final Color textColor = isResolved
        ? const Color(0xFF059669)
        : (isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0369A1));
    final IconData bannerIcon = isResolved
        ? Icons.check_circle_rounded
        : (isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded);
    final String statusLabel = isResolved
        ? 'Resolved ✓'
        : (isOverdue
            ? 'Overdue by ${-daysLeft} day${-daysLeft == 1 ? '' : 's'}'
            : (isWarning
                ? '$daysLeft day${daysLeft == 1 ? '' : 's'} left  ⚠️'
                : '$daysLeft day${daysLeft == 1 ? '' : 's'} remaining'));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: textColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isResolved ? 'Issue Resolved' : 'Expected Resolution',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: textColor,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(deadline),
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: textColor,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year} at $hour:$minute $period';
    } catch (_) {
      return isoTimestamp;
    }
  }

  Color _getStatusColor(String status) {
    if (status == 'Resolved') return const Color(0xFF059669);
    if (status == 'In Progress') return const Color(0xFFD97706);
    if (status == 'Verified') return const Color(0xFF3B82F6);
    return const Color(0xFFE11D48); // Reported / Pending
  }
}

class _TimelineStage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color activeColor;
  final String? timestamp;
  final DateTime? expectedDate;

  _TimelineStage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeColor,
    this.timestamp,
    this.expectedDate,
  });
}

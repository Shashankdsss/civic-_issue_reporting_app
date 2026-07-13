import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'status_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "Roads (Pothole)",
    "Water Leakage",
    "Garbage",
    "Drainage",
    "Street Light",
  ];

  void _refreshData() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Society Reports", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep), tooltip: "Clear All History", onPressed: () => _confirmClearAll()),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 20, top: 10),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search categories...",
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      backgroundColor: const Color(0xFFF1F5F9),
                      selectedColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF3B82F6),
                      labelStyle: GoogleFonts.poppins(
                        color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreService.getReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No reports found.", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16)));
                }
                final filteredReports = snapshot.data!.where((report) {
                  final cat = report['category'].toString().toLowerCase();
                  final matchesSearch = cat.contains(_searchQuery);
                  final matchesCategory = _selectedCategory == "All" || report['category'] == _selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredReports.isEmpty) {
                  return Center(child: Text("No matches found.", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) => _buildReportCard(filteredReports[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final statusColor = _getStatusColor(report['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StatusTrackingScreen(report: report))),
          onLongPress: () => _showAdminMenu(report),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(report['imagePath']),
                    width: 80, height: 80, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(report['category'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(report['status'] ?? 'Pending', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(report['timestamp'].toString().substring(0, 10), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                      if (report['description'] != null && report['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(report['description'], style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      // ── Deadline Badge ──
                      if (report['expectedResolutionDate'] != null && report['status'] != 'Resolved') ...[
                        const SizedBox(height: 6),
                        _buildDeadlineBadge(report['expectedResolutionDate'] as String),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.business, size: 12, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(
                            report['department']?.toString().isNotEmpty == true ? report['department'] : 'Municipal Authority',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          )),
                          if (report['priority'] != null)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: report['priority'] == 'High' ? Colors.red.withValues(alpha: 0.1) : (report['priority'] == 'Medium' ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(report['priority'], style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: report['priority'] == 'High' ? Colors.red : (report['priority'] == 'Medium' ? Colors.orange : Colors.green))),
                            ),
                        ],
                      ),
                      if (report['status'] == 'Resolved') ...[
                        const SizedBox(height: 6),
                        if (report['feedbackRating'] == null || report['feedbackRating'] == 0)
                          ElevatedButton.icon(
                            onPressed: () => _showFeedbackDialog(report),
                            icon: const Icon(Icons.star_border, size: 14),
                            label: Text("Provide Feedback", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.zero),
                          )
                        else
                          Row(children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text("You rated ${report['feedbackRating']}/5", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber[700])),
                          ]),
                      ],
                      const SizedBox(height: 8),
                      // ── Me Too Upvote Row ──
                      _UpvoteRow(
                        report: report,
                        onDelete: () async {
                          await FirestoreService.deleteReport(report['id']);
                          _refreshData();
                        },
                        onMap: () => _openMap(report['latitude'], report['longitude']),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _currentRating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  void _showFeedbackDialog(Map<String, dynamic> report) {
    _currentRating = 0;
    _feedbackController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Provide Feedback", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(index < _currentRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                  onPressed: () => setModalState(() => _currentRating = index + 1),
                )),
              ),
              const SizedBox(height: 10),
              TextField(controller: _feedbackController, decoration: InputDecoration(hintText: "Optional comment...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), maxLines: 2),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_currentRating == 0) return;
                  await FirestoreService.updateReportFeedback(report['id'], _currentRating, _feedbackController.text);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _refreshData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                child: const Text("Submit Feedback"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlineBadge(String isoDate) {
    try {
      final deadline = DateTime.parse(isoDate);
      final daysLeft = deadline.difference(DateTime.now()).inDays;
      final isOverdue = daysLeft < 0;
      final isWarning = !isOverdue && daysLeft <= 2;
      final Color color = isOverdue
          ? const Color(0xFFDC2626)
          : (isWarning ? const Color(0xFFD97706) : const Color(0xFF059669));
      final String label = isOverdue
          ? 'Overdue by ${-daysLeft} day${-daysLeft == 1 ? '' : 's'}'
          : (daysLeft == 0
              ? 'Due today'
              : '$daysLeft day${daysLeft == 1 ? '' : 's'} left');
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              'Resolve by ${DateFormat('MMM d').format(deadline)}  ·  $label',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(String? status) {
    if (status == 'Resolved') return const Color(0xFF059669);
    if (status == 'In Progress') return const Color(0xFFD97706);
    if (status == 'Verified') return const Color(0xFF3B82F6);
    if (status == 'Reported') return const Color(0xFFE11D48);
    return const Color(0xFF94A3B8); // Unknown
  }

  void _showAdminMenu(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update Status", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 15),
            _statusOption(report['id'], "Reported", const Color(0xFFE11D48)),
            _statusOption(report['id'], "Verified", const Color(0xFF3B82F6)),
            _statusOption(report['id'], "In Progress", const Color(0xFFD97706)),
            _statusOption(report['id'], "Resolved", const Color(0xFF059669)),
          ],
        ),
      ),
    );
  }

  Widget _statusOption(String id, String status, Color color) {
    return ListTile(
      leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      title: Text(status, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      onTap: () async {
        await FirestoreService.updateReportStatusWithTimestamp(id, status);
        await FirestoreService.insertNotification("Status Updated", "Your report is now marked as $status.");
        // Show local notification banner
        await NotificationService.show(title: "Report Status Updated", body: "Your civic report is now: $status");
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Status updated to $status")));
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  void _openMap(double lat, double lng) async {
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch Google Maps")));
    }
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear All History?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("This will delete all reports permanently.", style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              await FirestoreService.clearAllReports();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _refreshData();
            },
            child: Text("Clear All", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Animated Me Too Upvote Row ────────────────────────────────────────────────

class _UpvoteRow extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onDelete;
  final VoidCallback onMap;
  const _UpvoteRow({required this.report, required this.onDelete, required this.onMap});

  @override
  State<_UpvoteRow> createState() => _UpvoteRowState();
}

class _UpvoteRowState extends State<_UpvoteRow> with SingleTickerProviderStateMixin {
  late bool _upvoted;
  late int _count;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _upvoted = (widget.report['hasUpvoted'] ?? 0) == 1;
    _count = widget.report['upvotes'] ?? 0;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _toggle() async {
    _ctrl.forward(from: 0);
    final wasUpvoted = _upvoted;
    setState(() {
      _upvoted = !wasUpvoted;
      _count = _upvoted ? _count + 1 : (_count > 0 ? _count - 1 : 0);
    });
    await FirestoreService.toggleUpvote(widget.report['id'], wasUpvoted, wasUpvoted ? _count + 1 : _count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final color = _upvoted ? const Color(0xFF3B82F6) : Colors.grey[400]!;
    return Row(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _upvoted ? const Color(0xFF3B82F6).withAlpha(20) : Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(scale: _scale, child: Icon(Icons.thumb_up_alt_rounded, color: color, size: 14)),
                const SizedBox(width: 5),
                Text('Me Too · $_count', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
        const Spacer(),
        InkWell(onTap: widget.onMap, child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.map, color: Color(0xFF3B82F6), size: 22))),
        const SizedBox(width: 6),
        InkWell(onTap: widget.onDelete, child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 22))),
      ],
    );
  }
}

import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  static const _categories = [
    _Category('Roads', Icons.construction, Color(0xFF3B82F6)),
    _Category('Water', Icons.water_damage, Color(0xFF06B6D4)),
    _Category('Garbage', Icons.delete_sweep, Color(0xFF10B981)),
    _Category('Drainage', Icons.waves, Color(0xFFF59E0B)),
    _Category('Street Light', Icons.tungsten, Color(0xFFEC4899)),
    _Category('Other', Icons.report, Color(0xFF8B5CF6)),
  ];

  static const _statusColors = {
    'Pending': Color(0xFFE11D48),
    'Verified': Color(0xFF3B82F6),
    'In Progress': Color(0xFFD97706),
    'Resolved': Color(0xFF059669),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await FirestoreService.getReports();
      if (mounted) setState(() { _reports = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _countForCategory(String keyword) => _reports
      .where((r) => (r['category'] ?? '').toString().toLowerCase().contains(keyword.toLowerCase()))
      .length;

  int _countForStatus(String status) =>
      _reports.where((r) => r['status'] == status).length;

  double get _resolvedPct => _reports.isEmpty
      ? 0
      : (_countForStatus('Resolved') / _reports.length * 100);

  double get _avgUpvotes => _reports.isEmpty
      ? 0
      : _reports.fold<int>(0, (sum, r) => sum + ((r['upvotes'] ?? 0) as int)) / _reports.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Ward Analytics', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { setState(() => _isLoading = true); _loadData(); },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : _reports.isEmpty ? _buildEmptyState() : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 72, color: Color(0xFF334155)),
          const SizedBox(height: 16),
          Text('No data yet.\nReport an issue to see analytics.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards ──
          Row(
            children: [
              Expanded(child: _summaryCard('Total\nReports', '${_reports.length}', Icons.report_problem, const Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Resolved\nRate', '${_resolvedPct.toStringAsFixed(0)}%', Icons.check_circle, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(child: _summaryCard('Avg\nUpvotes', _avgUpvotes.toStringAsFixed(1), Icons.thumb_up, const Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 28),

          // ── Bar Chart ──
          _sectionHeader('Issues by Category'),
          const SizedBox(height: 16),
          _buildBarChart(),
          const SizedBox(height: 28),

          // ── Status Pie ──
          _sectionHeader('Status Breakdown'),
          const SizedBox(height: 16),
          _buildStatusSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(60), width: 1.5),
          ),
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
              const SizedBox(height: 12),
              Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white));

  Widget _buildBarChart() {
    final counts = [
      _countForCategory('Road'),
      _countForCategory('Water'),
      _countForCategory('Garbage'),
      _countForCategory('Drain'),
      _countForCategory('Street'),
      _reports.where((r) {
        final cat = (r['category'] ?? '').toString().toLowerCase();
        return !cat.contains('road') && !cat.contains('water') && !cat.contains('garbage') && !cat.contains('drain') && !cat.contains('street');
      }).length,
    ];
    final maxY = (counts.isEmpty ? 5 : counts.reduce((a, b) => a > b ? a : b) + 2).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: BarChart(
            BarChartData(
              maxY: maxY < 1 ? 5 : maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1E293B),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${_categories[groupIndex].label}\n',
                    GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                    children: [TextSpan(text: '${rod.toY.toInt()} issues', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))],
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
                  getTitlesWidget: (value, _) => Text('${value.toInt()}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final i = value.toInt();
                    if (i < 0 || i >= _categories.length) return const SizedBox();
                    return Padding(padding: const EdgeInsets.only(top: 6), child: Icon(_categories[i].icon, color: _categories[i].color, size: 16));
                  },
                )),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0x22FFFFFF), strokeWidth: 1)),
              barGroups: List.generate(_categories.length, (i) => BarChartGroupData(
                x: i,
                barRods: [BarChartRodData(
                  toY: counts[i].toDouble(),
                  color: _categories[i].color,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY < 1 ? 5 : maxY, color: Colors.white.withAlpha(8)),
                )],
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final total = _reports.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 160, width: 160,
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 40,
            sections: _statusColors.entries.map((entry) {
              final count = _countForStatus(entry.key);
              final pct = total == 0 ? 0.0 : count / total * 100;
              return PieChartSectionData(
                value: count.toDouble(),
                color: entry.value,
                radius: 50,
                title: pct > 5 ? '${pct.toStringAsFixed(0)}%' : '',
                titleStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _statusColors.entries.map((entry) {
              final count = _countForStatus(entry.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.key, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                    Text('$count', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  const _Category(this.label, this.icon, this.color);
}

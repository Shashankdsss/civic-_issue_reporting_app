import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/firebase_auth_service.dart';
import 'admin_complaint_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<List<dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _refreshReports();
  }

  void _refreshReports() {
    setState(() {
      _reportsFuture = AdminService.fetchAllReports();
    });
  }

  void _logout() async {
    await FirebaseAuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
      case 'Reported': return Colors.orange;
      case 'Assigned': return Colors.blue;
      case 'In Progress': return Colors.purple;
      case 'Resolved': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReports,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No complaints found."));
          }

          final reports = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              
              String formattedDate = '';
              if (report['createdAt'] != null) {
                try {
                  final dt = DateTime.parse(report['createdAt']).toLocal();
                  formattedDate = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                } catch (_) {}
              }
              
              String severity = (report['severity'] ?? 'LOW').toString().toUpperCase();
              Color severityColor = Colors.green;
              if (severity == 'HIGH' || severity == 'CRITICAL') severityColor = Colors.red;
              else if (severity == 'MEDIUM') severityColor = Colors.orange;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(report['category'] ?? 'Issue Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      // Severity badge 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: severityColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(severity, style: TextStyle(fontSize: 9, color: severityColor, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text("Reported by ${report['userId']?['firstName'] ?? 'Citizen'} ${report['userId']?['lastName'] ?? ''}", style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(report['status'] ?? 'Pending', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: _getStatusColor(report['status'] ?? 'Pending'),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminComplaintDetailScreen(report: report),
                      ),
                    ).then((_) => _refreshReports());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

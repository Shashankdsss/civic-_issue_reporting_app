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
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(report['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${report['location']} \nReported by: ${report['userId']?['firstName'] ?? 'Unknown'}"),
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

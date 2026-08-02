import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/admin_service.dart';

class AdminComplaintDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  const AdminComplaintDetailScreen({super.key, required this.report});

  @override
  State<AdminComplaintDetailScreen> createState() => _AdminComplaintDetailScreenState();
}

class _AdminComplaintDetailScreenState extends State<AdminComplaintDetailScreen> {
  late String _status;
  late String _department;
  late TextEditingController _remarksController;
  late TextEditingController _slaDaysController;
  DateTime? _selectedDate;
  bool _isLoading = false;

  final List<String> statuses = ['Pending', 'Assigned', 'In Progress', 'Resolved'];
  List<String> departments = ['', 'Roads', 'Water', 'Sanitation', 'Electricity', 'Parks', 'PWD', 'Jal Board', 'Municipal Corp.', 'Drainage Dept.', 'Electricity Board'];

  @override
  void initState() {
    super.initState();
    _status = widget.report['status'] ?? 'Pending';
    // ensure status is in dropdown logic, if it's 'Reported' change to 'Pending' visually for the dropdown
    if (!statuses.contains(_status)) _status = 'Pending';
    
    _department = widget.report['assignedDepartment'] ?? '';
    // Ensure the department exists in the list to prevent dropdown assertion crashes
    if (!departments.contains(_department)) {
      departments.add(_department);
    }
    
    _remarksController = TextEditingController(text: widget.report['adminRemarks'] ?? '');
    final int? existingSla = widget.report['slaDays'];
    _slaDaysController = TextEditingController(text: existingSla != null ? existingSla.toString() : '');
    
    if (widget.report['targetCompletionDate'] != null) {
      _selectedDate = DateTime.parse(widget.report['targetCompletionDate']);
    }
  }

  Future<void> _pickDate() async {
    final initial = _selectedDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _updateReport() async {
    setState(() => _isLoading = true);
    int? slaDays;
    DateTime? expectedResDate = _selectedDate;
    Map<String, dynamic>? expectedStages;

    final daysText = _slaDaysController.text.trim();
    if (daysText.isNotEmpty) {
      slaDays = int.tryParse(daysText);
      if (slaDays != null) {
        final now = DateTime.now();
        expectedResDate = now.add(Duration(days: slaDays));
        expectedStages = {
          'Verified': now.add(const Duration(days: 1)).toIso8601String(),
          'In Progress': now.add(Duration(days: (slaDays / 2).ceil())).toIso8601String(),
          'Resolved': expectedResDate.toIso8601String(),
        };
      }
    }

    try {
      await AdminService.updateReport(
        widget.report['_id'],
        _status,
        _department,
        expectedResDate?.toIso8601String(),
        slaDays,
        expectedStages,
        _remarksController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report updated successfully!')));
      Navigator.pop(context); // Go back to list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final String image = report['imageUrl'] ?? '';
    
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(image, height: 200, fit: BoxFit.cover, errorBuilder: (c,e,s) => const SizedBox()),
              ),
            const SizedBox(height: 16),
            Text(report['category'] ?? 'Reported Issue', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('Priority: ${report['priority'] ?? 'Medium'}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: report['priority'] == 'High' ? Colors.red : (report['priority'] == 'Low' ? Colors.green : Colors.orange),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(report['userName'] ?? 'Citizen', style: const TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.person, size: 16),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                if (report['createdAt'] != null)
                  Chip(
                    label: Text(DateTime.tryParse(report['createdAt'])?.toLocal().toString().split(' ')[0] ?? 'Unknown Date', style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report['description'] ?? 'No Description'),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.location_on, size: 16), const SizedBox(width: 4), Expanded(child: Text(report['location'] ?? ''))]),
            
            if (report['latitude'] != null && report['longitude'] != null) ...[
              const SizedBox(height: 16),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        double.tryParse(report['latitude'].toString()) ?? 0.0,
                        double.tryParse(report['longitude'].toString()) ?? 0.0,
                      ),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.civicissue',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              double.tryParse(report['latitude'].toString()) ?? 0.0,
                              double.tryParse(report['longitude'].toString()) ?? 0.0,
                            ),
                            width: 80,
                            height: 80,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('Open in Native Maps'),
                onPressed: () async {
                  final lat = report['latitude'].toString();
                  final lng = report['longitude'].toString();
                  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ],
            
            const Divider(height: 30),
            
            const Text("Admin Controls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _department,
              decoration: const InputDecoration(labelText: 'Assigned Department', border: OutlineInputBorder()),
              items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d.isEmpty ? 'None' : d))).toList(),
              onChanged: (v) => setState(() => _department = v!),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _slaDaysController,
              keyboardType: TextInputType.number,
              onChanged: (val) {
                final days = int.tryParse(val);
                if (days != null) {
                  setState(() {
                    _selectedDate = DateTime.now().add(Duration(days: days));
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Allocate SLA (Days)',
                hintText: 'e.g. 7',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer_rounded),
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Target Completion Date"),
              subtitle: Text(_selectedDate != null ? "${_selectedDate!.toLocal()}".split(' ')[0] : 'Not Set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Admin Remarks / Resolution Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _updateReport,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Complaint', style: TextStyle(fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}

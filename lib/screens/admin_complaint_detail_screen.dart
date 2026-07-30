import 'package:flutter/material.dart';
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
  DateTime? _selectedDate;
  bool _isLoading = false;

  final List<String> statuses = ['Pending', 'Assigned', 'In Progress', 'Resolved'];
  final List<String> departments = ['', 'Roads', 'Water', 'Sanitation', 'Electricity', 'Parks'];

  @override
  void initState() {
    super.initState();
    _status = widget.report['status'] ?? 'Pending';
    // ensure status is in dropdown logic, if it's 'Reported' change to 'Pending' visually for the dropdown
    if (!statuses.contains(_status)) _status = 'Pending';
    
    _department = widget.report['assignedDepartment'] ?? '';
    _remarksController = TextEditingController(text: widget.report['adminRemarks'] ?? '');
    
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
    try {
      await AdminService.updateReport(
        widget.report['_id'],
        _status,
        _department,
        _selectedDate?.toIso8601String(),
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
            Text(report['title'] ?? 'No Title', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(report['description'] ?? 'No Description'),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.location_on, size: 16), const SizedBox(width: 4), Expanded(child: Text(report['location'] ?? ''))]),
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

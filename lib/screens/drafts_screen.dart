import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/draft_service.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<DraftReport> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final drafts = await DraftService.getDrafts();
    setState(() {
      _drafts = drafts;
      _isLoading = false;
    });
  }

  void _deleteDraft(String id) async {
    await DraftService.deleteDraft(id);
    _loadDrafts();
  }

  void _openDraft(DraftReport draft) async {
    // Navigate to ReportScreen with draft data
    await Navigator.pushNamed(
      context, 
      '/report',
      arguments: draft,
    );
    // Reload drafts when we come back, in case it was submitted and deleted
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Drafts (Offline)"),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text("No saved drafts found", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _openDraft(draft),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: draft.mediaType == 'video'
                                  ? Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.black87,
                                      child: const Icon(Icons.videocam, color: Colors.white, size: 36),
                                    )
                                  : Image.file(
                                      File(draft.mediaPath),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 100,
                                        height: 100,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    draft.category.isEmpty ? "Uncategorized" : draft.category,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Location saved",
                                    style: GoogleFonts.poppins(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    draft.timestamp.split('.')[0], // simple formatting
                                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Draft?"),
                                    content: const Text("This action cannot be undone."),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteDraft(draft.id);
                                        },
                                        child: const Text("DELETE", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

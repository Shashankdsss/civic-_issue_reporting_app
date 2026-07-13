import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await FirestoreService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list.map((n) {
          n['localKey'] ??= UniqueKey().toString();
          return n;
        }).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    await FirestoreService.markNotificationRead(id);
    _loadNotifications();
  }

  Future<void> _clearAll() async {
    if (_notifications.isEmpty) return;
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Notifications"),
        content: const Text("Are you sure you want to delete all notifications?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("CLEAR ALL"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await FirestoreService.clearAllNotifications();
      await _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAll,
              tooltip: "Clear All",
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty 
          ? Center(child: Text("No notifications yet.", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead = notif['isRead'] == 1;
                final String dismissKey = notif['localKey'] ?? notif['id'] ?? index.toString();
                return Dismissible(
                  key: Key(dismissKey),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    final deletedNotif = _notifications[index];
                    final String deletedId = deletedNotif['id'];
                    
                    setState(() {
                      _notifications.removeAt(index);
                    });

                    bool undoTriggered = false;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Notification deleted"),
                        duration: const Duration(seconds: 7),
                        action: SnackBarAction(
                          label: "UNDO",
                          onPressed: () {
                            undoTriggered = true;
                            setState(() {
                              deletedNotif['localKey'] = UniqueKey().toString();
                              _notifications.insert(index, deletedNotif);
                            });
                          },
                        ),
                      ),
                    ).closed.then((reason) {
                      if (!undoTriggered) {
                        FirestoreService.deleteNotification(deletedId);
                      }
                    });
                  },
                  child: Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    color: isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.grey[200] : Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isRead ? Icons.notifications_none : Icons.notifications_active,
                          color: isRead ? Colors.grey[600] : Colors.blue[700],
                        ),
                      ),
                      title: Text(
                        notif['title'],
                        style: GoogleFonts.poppins(fontWeight: isRead ? FontWeight.w500 : FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(notif['message'], style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                          const SizedBox(height: 5),
                          Text(
                            notif['timestamp'].toString().substring(0, 16),
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!isRead) _markAsRead(notif['id']);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

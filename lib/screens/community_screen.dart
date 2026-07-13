import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Key _futureKey = UniqueKey();
  List<Map<String, dynamic>> _neighbors = [];
  List<String> _followingUids = [];
  bool _neighborsLoading = true;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _myUid = FirebaseAuthService.currentUser?.uid;
    _loadNeighborsAndFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNeighborsAndFollowing() async {
    if (_myUid == null) return;
    try {
      final results = await Future.wait([
        FirestoreService.getAllUsers(),
        FirestoreService.getFollowingUids(_myUid!),
      ]);
      if (mounted) {
        setState(() {
          _neighbors = (results[0] as List<Map<String, dynamic>>)
              .where((u) => u['uid'] != _myUid)
              .toList();
          _followingUids = results[1] as List<String>;
          _neighborsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _neighborsLoading = false);
    }
  }

  void _refreshData() {
    setState(() {
      _futureKey = UniqueKey();
    });
    _loadNeighborsAndFollowing();
  }

  Future<void> _toggleFollow(String targetUid) async {
    if (_myUid == null) return;
    if (_followingUids.contains(targetUid)) {
      await FirestoreService.unfollowUser(_myUid!, targetUid);
      setState(() => _followingUids.remove(targetUid));
    } else {
      await FirestoreService.followUser(_myUid!, targetUid);
      setState(() => _followingUids.add(targetUid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text("Community", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          unselectedLabelColor: Colors.white54,
          labelColor: Colors.white,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: "City Feed"),
            Tab(text: "Following"),
            Tab(text: "Neighbors"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedTab(filterByFollowing: false),
          _buildFeedTab(filterByFollowing: true),
          _buildNeighborsTab(),
        ],
      ),
    );
  }

  // ── FEED TAB (City / Following) ──────────────────────────────────────────
  Widget _buildFeedTab({required bool filterByFollowing}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      key: _futureKey,
      stream: FirestoreService.getReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
            icon: Icons.feed_outlined,
            title: filterByFollowing ? "No Followed Posts" : "No Reports Yet",
            subtitle: filterByFollowing
                ? "Follow neighbors to see their reports here!"
                : "Be the first to report an issue\nin your community!",
          );
        }

        List<Map<String, dynamic>> reports = snapshot.data!;
        if (filterByFollowing) {
          reports = reports.where((r) => _followingUids.contains(r['userId'])).toList();
          if (reports.isEmpty) {
            return _buildEmptyState(
              icon: Icons.people_outline,
              title: "No Posts From Followed Users",
              subtitle: "Go to the Neighbors tab to discover and follow people nearby!",
            );
          }
        }

        return RefreshIndicator(
          onRefresh: () async => _refreshData(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              return _buildFeedCard(reports[index]);
            },
          ),
        );
      },
    );
  }

  // ── NEIGHBORS TAB ─────────────────────────────────────────────────────────
  Widget _buildNeighborsTab() {
    if (_neighborsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async => _loadNeighborsAndFollowing(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        children: [
          _buildInviteCard(),
          if (_neighbors.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: _buildEmptyState(
                icon: Icons.location_off_outlined,
                title: "No Neighbors Yet",
                subtitle: "Invite your friends using the button above!\nThey'll appear here once they sign up.",
              ),
            )
          else
            ..._neighbors.map((user) => _buildNeighborCard(user)),
        ],
      ),
    );
  }

  Future<void> _inviteContacts() async {
    const message = 'Hey! Join me on CivicConnect — the app that lets you report civic issues like potholes, garbage & more in your neighborhood. Download now and let\'s make our city better together! 🏙️';
    final uri = Uri(scheme: 'sms', queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open messaging app.')));
      }
    }
  }

  Widget _buildInviteCard() {
    return GestureDetector(
      onTap: _inviteContacts,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite Your Neighbors!', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Share CivicConnect via SMS', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('INVITE', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeighborCard(Map<String, dynamic> user) {
    final String uid = user['uid'] ?? '';
    final String name = user['name'] ?? 'Citizen';
    final String region = user['region'] ?? 'Unknown Area';
    final bool isFollowing = _followingUids.contains(uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Flexible(child: Text(region, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _toggleFollow(uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey[200] : const Color(0xFF3B82F6),
              foregroundColor: isFollowing ? const Color(0xFF475569) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              isFollowing ? "Following" : "Follow",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> report) {
    final bool hasUpvoted = (report['hasUpvoted'] ?? 0) == 1;
    final int upvotes = report['upvotes'] ?? 0;
    final int commentCount = report['commentCount'] ?? 0;
    final String reportUserId = report['userId'] ?? '';
    final bool isMyPost = _myUid != null && reportUserId == _myUid;
    final String reporterName = isMyPost ? "You" : (report['userName'] ?? "A Neighbor");
    final String priority = report['priority'] ?? 'Low';

    Color priorityColor;
    if (priority == 'High') {
      priorityColor = Colors.red;
    } else if (priority == 'Medium') {
      priorityColor = Colors.orange;
    } else {
      priorityColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  child: Text(
                    reporterName[0].toUpperCase(),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reporterName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        report['timestamp']?.toString().substring(0, 16) ?? '',
                        style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Category + Priority badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        report['category'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(priority, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: priorityColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Image
          if (report['imagePath'] != null)
            ClipRRect(
              child: Image.file(
                File(report['imagePath']),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                ),
              ),
            ),

          // Description
          if (report['description'] != null && report['description'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                report['description'],
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF334155), height: 1.4),
              ),
            ),

          // Footer (Actions)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Me Too! Button
                InkWell(
                  onTap: () async {
                    await FirestoreService.toggleUpvote(report['id'], hasUpvoted, upvotes);
                    _refreshData();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasUpvoted ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: hasUpvoted ? Colors.red.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            hasUpvoted ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey<bool>(hasUpvoted),
                            color: hasUpvoted ? Colors.red : Colors.grey[500],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasUpvoted ? "Me Too! ($upvotes)" : "Me Too ($upvotes)",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: hasUpvoted ? Colors.red : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Comment Button
                InkWell(
                  onTap: () => _showCommentSheet(report['id']),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.grey[500], size: 18),
                        const SizedBox(width: 4),
                        Text(
                          "$commentCount",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // WhatsApp Share Button
                InkWell(
                  onTap: () async {
                    String category = report['category'] ?? 'Issue';
                    String text = Uri.encodeComponent("CivicConnect Alert! There is a $category issue reported near you. Open the app to view and upvote it so we can boost its priority!");
                    final Uri whatsappUrl = Uri.parse("whatsapp://send?text=$text");
                    try {
                      await launchUrl(whatsappUrl);
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch WhatsApp.")));
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share, color: Color(0xFF25D366), size: 18),
                  ),
                ),

                // Status badge
                if (report['status'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: report['status'] == 'Resolved'
                          ? const Color(0xFF059669).withValues(alpha: 0.1)
                          : const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          report['status'] == 'Resolved' ? Icons.check_circle : Icons.pending,
                          size: 14,
                          color: report['status'] == 'Resolved' ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          report['status'],
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: report['status'] == 'Resolved' ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _showCommentSheet(String reportId) {
    final TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirestoreService.getCommentsStream(reportId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) {
                      return const Center(child: Text("No comments yet. Support this issue!"));
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final comment = snapshot.data![index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            child: Text((comment['userName'] ?? 'C')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                          ),
                          title: Text(comment['userName'] ?? 'Citizen', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(comment['message'] ?? '', style: const TextStyle(fontSize: 14)),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 15, right: 15, top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF3B82F6)),
                      onPressed: () async {
                        if (commentController.text.trim().isEmpty) return;
                        final details = await FirebaseAuthService.getCurrentUserDetails();
                        await FirestoreService.addComment(
                          reportId,
                          _myUid ?? 'anonymous',
                          details?['name'] ?? 'Citizen',
                          commentController.text.trim(),
                        );
                        commentController.clear();
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }
}


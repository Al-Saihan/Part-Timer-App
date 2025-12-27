import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ! MARK: Ratings Screen
class RatingsScreen extends StatefulWidget {
  final int initialTab;
  const RatingsScreen({super.key, this.initialTab = 0});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Future<List<Map<String, dynamic>>> _eligibleFuture;
  late Future<List<Map<String, dynamic>>> _myFuture;
  late Future<List<Map<String, dynamic>>> _aboutMeFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadAll();
  }

  void _loadAll() {
    _eligibleFuture = _fetchEligible();
    _myFuture = _fetchMy();
    _aboutMeFuture = _fetchAboutMe();
  }

  // ! MARK: Data Fetching
  Future<List<Map<String, dynamic>>> _fetchEligible() async {
    final response = await ApiService.fetchEligibleRatings();
    if (!response.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
      return [];
    }
    return response.data ?? [];
  }

  Future<List<Map<String, dynamic>>> _fetchMy() async {
    final response = await ApiService.fetchMyRatings();
    if (!response.success) return [];
    return response.data ?? [];
  }

  Future<List<Map<String, dynamic>>> _fetchAboutMe() async {
    final response = await ApiService.fetchRatingsAboutMe();
    if (!response.success) return [];
    return response.data ?? [];
  }

  Future<void> _refreshAll() async {
    setState(() => _loadAll());
    await Future.wait([_eligibleFuture, _myFuture, _aboutMeFuture]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ! MARK: Helper Methods
  // ? Format date for display
  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      DateTime dt;
      if (raw is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(raw > 9999999999 ? raw : raw * 1000, isUtc: true).toLocal();
      } else if (raw is String) {
        dt = DateTime.parse(raw).toLocal();
      } else if (raw is DateTime) {
        dt = raw.toLocal();
      } else {
        return raw.toString();
      }
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  // ? Build star rating widget
  Widget _stars(int rating) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      return Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 16);
    }));
  }

  // ? Build avatar from user data
  Widget _avatarFromMap(dynamic user, {double radius = 20}) {
    try {
      if (user is Map) {
        final profilePic = user['profile_pic']?.toString();
        if (profilePic != null && profilePic.isNotEmpty) {
          final assetPath = 'assets/avatars/$profilePic.png';
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color.fromARGB(255, 213, 240, 255),
            child: ClipOval(
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                errorBuilder: (c, e, s) => CircleAvatar(radius: radius * 0.75, child: const Icon(Icons.person)),
              ),
            ),
          );
        }

        final img = user['avatar'] ?? user['profile_picture'] ?? user['photo'] ?? user['image'] ?? user['picture'];
        if (img is String && img.isNotEmpty) {
          String url = img;
          try {
            if (!url.startsWith('http')) {
              final baseRoot = ApiService.baseUrl.replaceAll('/api', '');
              url = baseRoot + (img.startsWith('/') ? img : '/$img');
            }
          } catch (_) {}

          return CircleAvatar(radius: radius, backgroundColor: Colors.grey[200], backgroundImage: NetworkImage(url), child: const SizedBox.shrink());
        }
      }
    } catch (_) {}

    return CircleAvatar(radius: radius, backgroundColor: Colors.grey[200], child: const Icon(Icons.person));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 31, 143, 189),
        foregroundColor: Colors.white,
        toolbarHeight: 50,
        elevation: 4,
        shadowColor: const Color.fromARGB(255, 31, 143, 189).withAlpha(150),
        title: const Text('Ratings'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [Tab(text: 'Eligible'), Tab(text: 'My Ratings'), Tab(text: 'About Me')],
        ),
      ),
      body: Stack(
        children: [
          // ! MARK: Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.fromARGB(255, 67, 163, 208), Color(0xFFE1F5FE)],
              ),
            ),
          ),

          // ? Decorative blur circles
          Positioned(
            top: -80,
            left: -60,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withAlpha(46),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -40,
            right: -50,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 46, 17, 189).withAlpha(64),
                ),
              ),
            ),
          ),

          // Content
          TabBarView(
            controller: _tabController,
            children: [
          // Eligible
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _eligibleFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final items = snap.data ?? [];
                // Only show candidates that can be rated and are not already rated
                final filtered = items.where((item) {
                  final canRate = (item['can_rate'] == true) || (item['canRate'] == true);
                  final existing = item['existing_rating'];
                  return canRate && (existing == null);
                }).toList();

                if (filtered.isEmpty) return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), Center(child: Text('No candidates available'))]);

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final jobTitle = item['job_title'] ?? item['jobTitle'] ?? 'Job';
                    final other = item['other_user'] ?? item['otherUser'] ?? item['other'] ?? {};
                    final name = other is Map ? (other['name'] ?? other['email'] ?? 'User') : 'User';
                    final canRate = (item['can_rate'] == true) || (item['canRate'] == true);
                    final existing = item['existing_rating'];

                    return Card(
                      elevation: 2,
                      color: const Color.fromARGB(255, 213, 240, 255),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: _avatarFromMap(other, radius: 22),
                        title: Text(name.toString()),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Text('Job: ${jobTitle.toString()}'),
                        ]),
                        trailing: canRate
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                onPressed: () => _showRateDialogForItem(item),
                                child: Text(existing != null ? 'Edit' : 'Rate', style: const TextStyle(color: Colors.white)),
                              )
                            : (existing != null
                                ? const Text('Already Rated!', style: TextStyle(color: Colors.grey))
                                : const Text('Not eligible', style: TextStyle(color: Colors.grey))),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // My Ratings
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _myFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final items = snap.data ?? [];
                if (items.isEmpty) return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), Center(child: Text('You have not rated anyone yet'))]);

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = items[index];
                    // expected shape: rating with ratedUser and job
                    final rated = r['ratedUser'] ?? r['rated_user'] ?? r['rated'] ?? r['other_user'] ?? r['other'] ?? {};
                    final job = r['job'] ?? r['job_relation'] ?? {};
                    final rating = r['rating'] ?? r['score'] ?? 0;
                    final review = r['review'] ?? r['comment'] ?? '';

                    return Card(
                      elevation: 2,
                      color: const Color.fromARGB(255, 213, 240, 255),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: _avatarFromMap(rated, radius: 22),
                        title: Text(rated is Map ? (rated['name'] ?? 'User') : 'User'),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Text('Job: ${job is Map ? (job['title'] ?? job['job_title'] ?? '') : ''}'),
                          const SizedBox(height: 6),
                          Row(children: [_stars((rating is int) ? rating : int.tryParse(rating?.toString() ?? '0') ?? 0)]),
                          if ((review ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(review.toString()),
                          ]
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // About Me
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _aboutMeFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final items = snap.data ?? [];
                if (items.isEmpty) return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), Center(child: Text('No ratings about you yet'))]);

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = items[index];
                    // expected shape: rating with rater and job
                    final rater = r['rater'] ?? r['rater_user'] ?? r['user'] ?? r['from'] ?? {};
                    final job = r['job'] ?? {};
                    final rating = r['rating'] ?? 0;
                    final review = r['review'] ?? r['comment'] ?? '';

                    return Card(
                      elevation: 2,                      color: const Color.fromARGB(255, 213, 240, 255),                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: _avatarFromMap(rater, radius: 22),
                        title: Text(rater is Map ? (rater['name'] ?? 'User') : 'User'),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Text('Job: ${job is Map ? (job['title'] ?? job['job_title'] ?? '') : ''}'),
                          const SizedBox(height: 6),
                          Row(children: [_stars((rating is int) ? rating : int.tryParse(rating?.toString() ?? '0') ?? 0), const SizedBox(width: 8), Text(_formatDate(r['created_at'] ?? r['created'] ?? r['createdAt'] ?? ''))]),
                          if ((review ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(review.toString()),
                          ]
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ],
      ),
    );
  }

  void _showRateDialogForItem(Map<String, dynamic> item) {
    final other = item['other_user'] ?? item['otherUser'] ?? item['other'] ?? {};
    final ratedId = other is Map ? (other['id'] ?? other['user_id']) : null;
    final jobId = item['job_id'] ?? item['jobId'];

    int rating = 5;
    final reviewCtrl = TextEditingController();
    bool loading = false;

    final existing = item['existing_rating'];
    if (existing is Map) {
      rating = (existing['rating'] is int) ? existing['rating'] : int.tryParse(existing['rating']?.toString() ?? '') ?? rating;
      reviewCtrl.text = (existing['review'] ?? existing['comment'] ?? '')?.toString() ?? '';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 213, 240, 255),
              title: Text('Rate ${other is Map ? (other['name'] ?? 'User') : 'User'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final idx = i + 1;
                      return IconButton(
                        icon: Icon(idx <= rating ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: () => setState(() => rating = idx),
                      );
                    }),
                  ),
                  TextField(controller: reviewCtrl, decoration: const InputDecoration(hintText: 'Write a review (optional)'), maxLines: 1),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel', style: TextStyle(color: Colors.blue))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          if (ratedId == null || jobId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing user/job id')));
                            return;
                          }
                          setState(() => loading = true);
                          final response = await ApiService.submitRating(
                            ratedUserId: int.tryParse(ratedId.toString()) ?? 0,
                            jobId: int.tryParse(jobId.toString()) ?? 0,
                            rating: rating,
                            review: reviewCtrl.text.trim().isEmpty ? null : reviewCtrl.text.trim(),
                          );
                          setState(() => loading = false);
                          
                          if (response.success) {
                            Navigator.pop(ctx2);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(response.message)),
                            );
                            await _refreshAll();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(response.message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


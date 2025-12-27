import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/api_response.dart';
import '../includes/auth.dart';
import 'sign_in.dart';
import 'ratings_screen.dart';
import 'chat_rooms_screen.dart';
import 'chat_screen.dart';

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  try {
    DateTime dt;
    if (raw is int) {
      // assume epoch seconds or ms
      dt = DateTime.fromMillisecondsSinceEpoch(
        raw > 9999999999 ? raw : raw * 1000,
        isUtc: true,
      ).toLocal();
    } else if (raw is String) {
      dt = DateTime.parse(raw).toLocal();
    } else if (raw is DateTime) {
      dt = raw.toLocal();
    } else {
      return raw.toString();
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    return raw.toString();
  }
}

// ! MARK: Start
class HomeRecruiterPage extends StatefulWidget {
  const HomeRecruiterPage({super.key});

  @override
  State<HomeRecruiterPage> createState() => _HomeRecruiterPageState();
}

// Show applicant details and allow recruiter to update status
void _showApplicantDetails(
  BuildContext context,
  Map<String, dynamic> applicant, {
  VoidCallback? onUpdated,
}) {
  final seeker = applicant['seeker'] ?? applicant['user'] ?? {};
  final job = applicant['job'] ?? {};
  final name = seeker is Map
      ? (seeker['name'] ?? seeker['email'] ?? 'Seeker')
      : 'Seeker';
  final email = seeker is Map ? (seeker['email'] ?? '') : '';
  final jobTitle = job is Map
      ? (job['title'] ?? 'Job')
      : (applicant['job_title'] ?? 'Job');
  final status = (applicant['STATUS'] ?? applicant['status'] ?? 'pending')
      .toString();
  final appliedAt = applicant['applied_at'] ?? applicant['created_at'] ?? '';
  final dateStr = _formatDate(appliedAt);
  // Parse seeker skills and ratings safely
  List<String> skills = [];
  try {
    final rawSkills = seeker is Map ? seeker['skills'] : null;
    if (rawSkills is String) {
      skills = rawSkills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else if (rawSkills is List) {
      skills = rawSkills.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
  } catch (_) {
    skills = [];
  }

  final seekerAvgRating = seeker is Map ? (seeker['avg_rating'] ?? seeker['rating'] ?? seeker['avgRating']) : null;
  final seekerRatingCount = seeker is Map ? (seeker['rating_count'] ?? seeker['ratingCount'] ?? 0) : 0;

  showDialog(
    context: context,
    builder: (ctx) {
      bool loading = false;
      return StatefulBuilder(
        builder: (ctx2, setState) {
          return AlertDialog(
            backgroundColor: const Color.fromARGB(255, 213, 240, 255),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileAvatar(seeker),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (email.toString().isNotEmpty)
                            Text(
                              email.toString(),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            jobTitle.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        status,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      backgroundColor: status.toLowerCase() == 'pending'
                          ? const Color.fromARGB(255, 172, 106, 1)
                          : (status.toLowerCase() == 'accepted'
                                ? const Color.fromARGB(255, 64, 184, 74)
                                : const Color.fromARGB(255, 219, 44, 70)),
                    ),
                    const Spacer(),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Seeker details: location, bio, skills, ratings
                if ((seeker is Map) && (seeker['location'] ?? seeker['address']) != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (seeker['location'] ?? seeker['address']).toString(),
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if ((seeker is Map) && (seeker['bio'] ?? '').toString().isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (seeker['bio'] ?? '').toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (skills.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: skills.map((s) => Chip(label: Text(s))).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (seekerAvgRating != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(seekerAvgRating.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('(${seekerRatingCount.toString()})', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final seekerId = seeker is Map ? (seeker['id'] ?? seeker['user_id']) : null;
                        if (seekerId == null) {
                          ScaffoldMessenger.of(ctx2).showSnackBar(
                            const SnackBar(content: Text('Unable to start chat')),
                          );
                          return;
                        }

                        Navigator.pop(ctx2);
                        
                        // Show loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening chat...')),
                        );

                        // Create or get chat room
                        final response = await ApiService.createOrGetChatRoom(
                          otherUserId: seekerId,
                        );

                        if (response.success && response.data != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                roomId: response.data!.id,
                                otherUser: seeker is Map ? Map<String, dynamic>.from(seeker) : {},
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(response.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Contact'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: loading
                            ? null
                            : () async {
                                final aid =
                                    applicant['id'] ??
                                    applicant['application_id'] ??
                                    applicant['app_id'];
                                final appId = aid is int
                                    ? aid
                                    : int.tryParse(aid?.toString() ?? '') ?? 0;
                                if (appId == 0) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid application id'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => loading = true);
                                final response = await ApiService.updateApplicationStatus(
                                  applicationId: appId,
                                  status: 'rejected',
                                );
                                setState(() => loading = false);
                                
                                if (response.success) {
                                  Navigator.pop(ctx2);
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    SnackBar(content: Text(response.message)),
                                  );
                                  if (onUpdated != null) onUpdated();
                                } else {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    SnackBar(
                                      content: Text(response.message),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          'Reject',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: loading
                            ? null
                            : () async {
                                final aid =
                                    applicant['id'] ??
                                    applicant['application_id'] ??
                                    applicant['app_id'];
                                final appId = aid is int
                                    ? aid
                                    : int.tryParse(aid?.toString() ?? '') ?? 0;
                                if (appId == 0) {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invalid application id'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => loading = true);
                                final response = await ApiService.updateApplicationStatus(
                                  applicationId: appId,
                                  status: 'accepted',
                                );
                                setState(() => loading = false);
                                
                                if (response.success) {
                                  Navigator.pop(ctx2);
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    SnackBar(content: Text(response.message)),
                                  );
                                  if (onUpdated != null) onUpdated();
                                } else {
                                  ScaffoldMessenger.of(ctx2).showSnackBar(
                                    SnackBar(
                                      content: Text(response.message),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildProfileAvatar(Map<String, dynamic>? user, {double radius = 40}) {
  // Prefer using `profile_pic` (asset name) when present
  if (user != null) {
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
            errorBuilder: (c, e, s) => CircleAvatar(
              radius: radius * 0.75,
              child: const Icon(Icons.person, size: 18),
            ),
          ),
        ),
      );
    }
  }

  // Fallback: support various remote image keys
  String? img;
  if (user != null) {
    img =
        user['avatar']?.toString() ??
        user['profile_picture']?.toString() ??
        user['photo']?.toString() ??
        user['image']?.toString() ??
        user['picture']?.toString();
  }

  if (img == null || img.isEmpty) {
    return CircleAvatar(radius: radius, child: const Icon(Icons.person, size: 18));
  }

  String url = img;
  try {
    if (!url.startsWith('http')) {
      final baseRoot = ApiService.baseUrl.replaceAll('/api', '');
      url = baseRoot + (img.startsWith('/') ? img : '/$img');
    }
  } catch (_) {}

  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.grey[200],
    backgroundImage: NetworkImage(url),
    child: const SizedBox.shrink(),
  );
}

class _HomeRecruiterPageState extends State<HomeRecruiterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 31, 143, 189),
          foregroundColor: Colors.white,
          toolbarHeight: 50,
          elevation: 4,
          shadowColor: const Color.fromARGB(255, 31, 143, 189).withAlpha(150),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('Recruiter Dashboard'),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: const [
              Tab(text: 'Home'),
              Tab(text: 'Posted Jobs'),
              Tab(text: 'Profile'),
            ],
          ),
        ),

        drawer: _buildDrawer(context),

        body: Stack(
          children: [
            // ? MARK: Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.fromARGB(255, 67, 163, 208), Color(0xFFE1F5FE)],
                ),
              ),
            ),

            // ? Soft decorative circle 1
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

            // ? Soft decorative circle 2
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
              children: const [RecruiterHomeTab(), PostedJobsTab(), ProfileTab()],
            ),
          ],
        ),

        // FAB only visible on "Posted Jobs" tab (index 1)
        floatingActionButton: _currentTabIndex == 1
            ? FloatingActionButton(
                backgroundColor: Colors.blue,
                onPressed: () => _showAddJobDialog(context),
                tooltip: 'Add Job',
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}

// ! MARK: Home Tab
class RecruiterHomeTab extends StatefulWidget {
  const RecruiterHomeTab({super.key});

  @override
  State<RecruiterHomeTab> createState() => _RecruiterHomeTabState();
}

class _RecruiterHomeTabState extends State<RecruiterHomeTab> {
  late Future<List<Map<String, dynamic>>?> _applicantsFuture;

  @override
  void initState() {
    super.initState();
    _applicantsFuture = _fetchApplicants();
  }

  Future<List<Map<String, dynamic>>?> _fetchApplicants() async {
    final response = await ApiService.fetchApplicants();
    if (!response.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
    return response.data;
  }

  Future<void> _refresh() async {
    setState(() {
      _applicantsFuture = _fetchApplicants();
    });
    await _applicantsFuture;
  }

  Future<Map<String, dynamic>?> _fetchCurrentUser() async {
    final response = await ApiService.fetchCurrentUser();
    if (!response.success) return null;
    return response.data;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ! MARK: Profile
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _fetchCurrentUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final user = snapshot.data;

                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          elevation: 4,
                          color: const Color.fromARGB(255, 213, 240, 255),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: user == null
                                ? const Center(child: Text('No profile data'))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['name']?.toString() ?? 'No name',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        user['email']?.toString() ?? 'No email',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Role: ${user['user_type'] ?? user['type'] ?? 'unknown'}',
                                      ),
                                      const SizedBox(height: 8),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Card(
                          elevation: 4,
                          color: const Color.fromARGB(255, 213, 240, 255),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            height: 135,
                            child: Center(child: _buildProfileAvatar(user)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(),

            // ! MARK: Applicants
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'Job Applicants',
                  style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: const Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black.withAlpha(77),
                    ),
                  ],
                ),
                ),
              ),
            ),

            // Applicants list
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: FutureBuilder<List<Map<String, dynamic>>?>(
                future: _applicantsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final applicants = snapshot.data ?? [];

                  if (applicants.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No applicants yet'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: applicants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final a = applicants[index];
                      final seeker = a['seeker'] ?? a['user'] ?? {};
                      final job = a['job'] ?? {};
                      final name = seeker is Map
                          ? (seeker['name'] ?? seeker['email'] ?? 'Seeker')
                          : 'Seeker';
                      final email = seeker is Map
                          ? (seeker['email'] ?? '')
                          : '';
                      final jobTitle = job is Map
                          ? (job['title'] ?? 'Job')
                          : (a['job_title'] ?? 'Job');
                      final status = (a['STATUS'] ?? a['status'] ?? 'pending')
                          .toString()
                          .toUpperCase();
                      final appliedAt =
                          a['applied_at'] ?? a['created_at'] ?? '';
                      final dateStr = _formatDate(appliedAt);

                      return Card(
                        elevation: 4,
                        color: const Color.fromARGB(255, 213, 240, 255),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showApplicantDetails(
                            context,
                            a,
                            onUpdated: _refresh,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                _buildProfileAvatar(seeker, radius: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (email.toString().isNotEmpty)
                                        Text(email.toString()),
                                      Text(
                                        'Job: $jobTitle',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status.toLowerCase() == 'pending'
                                            ? const Color.fromARGB(255, 172, 106, 1)
                                            : status.toLowerCase() == 'rejected'
                                            ? const Color.fromARGB(255, 219, 44, 70)
                                            : const Color.fromARGB(255, 64, 184, 74),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (dateStr.isNotEmpty)
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ! MARK: Posted Jobs
class PostedJobsTab extends StatefulWidget {
  const PostedJobsTab({super.key});

  @override
  State<PostedJobsTab> createState() => _PostedJobsTabState();
}

class _PostedJobsTabState extends State<PostedJobsTab> {
  late Future<List<Map<String, dynamic>>?> _postedJobsFuture;

  @override
  void initState() {
    super.initState();
    _postedJobsFuture = _fetchPostedJobs();
  }

  Future<List<Map<String, dynamic>>?> _fetchPostedJobs() async {
    final response = await ApiService.fetchPostedJobs();
    if (!response.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
    return response.data;
  }

  Future<void> _refresh() async {
    setState(() {
      _postedJobsFuture = _fetchPostedJobs();
    });
    await _postedJobsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>?>(
        future: _postedJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final jobs = snapshot.data ?? [];

          if (jobs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No posted jobs yet')),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Posted Jobs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black.withAlpha(77),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh, color: Colors.white,),
                        onPressed: _refresh,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    final id = job['id'] ?? 0;
                    final title = job['title'] ?? 'Untitled';
                    final workingHours =
                        job['working_hours']?.toString() ??
                        job['workingHours']?.toString() ??
                        '0';
                    final payment = job['payment']?.toString() ?? '0';
                    final appsCount =
                        job['applications_count'] ?? job['applications'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: const Color.fromARGB(255, 213, 240, 255),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showApplicantsDialog(context, id, title),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // avatar
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.work,
                                      size: 28,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 18),

                              // main content: title, location, hours, payment each on its own line
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      " $title",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // location line
                                    if ((job['location'] ?? job['locations']) != null) ...[
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              (job['location'] is String)
                                                  ? job['location']
                                                  : (job['locations'] is List)
                                                      ? (job['locations'] as List).join(', ')
                                                      : job['location']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                    ],

                                    // hours line
                                    Row(
                                      children: [
                                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '$workingHours hrs/day',
                                            style: const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // payment line
                                    Row(
                                      children: [
                                        Icon(Icons.payments, size: 14, color: Colors.green[700]),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '$payment per hour',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // applicants badge
                              const SizedBox(width: 12),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text('$appsCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.blue[50],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('applicants', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // _showJobOptions removed — jobs now open applicants directly on tap

  void _showApplicantsDialog(
    BuildContext context,
    int jobId,
    String jobTitle,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    final response = await ApiService.fetchApplicants();
    
    if (!response.success) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final all = response.data ?? [];
    final filtered = all.where((a) {
        // Job may come under key 'job' or 'job_id'
        final j = a['job'];
        if (j is Map && j['id'] != null) return j['id'] == jobId;
        if (a['job_id'] != null) return a['job_id'] == jobId;
        return false;
      }).toList();

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color.fromARGB(255, 213, 240, 255),
            title: Text('Applicants - $jobTitle'),
            content: SizedBox(
              width: double.maxFinite,
              child: filtered.isEmpty
                  ? const Text('No applicants yet')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final a = filtered[index];
                        final seeker = a['seeker'] ?? a['user'] ?? {};
                        final name = seeker is Map
                            ? (seeker['name'] ?? seeker['email'] ?? 'Seeker')
                            : 'Seeker';
                        final appliedAt =
                            a['applied_at'] ?? a['created_at'] ?? '';
                        final dateStr = _formatDate(appliedAt);

                        return Card(
                          elevation: 3,
                          color: const Color.fromARGB(255, 213, 240, 255),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showApplicantDetails(
                                context,
                                a,
                                onUpdated: () => _refresh(),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  _buildProfileAvatar(seeker),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (dateStr.isNotEmpty)
                                          Text(
                                            dateStr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: filtered.length,
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
  }
}

// ! MARK: Profile Tab
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _loadingBio = false;
  bool _loadingLocation = false;
  late Future<Map<String, dynamic>?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUser();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchUser() async {
    final response = await ApiService.fetchCurrentUser();
    if (!response.success) return null;
    return response.data;
  }

  Future<void> _refreshUser() async {
    setState(() {
      _userFuture = _fetchUser();
    });
    await _userFuture;
  }

  Future<void> _updateField(String field) async {
    setState(() {
      if (field == 'bio') _loadingBio = true;
      if (field == 'location') _loadingLocation = true;
    });

    final scaffold = ScaffoldMessenger.of(context);
    
    dynamic response;
    if (field == 'bio') {
      response = await ApiService.updateBio(
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      );
    } else if (field == 'location') {
      response = await ApiService.updateLocation(
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
      );
    }

    if (response.success) {
      scaffold.showSnackBar(
        SnackBar(content: Text(response.message)),
      );
      await _refreshUser();
    } else {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() {
      if (field == 'bio') _loadingBio = false;
      if (field == 'location') _loadingLocation = false;
    });
  }

  void _showProfileActions() {
    // Directly open avatar chooser — remove "Edit Details" option
    _showAvatarChooser();
  }

  Future<void> _showAvatarChooser() async {
    final scaffold = ScaffoldMessenger.of(context);
    await showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (ctx2, setState) {
            return AlertDialog(
              backgroundColor: const Color.fromARGB(255, 213, 240, 255),
              title: const Text('Choose Avatar'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    const Text('Select an avatar from the set'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: List.generate(50, (i) {
                          final idx = i + 1;
                          final name = 'Avatars Set Flat Style-$idx';
                          final assetPath = 'assets/avatars/$name.png';

                          return GestureDetector(
                            onTap: loading
                                ? null
                                : () async {
                                    setState(() => loading = true);
                                    final response = await ApiService.updateProfilePic(
                                      profilePic: name,
                                    );
                                    setState(() => loading = false);
                                    
                                    if (response.success) {
                                      scaffold.showSnackBar(
                                        SnackBar(content: Text(response.message)),
                                      );
                                      Navigator.pop(ctx2);
                                      await _refreshUser();
                                    } else {
                                      scaffold.showSnackBar(
                                        SnackBar(
                                          content: Text(response.message),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipOval(
                                    child: Image.asset(
                                      assetPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) =>
                                          const CircleAvatar(
                                            child: Icon(Icons.person),
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  idx.toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _userFuture,
          builder: (context, snapshot) {
            final user = snapshot.data;

            if (snapshot.connectionState == ConnectionState.done &&
                user != null) {
              if (_bioCtrl.text.isEmpty) {
                _bioCtrl.text = user['bio']?.toString() ?? '';
              }
              if (_locationCtrl.text.isEmpty) {
                _locationCtrl.text = (user['locations'] is List)
                    ? (user['locations'] as List).join(', ')
                    : (user['locations']?.toString() ??
                          user['location']?.toString() ??
                          '');
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  color: const Color.fromARGB(255, 213, 240, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?['name']?.toString() ?? 'No name',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user?['email']?.toString() ?? 'No email',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Role: ${user?['user_type'] ?? user?['type'] ?? 'unknown'}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Created: ${_formatDate(user?['created_at'] ?? user?['createdAt'] ?? user?['created'] ?? '')}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              Card(
                                elevation: 2,
                                color: const Color.fromARGB(255, 213, 240, 255),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SizedBox(
                                  height: 120,
                                  child: Center(
                                    child: _buildProfileAvatar(user),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 140,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        side: const BorderSide(color: Colors.blue),
                                        foregroundColor: Colors.blue,
                                      ),
                                      onPressed: () => _showProfileActions(),
                                      label: const Text('Edit'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bio
                Card(
                  elevation: 2,
                  color: const Color.fromARGB(255, 213, 240, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Bio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bioCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Tell us about yourself',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              onPressed: _loadingBio
                                  ? null
                                  : () => _updateField('bio'),
                              child: _loadingBio
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Update Bio', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Locations
                Card(
                  elevation: 2,
                  color: const Color.fromARGB(255, 213, 240, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Locations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter your address',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              onPressed: _loadingLocation
                                  ? null
                                  : () => _updateField('location'),
                              child: _loadingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Update Location', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ! MARK: Drawer
Drawer _buildDrawer(BuildContext context) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.fromARGB(255, 67, 163, 208), Color.fromARGB(255, 0, 101, 147)],
            ),
          ),
          child: FutureBuilder<ApiResponse<Map<String, dynamic>>>(
            future: ApiService.fetchCurrentUser(),
            builder: (ctx, snap) {
              final user = snap.data?.data;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProfileAvatar(user, radius: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user == null ? 'Recruiter' : (user['name']?.toString() ?? 'Recruiter'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user == null ? '' : (user['email']?.toString() ?? ''),
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        const Text('Quick actions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text('Messages', style: Theme.of(context).textTheme.titleSmall),
        ),

        ListTile(
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.inbox, color: Colors.blue),
          title: const Text('Inbox'),
          subtitle: const Text('View your messages'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatRoomsScreen()));
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        const Divider(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text('Ratings', style: Theme.of(context).textTheme.titleSmall),
        ),

        ListTile(
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.how_to_vote, color: Colors.indigo),
          title: const Text('Eligible'),
          subtitle: const Text('People you can rate'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RatingsScreen(initialTab: 0)));
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        ListTile(
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.rate_review, color: Colors.green),
          title: const Text('My Ratings'),
          subtitle: const Text('Ratings you created'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RatingsScreen(initialTab: 1)));
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        ListTile(
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.reviews, color: Colors.orange),
          title: const Text('About Me'),
          subtitle: const Text('Ratings written about you'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RatingsScreen(initialTab: 2)));
          },
          trailing: const Icon(Icons.chevron_right),
        ),

        const Divider(height: 18, thickness: 1),

        ListTile(
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          subtitle: const Text('Sign out from the app'),
          onTap: () async {
            Navigator.pop(context); // close drawer

            await ApiService.logout();
            await clearToken();
            
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SignInPage()),
                (route) => false,
              );
            }
          },
        ),

        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('App version: 1.0.0', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

// ! MARK: Add Job
void _showAddJobDialog(BuildContext context) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final hoursCtrl = TextEditingController();
  final paymentCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  String selectedDifficulty = 'easy';
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: const Color.fromARGB(255, 213, 240, 255),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Job',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Job Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDifficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedDifficulty = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hoursCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Working Hours / Day',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: paymentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Payment per Hour',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location (optional)',
                        hintText: 'City, address or remote',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blue),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() => isLoading = true);
                                      
                                    final title = titleCtrl.text.trim();
                                    final desc = descCtrl.text.trim();
                                    final hours =
                                        int.tryParse(hoursCtrl.text.trim()) ??
                                        0;
                                    final payment =
                                        double.tryParse(
                                          paymentCtrl.text.trim(),
                                        ) ??
                                        0;

                                      if (title.isEmpty ||
                                          desc.isEmpty ||
                                          hours <= 0 ||
                                          payment <= 0) {
                                        setState(() => isLoading = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please fill all fields correctly',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                    final response = await ApiService.createJob(
                                      title: title,
                                      description: desc,
                                      difficulty: selectedDifficulty,
                                      workingHours: hours,
                                      payment: payment,
                                      location: locationCtrl.text.trim().isEmpty
                                          ? null
                                          : locationCtrl.text.trim(),
                                    );
                                    
                                    setState(() => isLoading = false);

                                    if (response.success) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(response.message)),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(response.message),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Add Job'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}


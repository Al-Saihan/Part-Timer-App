import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../includes/auth.dart';
import 'sign_in.dart';

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  try {
    DateTime dt;
    if (raw is int) {
      // assume epoch seconds or ms
      dt = DateTime.fromMillisecondsSinceEpoch(raw > 9999999999 ? raw : raw * 1000, isUtc: true).toLocal();
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
void _showApplicantDetails(BuildContext context, Map<String, dynamic> applicant, {VoidCallback? onUpdated}) {
  final seeker = applicant['seeker'] ?? applicant['user'] ?? {};
  final job = applicant['job'] ?? {};
  final name = seeker is Map ? (seeker['name'] ?? seeker['email'] ?? 'Seeker') : 'Seeker';
  final email = seeker is Map ? (seeker['email'] ?? '') : '';
  final jobTitle = job is Map ? (job['title'] ?? 'Job') : (applicant['job_title'] ?? 'Job');
  final status = (applicant['STATUS'] ?? applicant['status'] ?? 'pending').toString();
  final appliedAt = applicant['applied_at'] ?? applicant['created_at'] ?? '';
  final dateStr = _formatDate(appliedAt);

  showDialog(
    context: context,
    builder: (ctx) {
      bool loading = false;
      return StatefulBuilder(builder: (ctx2, setState) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        Text(name.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (email.toString().isNotEmpty) Text(email.toString(), style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(jobTitle.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(status, style: const TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: status.toLowerCase() == 'pending' ? Colors.orange[50] : (status.toLowerCase() == 'accepted' ? Colors.green[50] : Colors.red[50]),
                  ),
                  const Spacer(),
                  if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Contact pressed'))),
                    child: const Text('Contact'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading
                          ? null
                          : () async {
                              final aid = applicant['id'] ?? applicant['application_id'] ?? applicant['app_id'];
                              final appId = aid is int ? aid : int.tryParse(aid?.toString() ?? '') ?? 0;
                              if (appId == 0) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Invalid application id')));
                                return;
                              }
                              setState(() => loading = true);
                              try {
                                await ApiService.updateApplicationStatus(applicationId: appId, status: 'rejected');
                                Navigator.pop(ctx2);
                                ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Application rejected')));
                                if (onUpdated != null) onUpdated();
                              } catch (e) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              } finally {
                                setState(() => loading = false);
                              }
                            },
                      child: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: loading
                          ? null
                          : () async {
                              final aid = applicant['id'] ?? applicant['application_id'] ?? applicant['app_id'];
                              final appId = aid is int ? aid : int.tryParse(aid?.toString() ?? '') ?? 0;
                              if (appId == 0) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Invalid application id')));
                                return;
                              }
                              setState(() => loading = true);
                              try {
                                await ApiService.updateApplicationStatus(applicationId: appId, status: 'accepted');
                                Navigator.pop(ctx2);
                                ScaffoldMessenger.of(ctx2).showSnackBar(const SnackBar(content: Text('Application accepted')));
                                if (onUpdated != null) onUpdated();
                              } catch (e) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text('Failed: $e')));
                              } finally {
                                setState(() => loading = false);
                              }
                            },
                      child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });
    },
  );
}

Widget _buildProfileAvatar(Map<String, dynamic>? user) {
  // look for common image keys
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
    return const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 35));
  }

  String url = img;
  // if relative path, prefix with base url root
  try {
    if (!url.startsWith('http')) {
      // remove trailing /api from base url
      final baseRoot = ApiService.baseUrl.replaceAll('/api', '');
      url = baseRoot + (img.startsWith('/') ? img : '/$img');
    }
  } catch (_) {}

  return CircleAvatar(
    radius: 40,
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
        appBar: AppBar(
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
            tabs: const [
              Tab(text: 'Home'),
              Tab(text: 'Posted Jobs'),
              Tab(text: 'Profile'),
            ],
          ),
        ),

        drawer: _buildDrawer(context),

        body: TabBarView(
          controller: _tabController,
          children: const [RecruiterHomeTab(), PostedJobsTab(), ProfileTab()],
        ),

        // FAB only visible on "Posted Jobs" tab (index 1)
        floatingActionButton: _currentTabIndex == 1
            ? FloatingActionButton(
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
  late Future<List<Map<String, dynamic>>> _applicantsFuture;

  @override
  void initState() {
    super.initState();
    _applicantsFuture = ApiService.fetchApplicants();
  }

  Future<void> _refresh() async {
    setState(() {
      _applicantsFuture = ApiService.fetchApplicants();
    });
    await _applicantsFuture;
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
                future: ApiService.fetchCurrentUser(),
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
                                      Text(
                                        'Created: ${_formatDate(user['created_at'] ?? user['createdAt'] ?? user['created'] ?? user['registered_at'] ?? '')}',
                                      ),
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
                alignment: Alignment.centerLeft,
                child: Text(
                  'Job Applicants',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),

            // Applicants list
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
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
                          .toString().toUpperCase();
                      final appliedAt =
                          a['applied_at'] ?? a['created_at'] ?? '';
                      final dateStr = _formatDate(appliedAt);

                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showApplicantDetails(context, a, onUpdated: _refresh),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person)),
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
                                            ? Colors.orange[100]
                                            : status.toLowerCase() == 'rejected'
                                                ? Colors.red[100]
                                            : Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
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
  late Future<List<Map<String, dynamic>>> _postedJobsFuture;

  @override
  void initState() {
    super.initState();
    _postedJobsFuture = ApiService.fetchPostedJobs();
  }

  Future<void> _refresh() async {
    setState(() {
      _postedJobsFuture = ApiService.fetchPostedJobs();
    });
    await _postedJobsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('Your Posted Jobs', style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                    ),
                  ],
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
                child: ListTile(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$workingHours hrs/day'),
                        const Spacer(),
                        Icon(
                          Icons.payments,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$payment per hour',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$appsCount',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'applicants',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  onTap: () => _showApplicantsDialog(context, id, title),
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
    scaffold.showSnackBar(
      const SnackBar(content: Text('Loading applicants...')),
    );

    try {
      final all = await ApiService.fetchApplicants();
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showApplicantDetails(context, a, onUpdated: () => _refresh());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  _buildProfileAvatar(seeker),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Failed to load applicants: $e')),
      );
    }
  }
}

// ! MARK: Profile Tab
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Profile page', style: TextStyle(fontSize: 16)),
    );
  }
}

// ! MARK: Drawer
Drawer _buildDrawer(BuildContext context) {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Color.fromARGB(255, 111, 146, 175)),
          child: Text(
            'Quick Settings',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.home),
          title: const Text('Button 1'),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: const Icon(Icons.work),
          title: const Text('Button 2'),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Button 3'),
          onTap: () => Navigator.pop(context),
        ),
        const Divider(),
        // ! MARK: Logout
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(context); // close drawer

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Logging out...')));

            try {
              await ApiService.logout();
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Logout API failed: $e')));
            } finally {
              await clearToken();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInPage()),
                  (route) => false,
                );
              }
            }
          },
        ),
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
  String selectedDifficulty = 'easy';
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
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
                    DropdownButton<String>(
                      value: selectedDifficulty,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedDifficulty = val);
                        }
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    setState(() => isLoading = true);

                                    try {
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

                                      final res = await ApiService.createJob(
                                        title: title,
                                        description: desc,
                                        difficulty: selectedDifficulty,
                                        workingHours: hours,
                                        payment: payment,
                                      );

                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            res['message'] ??
                                                'Job created successfully!',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to create job: $e',
                                          ),
                                        ),
                                      );
                                    } finally {
                                      setState(() => isLoading = false);
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

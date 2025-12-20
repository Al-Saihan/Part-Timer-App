import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/job.dart';
import '../includes/auth.dart';
import 'sign_in.dart';

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

    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final m = months[dt.month - 1];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year} • ${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    return raw.toString();
  }
}

Widget _buildProfileAvatar(Map<String, dynamic>? user) {
  String? img;
  if (user != null) {
    img = user['avatar']?.toString() ?? user['profile_picture']?.toString() ?? user['photo']?.toString() ?? user['image']?.toString() ?? user['picture']?.toString();
  }

  if (img == null || img.isEmpty) {
    return const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 35));
  }

  String url = img;
  try {
    if (!url.startsWith('http')) {
      final baseRoot = ApiService.baseUrl.replaceAll('/api', '');
      url = baseRoot + (img.startsWith('/') ? img : '/$img');
    }
  } catch (_) {}

  return CircleAvatar(radius: 40, backgroundColor: Colors.grey[200], backgroundImage: NetworkImage(url), child: const SizedBox.shrink());
}

// ! MARK: Start
class HomeSeekerPage extends StatelessWidget {
  final String? email;
  const HomeSeekerPage({super.key, this.email});

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
          title: const Text('Seeker Dashboard'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Home'),
              Tab(text: 'Applied Jobs'),
              Tab(text: 'Profile'),
            ],
          ),
        ),
        drawer: _buildDrawer(context),
        body: const TabBarView(
          children: [HomeTab(), AppliedJobsTab(), ProfileTab()],
        ),
      ),
    );
  }
}

// ! MARK: Home Tab
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Job>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = ApiService.fetchJobs();
  }

  Future<void> _refresh() async {
    setState(() {
      _jobsFuture = ApiService.fetchJobs();
    });
    await _jobsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile (copied from recruiter dashboard)
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: Center(child: _buildProfileAvatar(null)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(),

          // ! MARK: Available
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available Jobs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          // ! MARK: Jobs List
          FutureBuilder<List<Job>>(
            future: _jobsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
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
                  child: Text('No jobs available'),
                );
              }

              // ! MARK: Jobs ListView
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      onTap: () => _showJobDetails(context, job, onApplied: _refresh),
                      title: Text(
                        job.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text('${job.workingHours} hrs/day'),
                            const Spacer(),
                            Icon(
                              Icons.payments,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${job.payment} Taka per hour',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }
}

// ! MARK: Applied Jobs
class AppliedJobsTab extends StatefulWidget {
  const AppliedJobsTab({super.key});

  @override
  State<AppliedJobsTab> createState() => _AppliedJobsTabState();
}

class _AppliedJobsTabState extends State<AppliedJobsTab> {
  late Future<List<Map<String, dynamic>>> _appliedFuture;

  @override
  void initState() {
    super.initState();
    _appliedFuture = ApiService.fetchAppliedJobs();
  }

  Future<void> _refresh() async {
    setState(() => _appliedFuture = ApiService.fetchAppliedJobs());
    await _appliedFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _appliedFuture,
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
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final apps = snapshot.data ?? [];
          if (apps.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('You have not applied to any jobs yet')),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final app = apps[index];
              final jobMap = app['job'] is Map ? Map<String, dynamic>.from(app['job']) : null;
              final title = jobMap != null ? (jobMap['title'] ?? 'Job') : (app['job_title'] ?? 'Job');
              final status = (app['status'] ?? app['STATUS'] ?? 'pending').toString();
              final appliedAt = app['created_at'] ?? app['applied_at'] ?? '';
              final dateStr = _formatDate(appliedAt);

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    // If we have job details, open job dialog by constructing a Job
                    if (jobMap != null && jobMap['id'] != null) {
                      final jobObj = Job.fromJson(jobMap);
                      _showJobDetails(context, jobObj, onApplied: _refresh, showApply: false);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job details unavailable')));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        const CircleAvatar(child: Icon(Icons.work)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              if (dateStr.isNotEmpty) Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: status.toLowerCase() == 'pending' ? Colors.orange[50] : (status.toLowerCase() == 'accepted' ? Colors.green[50] : Colors.red[50]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
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
    );
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
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () async {
            Navigator.pop(context); // close drawer

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logging out...')),
            );

            try {
              await ApiService.logout();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logout API failed: $e')),
              );
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

// ! MARK: Job Details
Future<void> _showJobDetails(BuildContext context, Job job, {VoidCallback? onApplied, bool showApply = true}) async {
  final scaffold = ScaffoldMessenger.of(context);
  scaffold.showSnackBar(const SnackBar(content: Text('Loading job details...')));

  Map<String, dynamic>? details;
  try {
    details = await ApiService.fetchJobDetails(jobId: job.id);
  } catch (_) {
    // fallback to minimal data when details endpoint not available
    details = null;
  }

  String createdStr = '';
  if (details != null) {
    createdStr = _formatDate(details['created_at'] ?? details['createdAt'] ?? details['posted_at'] ?? '');
  }

  final title = details != null ? (details['title'] ?? job.title) : job.title;
  final description = details != null ? (details['description'] ?? job.description) : job.description;
  final difficulty = details != null ? (details['difficulty'] ?? job.difficulty) : job.difficulty;
  final workingHours = details != null ? (details['working_hours']?.toString() ?? details['workingHours']?.toString() ?? job.workingHours.toString()) : job.workingHours.toString();
  final payment = details != null ? (details['payment']?.toString() ?? job.payment.toString()) : job.payment.toString();

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                              // Header: title (no recruiter profile shown)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  if (createdStr.isNotEmpty) Text(createdStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                const SizedBox(height: 12),

                // Description
                Text(description),
                const SizedBox(height: 12),

                // Info chips (wrap to avoid overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(difficulty.toString())),
                    Chip(label: Text('$workingHours hrs/day')),
                    Chip(label: Text('$payment per hour')),
                  ],
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    if (showApply) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            scaffold.showSnackBar(const SnackBar(content: Text('Applying...')));
                            try {
                              final res = await ApiService.applyJob(jobId: job.id);
                              final msg = (res['message'] ?? 'Applied successfully').toString();
                              scaffold.showSnackBar(SnackBar(content: Text(msg)));
                              if (onApplied != null) onApplied();
                            } catch (e) {
                              scaffold.showSnackBar(SnackBar(content: Text('Apply failed: $e')));
                            }
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Info row removed — replaced by chips in job details

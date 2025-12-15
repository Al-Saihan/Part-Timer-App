import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/job.dart';
import '../includes/auth.dart';
import 'sign_in.dart';

class HomePage extends StatelessWidget {
  final String? email;
  const HomePage({super.key, this.email});

  // ! MARK: Tabbed Scaffold
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
          title: const Text('Title Undecided'),
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

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ! MARK: Seeker Info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Expanded(
                  child: Placeholder(
                    fallbackHeight: 150,
                    child: Center(child: Text('User Profile Info')),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Placeholder(
                    fallbackHeight: 150,
                    child: Center(child: Text('Profile Picture')),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // ! MARK: Jobs List Header
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
            future: ApiService.fetchJobs(),
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

              // ! MARK: Jobs List 
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
                      onTap: () => _showJobDetails(context, job),
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


// ! MARK: AppliedJobs
class AppliedJobsTab extends StatelessWidget {
  const AppliedJobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Applied jobs will appear here',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}

// ! MARK: Profile
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
void _showJobDetails(BuildContext context, Job job) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(job.description),
              const SizedBox(height: 16),
              _infoRow(Icons.bar_chart, 'Difficulty', job.difficulty),
              _infoRow(
                Icons.schedule,
                'Working Hours',
                '${job.workingHours} hrs/day',
              ),
              _infoRow(
                Icons.payments,
                'Payment',
                '${job.payment} Taka per hour',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);

                        final scaffold = ScaffoldMessenger.of(context);
                        scaffold.showSnackBar(
                          const SnackBar(content: Text('Applying...')),
                        );

                        try {
                          final res = await ApiService.applyJob(jobId: job.id);
                          final msg = (res['message'] ?? 'Applied successfully').toString();
                          scaffold.showSnackBar(SnackBar(content: Text(msg)));
                        } catch (e) {
                          scaffold.showSnackBar(SnackBar(content: Text('Apply failed: $e')));
                        }
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ? MARK: Helper Wgt

Widget _infoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

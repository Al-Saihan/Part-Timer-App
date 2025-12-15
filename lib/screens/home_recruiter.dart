import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../includes/auth.dart';
import 'sign_in.dart';

// ! MARK: Start
class HomeRecruiterPage extends StatefulWidget {
  const HomeRecruiterPage({super.key});

  @override
  State<HomeRecruiterPage> createState() => _HomeRecruiterPageState();
}

class _HomeRecruiterPageState extends State<HomeRecruiterPage> with SingleTickerProviderStateMixin {
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
class RecruiterHomeTab extends StatelessWidget {
  const RecruiterHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ! MARK: User Profile
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

          // ! MARK: Job Applicants
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Center(
              child: Placeholder(
                fallbackHeight: 200,
                child: const Center(child: Text('Job Applicants (placeholder)')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ! MARK: Posted Tab
class PostedJobsTab extends StatelessWidget {
  const PostedJobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Center(
        child: Placeholder(
          fallbackHeight: 200,
          child: Center(child: Text('Your Posted Jobs (placeholder)')),
        ),
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
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Job',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
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
                                      final hours = int.tryParse(hoursCtrl.text.trim()) ?? 0;
                                      final payment = double.tryParse(paymentCtrl.text.trim()) ?? 0;

                                      if (title.isEmpty || desc.isEmpty || hours <= 0 || payment <= 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please fill all fields correctly')),
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
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res['message'] ?? 'Job created successfully!'),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to create job: $e')),
                                      );
                                    } finally {
                                      setState(() => isLoading = false);
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
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

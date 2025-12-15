import 'dart:ui';
import 'package:flutter/material.dart';
import 'sign_up.dart';
import 'home_seeker.dart';
import 'home_recruiter.dart';
import '../services/api_service.dart';
import '../includes/auth.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ! MARK: On-Submit
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // ? On successful login, navigate to HomePage
      if (!mounted) return;
      // decide where to go based on saved user_type
      final type = await getUserType();
      if (type == 'recruiter') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeRecruiterPage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeSeekerPage(email: _emailController.text.trim())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          // ? MARK: Sign-in
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: 8,
                  color: Colors.white.withAlpha(243),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'SIGN IN',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email, color: Colors.blue),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter email';
                              }
                              if (!v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock, color: Colors.blue),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter password';
                              }
                              if (v.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          // ! MARK: Actions x 2
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  // ?----------------- Navigate to SignUpPage -----------------?
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Create An Account',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Reset password flow not implemented',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Forget Password?',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


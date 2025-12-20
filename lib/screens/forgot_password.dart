import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'reset_password.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final res = await ApiService.forgotPassword(email: _emailCtrl.text.trim());
      scaffold.showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Email verified')));
      // navigate to reset page
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResetPasswordPage(email: _emailCtrl.text.trim())),
        );
      }
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter your email to reset password', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ChangeEmail extends StatefulWidget {
  final String currentEmail;

  const ChangeEmail({
    super.key,
    required this.currentEmail,
  });

  @override
  State<ChangeEmail> createState() => _ChangeEmailState();
}

class _ChangeEmailState extends State<ChangeEmail> {
  // step control
  int step = 1;

  bool showPassword = false;
  bool saving = false;

  final _pwFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _confirmEmailController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    super.dispose();
  }

  Future<void> _showSuccess() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 60,),
          ],
        ),
        content: const Text('Your email has been changed successfully.', textAlign: TextAlign.center,),
      ),
    );
  }

  InputDecoration _input(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFEAEAEA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: const BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: const Color(0x30FFFFFF),
                    ),
                    child: const Icon(Icons.email_outlined, color: Colors.white, size: 50),
                  ),
                  const SizedBox(width: 15),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Manage your email',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Back row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (step == 2) {
                        setState(() => step = 1);
                        return;
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(CupertinoIcons.arrow_left),
                  ),
                  Text(step == 1 ? 'Back' : 'Back to password'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Container(
                    width: w > 400 ? 370 : w * 0.92,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 5)),
                      ],
                    ),
                    child: step == 1 ? _passwordStep() : _emailStep(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordStep() {
    final w = MediaQuery.of(context).size.width;

    return Column(
      children: [
        const Text(
          'Confirm your password',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'For security, enter your password to continue.',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        Form(
          key: _pwFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: !showPassword,
                style: const TextStyle(fontSize: 12),
                decoration: _input(
                  'Enter your password',
                  suffix: IconButton(
                    onPressed: () => setState(() => showPassword = !showPassword),
                    icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off, size: 18),
                  ),
                ),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Password is required';
                  if (v.length < 8) return 'Minimum 8 characters';
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: w * 0.6,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF004280),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (_pwFormKey.currentState!.validate()) {
                // In real app: reauthenticate here
                setState(() => step = 2);
              }
            },
            child: const Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _emailStep() {
    final w = MediaQuery.of(context).size.width;

    return Column(
      children: [
        const Text(
          'Enter your new email',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Make sure you can access this email.',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        Form(
          key: _emailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Email', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _newEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 12),
                decoration: _input('Enter new email'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Email is required';
                  final emailOk = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
                  if (!emailOk) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              const Text('Confirm Email', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 12),
                decoration: _input('Re-enter new email'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty && !_newEmailController.text.trim().isEmpty) return 'Confirm your email';
                  if (v != _newEmailController.text.trim()) return 'Emails do not match';
                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: w * 0.75,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF004280),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: saving
                ? null
                : () async {
              if (!_emailFormKey.currentState!.validate()) return;

              setState(() => saving = true);

              // simulate update call
              await Future.delayed(const Duration(milliseconds: 700));

              if (!mounted) return;
              setState(() => saving = false);

              await _showSuccess();
              if (!mounted) return;
              Navigator.pop(context, _newEmailController.text.trim());
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  saving ? 'Saving...' : 'Update Email',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

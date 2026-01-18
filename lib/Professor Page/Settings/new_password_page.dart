import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewPasswordPage extends StatefulWidget {
  final String userId; // auth.users.id (student/prof/admin)
  final String otp;
  final String role; // "student" | "professor" | "admin" (optional)

  const NewPasswordPage({
    super.key,
    required this.userId,
    required this.otp,
    required this.role,
  });

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();

  bool loading = false;
  String error = "";

  @override
  void dispose() {
    _newPass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      error = "";
      loading = true;
    });

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'prof-verify-otp-and-change-password',
        body: {
          'user_id': widget.userId,
          'otp': widget.otp,
          'new_password': _newPass.text.trim(),
        },
      );


      final data = res.data;
      if (data == null || data['success'] != true) {
        setState(() {
          error = "${data?['step'] ?? 'error'}: ${data?['message'] ?? 'Failed'}";
        });
        return;
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
          content: const Text(
            "Password changed successfully.",
            textAlign: TextAlign.center,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // back
    } catch (e) {
      setState(() => error = "Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set New Password")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),

              TextFormField(
                controller: _newPass,
                obscureText: true,
                decoration: const InputDecoration(labelText: "New Password"),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (v.length < 8) return "Min 8 characters";
                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmPass,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Confirm Password"),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Required";
                  if (v != _newPass.text) return "Passwords do not match";
                  return null;
                },
              ),

              const SizedBox(height: 18),

              ElevatedButton(
                onPressed: loading
                    ? null
                    : () {
                  if (_formKey.currentState!.validate()) _submit();
                },
                child: loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Change Password"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

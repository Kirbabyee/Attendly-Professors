import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final supabase = Supabase.instance.client;

  bool loading = false;

  // server-side field errors
  String? _emailServerError;

  String? emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';

    return null;
  }

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _clearServerErrors() {
    if (_emailServerError != null) {
      setState(() {
        _emailServerError = null;
      });
    }
  }

  Future<void> _checkEmailAndProceed() async {
    // clear previous server errors
    setState(() {
      _emailServerError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    setState(() => loading = true);
    try {
      final res = await supabase.functions.invoke(
        'prof-check-email',
        body: {
          'email': email,
        },
      );

      if (res.status != 200) {
        final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null) ??
            'Request failed';
        throw Exception(msg);
      }

      final data = res.data as Map? ?? {};
      final exists = data['exists'] == true;

      if (!exists) {
        // ❗ no match found → show errors on both fields
        setState(() {
          _emailServerError = 'Email not found';
        });
        return;
      }

      // proceed to new password screen
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/new_password',
        arguments: {
          'email': email,
        },
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');

      // optional: map common server messages to fields
      if (msg.toLowerCase().contains('email')) {
        setState(() => _emailServerError = msg);
      } else {
        // fallback snackbar
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isKeyboard = MediaQuery.of(context).viewInsets.bottom != 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFEAF5FB),
      body: Stack(
        children: [
          Stack(
            children: [
              Visibility(
                visible: (!isKeyboard),
                child: Positioned(
                  top: screenHeight > 640 ? 0 : -50,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/Ellipse 2.png',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: screenHeight > 640 ? 0 : -50,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/Ellipse 1.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          Center(
            child: Column(
              children: [
                SizedBox(height: !isKeyboard ? screenHeight * .24 : screenHeight * .16),
                Image.asset(width: screenWidth * .9, 'assets/logo.png'),
                SizedBox(height: screenHeight * .013),
                Text(
                  'Forgot Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight * .017),
                ),
                SizedBox(height: screenHeight * .048),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email', style: TextStyle(fontSize: screenHeight * .017)),
                      SizedBox(height: screenHeight * .008),
                      SizedBox(
                        height: screenHeight * .068,
                        width: screenWidth * .83,
                        child: TextFormField(
                          controller: _emailController,
                          style: TextStyle(fontSize: screenHeight * .017),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => _clearServerErrors(),
                          decoration: InputDecoration(
                            errorText: _emailServerError, // server error here
                            errorMaxLines: 2,
                            errorStyle: TextStyle(fontSize: screenHeight * .013, height: 1.2),
                            hintText: 'Enter Email',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: screenHeight * .017),
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.grey, size: screenHeight * .023),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: screenHeight * .013,
                              vertical: screenHeight * .013,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                          ),
                          validator: emailValidator,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * .073),

                if (!isKeyboard)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(screenHeight * .18, screenHeight * .043),
                      backgroundColor: const Color(0xFF004280),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.circular(6),
                      ),
                    ),
                    onPressed: loading ? null : _checkEmailAndProceed,
                    child: loading
                        ? SizedBox(
                      width: screenHeight * .02,
                      height: screenHeight * .02,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(
                      'Next',
                      style: TextStyle(color: Colors.white, fontSize: screenHeight * .017),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

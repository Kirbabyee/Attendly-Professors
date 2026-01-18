import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mainshell.dart';
import 'new_password_page.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  @override
  void initState() {
    super.initState();
    _loadProfessor();
  }

  String? _profEmail;
  String? _profName;
  bool _loadingProf = true;
  String _errorTop = "";

  Future<void> _loadProfessor() async {
    setState(() {
      _loadingProf = true;
      _errorTop = "";
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorTop = "Not logged in.";
          _loadingProf = false;
        });
        return;
      }

      final row = await Supabase.instance.client
          .from('professors')
          .select('email, professor_name')
          .eq('id', user.id)
          .single();

      setState(() {
        _profEmail = (row['email'] as String?)?.trim().toLowerCase();
        _profName = (row['professor_name'] as String?)?.trim();
        _loadingProf = false;
      });
    } catch (e) {
      setState(() {
        _errorTop = "Failed to load professor: $e";
        _loadingProf = false;
      });
    }
  }

  final TextEditingController _otpController = TextEditingController();

  Future<String?> _showOtpModal() async {
    _otpController.clear();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool localLoading = false;
        String? localError;

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Text(
                "Enter OTP",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "We sent a 6-digit OTP to your email.\nPlease enter it below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "000000",
                      filled: true,
                      fillColor: const Color(0x50D9D9D9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: localLoading ? null : () => Navigator.pop(ctx, null),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF043B6F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: localLoading
                            ? null
                            : () async {
                          final otp = _otpController.text.trim();

                          if (otp.length != 6) {
                            setStateDialog(() {
                              localError = "OTP must be 6 digits.";
                            });
                            return;
                          }

                          // ✅ if you want to show loading inside the dialog:
                          setStateDialog(() {
                            localLoading = true;
                            localError = null;
                          });

                          // TODO: call verify otp edge function here later
                          await Future.delayed(const Duration(milliseconds: 400));

                          setStateDialog(() => localLoading = false);

                          Navigator.pop(ctx, otp);
                        },
                        child: localLoading
                            ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Text("Verify", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: localLoading
                        ? null
                        : () async {
                      // TODO: call resend OTP edge function later
                      setStateDialog(() {
                        localError = "OTP resent (demo).";
                      });
                    },
                    child: const Text("Resend OTP"),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _showLoading() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Future<void> _handlePasswordChange() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _errorTop = "Not logged in.");
      return;
    }

    final currentPass = _currentPassword.text.trim();

    await _showLoading();
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'prof-send-otp',
        body: {
          'professor_id': user.id,
          'current_password': currentPass,
        },
      );

      if (Navigator.canPop(context)) Navigator.pop(context);

      final data = res.data;
      if (data == null || data['success'] != true) {
        setState(() {
          _errorTop = "${data?['step'] ?? 'error'}: ${data?['message'] ?? 'Failed'}";
        });
        return;
      }

      final otp = await _showOtpModal();
      if (!mounted) return;
      if (otp == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordPage(
            userId: user.id,
            otp: otp,
            role: "professor",
          ),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      setState(() => _errorTop = "Failed to send OTP: $e");
    }
  }


  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool showPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;

  @override
  void dispose() {
    _newPassword.dispose();
    _currentPassword.dispose();
    _confirmPassword.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(
                  top: Radius.zero,
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadiusGeometry.circular(7),
                      color: Color(0x30FFFFFF),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  SizedBox(width: 15),
                  Container(
                    height: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: screenHeight > 700 ? 10 : 5),
                        Text(
                          'Manage your preferences',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20,),
            Container(
              child: Row(
                children: [
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(CupertinoIcons.arrow_left)
                  ),
                  Text('Back')
                ],
              ),
            ),
            SizedBox(height: 20,),
            Container(
              width: 350,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                  borderRadius: BorderRadiusGeometry.circular(8),
                  color: Colors.white
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_loadingProf)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: CircularProgressIndicator(),
                      )
                    else if (_errorTop.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(/*_errorTop if debugging happens uncomment this error message*/ 'Password Incorrect', style: const TextStyle(color: Colors.red)),
                      )
                    else SizedBox(),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.lock,
                          size: 20,
                        ),
                        SizedBox(width: 10,),
                        Text(
                          'Change Password',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20,),
                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current password'),
                          SizedBox(height: 5,),
                          SizedBox(
                            width: 300,
                            height: 58,
                            child: TextFormField(
                              controller: _currentPassword,
                              obscureText: showPassword ? false : true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Current password is required';
                                }
                                return null;
                              },
                              style: TextStyle(
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                suffixIcon: IconButton(onPressed: () {setState(() {showPassword = !showPassword;});}, icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off)),
                                  errorMaxLines: 1,
                                  errorStyle: TextStyle(
                                    fontSize: 10,
                                  ),
                                  contentPadding: EdgeInsets.all(10), // Padding inside the inputbar
                                  filled: true,
                                  fillColor: Color(0x50D9D9D9),
                                  hintText: 'Enter current password',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.black,
                                        width: .5
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.red,
                                        width: .5
                                    ),
                                  )
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 10,),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF043B6F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(8)
                        )
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          // All inputs valid
                          _handlePasswordChange();
                        }
                      },
                      child: const Text(
                        'Next',
                        style: TextStyle(
                            color: Colors.white
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

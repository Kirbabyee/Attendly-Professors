import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mainshell.dart';
import 'new_password_page.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  int _cooldown = 0;
  Timer? _cooldownTimer;

  static const _cooldownKey = 'prof_forgot_cooldown_until_ms';

  Future<void> _restoreCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_cooldownKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final remaining = ((untilMs - nowMs) / 1000).ceil();
    if (remaining > 0) {
      _runCooldownTimer(remaining);
    } else {
      // expired -> cleanup
      await prefs.remove(_cooldownKey);
      if (mounted) setState(() => _cooldown = 0);
    }
  }

  Future<void> _startCooldown([int seconds = 60]) async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    await prefs.setInt(_cooldownKey, untilMs);

    _runCooldownTimer(seconds);
  }

  void _runCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cooldownKey);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadProfessor();
    _restoreCooldown();
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

  Future<String?> _showOtpModal({required String professorId}) async {
    _otpController.clear();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool localLoading = false;
        String? localError;

        int secondsLeft = 60;          // 👈 countdown start
        Timer? timer;

        void startTimer(void Function(void Function()) setStateDialog) {
          timer?.cancel();
          secondsLeft = 60;

          timer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (secondsLeft <= 1) {
              t.cancel();
              setStateDialog(() => secondsLeft = 0);
            } else {
              setStateDialog(() => secondsLeft -= 1);
            }
          });
        }

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            // ✅ start countdown once when dialog opens
            timer ??= Timer(const Duration(milliseconds: 1), () {
              startTimer(setStateDialog);
            });

            Future<void> resendOtp() async {
              setStateDialog(() {
                localLoading = true;
                localError = null;
              });

              try {
                final session = Supabase.instance.client.auth.currentSession;
                if (session == null) {
                  setStateDialog(() {
                    localError = "Session expired. Please login again.";
                    localLoading = false;
                  });
                  return;
                }

                final res = await Supabase.instance.client.functions.invoke(
                  'prof-resend-otp',
                  body: {'professor_id': professorId},
                  headers: {'Authorization': 'Bearer ${session.accessToken}'},
                );

                final data = res.data;
                if (data == null || data['success'] != true) {
                  setStateDialog(() {
                    localError =
                    "${data?['step'] ?? 'error'}: ${data?['message'] ?? 'Failed'}";
                    localLoading = false;
                  });
                  return;
                }

                // ✅ restart cooldown after successful resend
                startTimer(setStateDialog);

                setStateDialog(() {
                  localError = "OTP sent again. Please check your email.";
                  localLoading = false;
                });
              } catch (e) {
                setStateDialog(() {
                  localError = "Resend failed: $e";
                  localLoading = false;
                });
              }
            }

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
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFDDDDDD)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: localLoading
                            ? null
                            : () {
                          timer?.cancel();
                          Navigator.pop(ctx, null);
                        },
                        child: const Text("Cancel", style: TextStyle(color: Colors.black)),
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
                            setStateDialog(() => localError = "OTP must be 6 digits.");
                            return;
                          }

                          // ✅ close + return OTP to caller
                          timer?.cancel();
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

                // ✅ RESEND with COUNTDOWN
                Center(
                  child: TextButton(
                    onPressed: (localLoading || secondsLeft > 0) ? null : resendOtp,
                    child: Text(
                      secondsLeft > 0 ? "Resend OTP (${secondsLeft}s)" : "Resend OTP",
                      style: TextStyle(
                        color: (secondsLeft > 0) ? Colors.grey : Colors.black,
                      ),
                    ),
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

      final otp = await _showOtpModal(professorId: user.id);
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
    _cooldownTimer?.cancel();
    _newPassword.dispose();
    _currentPassword.dispose();
    _confirmPassword.dispose();
    _otpController.dispose();
    super.dispose();
  }
  String? _passwordError;
  @override
  Widget build(BuildContext context) {
    if(_errorTop.isNotEmpty) _passwordError = 'Incorrect Password';
    final screenHeight = MediaQuery.of(context).size.height;
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
                          Text('$_errorTop'),
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
                                  errorText: _passwordError,
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
                                  ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.red,
                                      width: .5
                                  ),
                                ),
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
                      onPressed: _cooldown > 0 ? null : () {
                        if (_formKey.currentState!.validate()) {
                          // All inputs valid
                          _handlePasswordChange();
                          _startCooldown(60);
                        }
                      },
                      child: Text(
                        _cooldown > 0
                            ? 'Please wait (${_cooldown}s)'
                            : 'Next',
                        style: const TextStyle(color: Colors.white),
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

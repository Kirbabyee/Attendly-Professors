import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'new_password.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  int _cooldown = 0;
  Timer? _cooldownTimer;

  static const _cooldownKey = 'prof_forgot_cooldown_until_ms';

  @override
  void initState() {
    super.initState();
    _restoreCooldown();
  }

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
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool loading = false;
  String error = "";

  final TextEditingController _otpController = TextEditingController();

  Future<String?> _showOtpModal({required String email}) async {
    _otpController.clear();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool localLoading = false;
        String? localError;

        int secondsLeft = 60;
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
            // start countdown once
            timer ??= Timer(const Duration(milliseconds: 1), () {
              startTimer(setStateDialog);
            });

            Future<void> resendOtp() async {
              setStateDialog(() {
                localLoading = true;
                localError = null;
              });

              try {
                final resendRes = await Supabase.instance.client.functions.invoke(
                  'prof-forgot-send-otp',
                  body: {'email': email},
                );

                final resendData = resendRes.data;
                if (resendData == null || resendData['success'] != true) {
                  setStateDialog(() {
                    localError =
                    "${resendData?['step'] ?? 'error'}: ${resendData?['message'] ?? 'Failed'}";
                    localLoading = false;
                  });
                  return;
                }

                // restart cooldown after resend
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
    ).then((v) {
      // just to be safe, cancel timer if dialog closes in any way
      return v;
    });
  }


  String? emailValidator(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';

    return null; // ✅ valid
  }


  bool showPassword = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  String? _emailError;

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) _emailError =  'Invalid email';
    final screenHeight = MediaQuery.of(context).size.width;
    final isKeyboard = MediaQuery.of(context).viewInsets.bottom != 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(0xFFEAF5FB),
      body: Stack(
        children: [
          Stack(
            children: [
              Visibility(
                visible: (!isKeyboard ? true : false), // bool
                child: Positioned(
                  top: screenHeight > 370 ? 0 : -50,
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
                top: screenHeight > 370 ? 0 : -50,
                left: 0,
                right: 0,
                child: Image.asset(
                  'assets/Ellipse 1.png', // Dark Blue Wave
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          Container(
            child: Center(
              child: Column(
                children: [
                  SizedBox(height: !isKeyboard && screenHeight > 370 ? 210 : 130,),
                  Image.asset(
                    width: screenHeight > 370 ? 400 : 300,
                    'assets/logo.png'
                  ), // Logo
                  SizedBox(height: 10,),
                  Container(
                    child: Text(
                      'Forgot Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight > 370 ? 45 : 30,),
                  // Input Boxes
                  Form( // Put to form to add validations
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student No.
                        Container(
                          child: Text(
                            'Email',
                            style: TextStyle(
                              fontSize: screenHeight > 370 ? 14 : 12
                            ),
                          ),
                        ),
                        SizedBox(height: 5,),
                        SizedBox(
                          height: screenHeight > 370 ? 55 : 48,
                          width: 300,
                          child: TextFormField( // Input box
                            controller: _emailController,
                            style: TextStyle(fontSize: 14),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorText: _emailError,
                              errorStyle: TextStyle(
                                fontSize: 10,
                                height: 1,
                              ),
                              hintText: 'Enter Email', // Placeholder
                              hintStyle: TextStyle(
                                color: Colors.grey, // Change placeholder color
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined, // Add icon to the placeholder
                                color: Colors.grey, // Change the color of the icon
                              ),
                              contentPadding: const EdgeInsets.symmetric( // Add padding
                                horizontal: 10,
                                vertical: 10,
                              ),
                              // Add border to the input box
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.grey
                                  )
                              ),
                              focusedBorder: OutlineInputBorder(  // Change color of the border when clicked
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.black
                                  )
                              ),
                              errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Colors.red
                                  )
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Colors.red
                                ),
                              ),
                            ),
                            validator: emailValidator,
                          ),
                        ),
                        SizedBox(height: screenHeight > 370 ? 15 : 10),
                      ],
                    ),
                  ),
                  SizedBox(height: 70,),
                  !isKeyboard ? Container(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(150, 40),
                        backgroundColor: Color(0xFF004280),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(6)
                        )
                      ),
                        onPressed: (loading || _cooldown > 0)
                            ? null
                            : () async {
                          setState(() => error = "");
                          if (!_formKey.currentState!.validate()) return;

                          final email = _emailController.text.trim().toLowerCase();

                          setState(() => loading = true);
                          try {
                            // 1) send otp
                            final sendRes = await Supabase.instance.client.functions.invoke(
                              'prof-forgot-send-otp',
                              body: {'email': email},
                            );

                            final sendData = sendRes.data;
                            if (sendData == null || sendData['success'] != true) {
                              setState(() => error = "${sendData?['step'] ?? 'error'}: ${sendData?['message'] ?? 'Failed'}");
                              return;
                            }

                            await _startCooldown(60);

                            // 2) show otp modal
                            final otp = await _showOtpModal(email: email);
                            if (!mounted) return;
                            if (otp == null) return;

                            // 3) verify otp -> get user_id
                            final verRes = await Supabase.instance.client.functions.invoke(
                              'prof-forgot-verify-otp',
                              body: {'email': email, 'otp': otp},
                            );

                            final verData = verRes.data;
                            if (verData == null || verData['success'] != true) {
                              setState(() => error = "${verData?['step'] ?? 'error'}: ${verData?['message'] ?? 'Invalid OTP'}");
                              return;
                            }

                            final userId = (verData['user_id'] ?? "").toString().trim();
                            if (userId.isEmpty) {
                              setState(() => error = "Missing user_id from server.");
                              return;
                            }

                            // 4) go to new password page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewPassword(
                                  userId: userId,
                                  otp: otp,
                                ),
                              ),
                            );
                          } catch (e) {
                            setState(() => error = "Error: $e");
                          } finally {
                            if (mounted) setState(() => loading = false);
                          }
                        },

                        child: Text(
                        _cooldown > 0
                            ? 'Email Me (${_cooldown}s)'
                            : 'Email Me',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ) : Container(),
                ],
              ),
            ),
          )
        ],
      )
    );
  }
}

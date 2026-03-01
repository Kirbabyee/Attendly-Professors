import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:professor/Professor%20Page/professor_session.dart';
import 'package:professor/Professor%20Page/two_fa_verification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'Notification/push_token_service.dart';
import 'mainshell.dart';
import 'maintenance.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _locked = false;
  int _lockSeconds = 0;
  Timer? _lockTimer;

  void _startLock(int seconds) {
    _lockTimer?.cancel();
    setState(() {
      _locked = true;
      _lockSeconds = seconds;
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_lockSeconds <= 1) {
        t.cancel();
        setState(() {
          _locked = false;
          _lockSeconds = 0;
        });
      } else {
        setState(() => _lockSeconds -= 1);
      }
    });
  }

  void _showLockedDialog(int seconds) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: const [
              Icon(Icons.lock_clock_outlined, color: Colors.red),
              SizedBox(width: 10),
              Text('Login Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Too many failed attempts. Please wait for $seconds seconds before trying again.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(color: Color(0xFF004280), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  String? emailValidator(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) return 'Email is required';

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email';

    return null; // valid
  }


  bool showPassword = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _loginError;

  @override
  Widget build(BuildContext context) {
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
                      'Log in to your Account',
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
                            onChanged: (_) {
                              if (_loginError != null) {
                                setState(() => _loginError = null);
                              }
                            },
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorText: _loginError,
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
                        // Password
                        Container(child: Text(
                          'Password',
                          style: TextStyle(
                              fontSize: screenHeight > 370 ? 14 : 12
                          ),
                        ),),
                        SizedBox(height: 5,),
                        SizedBox(
                          height: screenHeight > 370 ? 55 : 48,
                          width: 300,
                          child: TextFormField( // Input box
                            controller: _passwordController,
                            style: TextStyle(fontSize: 14),
                            obscureText: (showPassword ? true : false),
                            decoration: InputDecoration(
                              errorMaxLines: 1,
                              errorStyle: TextStyle(
                                fontSize: 10,
                                height: 1,
                              ),
                              hintText: 'Enter Password', // Placeholder
                              hintStyle: TextStyle(
                                color: Colors.grey, // Change placeholder color
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline, // Add icon to the placeholder
                                color: Colors.grey, // Change the color of the icon
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    showPassword = !showPassword;
                                  });
                                },
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
                            validator: (value) {
                              final v = value ?? '';
                              if (v.isEmpty) return 'Password is required';
                              if (v.length <= 7) return 'Minimum 8 characters';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () {
                                Navigator.pushNamed(context, '/forgot_password');
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 70,),
                  !isKeyboard ? Container(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(150, 40),
                        backgroundColor: _locked ? Colors.grey : Color(0xFF004280),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(6)
                        )
                      ),
                        onPressed: () async {
                          if (_locked) {
                            _showLockedDialog(_lockSeconds);
                            return;
                          }

                          if (!_formKey.currentState!.validate()) return;

                          setState(() {
                            _loginError = null;
                          });

                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) {
                              return Dialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Signing in...'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                          try {
                            final email = _emailController.text.trim().toLowerCase();
                            final password = _passwordController.text;

                            final res = await supabase.auth.signInWithPassword(
                              email: email,
                              password: password,
                            );

                            final uid = res.user?.id;
                            if (uid == null) {
                              throw Exception("User has no data");
                            }

                            final token = await FirebaseMessaging.instance.getToken();
                            print('FCM token: $token');

                            // To check if the account is for professor
                            final profRow = await supabase
                                .from('professors')
                                .select('id, email, terms_conditions, two_fa_enabled, push_enabled, status, archived')
                                .eq('id', uid)
                                .maybeSingle();

                            if (profRow == null) {
                              await supabase.auth.signOut();
                              if (!mounted) return;
                              Navigator.pop(context); // close loading

                              setState(() {
                                _loginError = 'Invalid email or password';
                              });
                              _formKey.currentState!.validate();
                              return;
                            }

                            // archived: behave like “does not exist”
                            final isArchived = (profRow['archived'] == true);
                            if (isArchived) {
                              await supabase.auth.signOut();
                              if (!mounted) return;
                              Navigator.pop(context); // close loading

                              setState(() {
                                _loginError = 'Invalid email or password'; // same as wrong login
                              });
                              _formKey.currentState!.validate();
                              return;
                            }

                            // inactive: show your custom message
                            final status = (profRow['status'] ?? '').toString().trim().toLowerCase();
                            if (status == 'inactive') {
                              await supabase.auth.signOut();
                              if (!mounted) return;
                              Navigator.pop(context); // close loading

                              setState(() {
                                _loginError =
                                'This account has been deactivated.';
                              });
                              _formKey.currentState!.validate();
                              return;
                            }

                            // reset attempts on successful login
                            try {
                              await supabase.functions.invoke(
                                'prof-login-reset',
                                body: {'user_id': uid},
                              );
                            } catch (_) {
                              // ignore (login should still proceed)
                            }

                            ProfessorSession.clear();
                            await ProfessorSession.get(force: true);

                            final rawTerms = profRow['terms_conditions'];
                            final terms = (rawTerms is num) ? rawTerms.toInt() : int.tryParse('$rawTerms') ?? 0;

                            final twoFA = (profRow['two_fa_enabled'] == true);
                            final emailReal = (profRow['email'] ?? '').toString().trim();

                            // fallback kung sakaling walang email sa table
                            final emailToUse = emailReal.isNotEmpty ? emailReal : email;

                            // 2FA flow
                            if (twoFA) {
                              // 1) send OTP using email
                              try {
                                await supabase.functions.invoke(
                                  'send-2fa-otp',
                                  body: {'email': emailToUse},
                                );
                              } catch (_) {
                                // ok lang, user can resend inside modal
                              }

                              if (!mounted) return;
                              Navigator.pop(context); // close loading before opening 2FA modal

                              // 2) open OTP modal
                              final verified = await TwoFAVerificationPage.open(
                                context,
                                email: emailToUse,
                                resendSeconds: 60,
                                onResend: () async {
                                  await supabase.functions.invoke(
                                    'send-2fa-otp',
                                    body: {'email': emailToUse},
                                  );
                                },
                                onVerify: (otp) async {
                                  final resp = await supabase.functions.invoke(
                                    'verify-2fa-otp',
                                    body: {'email': emailToUse, 'otp': otp},
                                  );

                                  final data = Map<String, dynamic>.from(resp.data ?? {});
                                  return data['verified'] == true; // ✅
                                },
                              );

                              if (!mounted) return;

                              // cancel / failed
                              if (verified != true) {
                                await supabase.auth.signOut();
                                ProfessorSession.clear();
                                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                                return;
                              }
                              
                              // Re-open loading if passed 2FA but still need to check terms/maintenance
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );
                            }

                            // terms after 2FA
                            if (terms != 1) {
                              if (mounted) Navigator.pop(context); // close loading
                              Navigator.of(context).pushNamedAndRemoveUntil('/terms_conditions', (r) => false);
                              return;
                            }

                            // NOW fully authenticated + passed 2FA + accepted terms
                            final pushEnabled = (profRow['push_enabled'] == true);
                            final svc = PushTokenService(supabase);

                            if (pushEnabled) {
                              await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
                              await svc.replaceTokenForUser(professorId: uid); // delete old then add new
                            } else {
                              await svc.removeAllForUser(professorId: uid);    // cleanup tokens
                            }

                            try {
                              final maintenanceRow = await supabase
                                  .from('system_settings')
                                  .select('is_active')
                                  .eq('id', 'maintenance_mode')
                                  .maybeSingle();

                              if (maintenanceRow != null && maintenanceRow['is_active'] == true) {
                                if (mounted) Navigator.pop(context); // close loading
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const MaintenanceGuard()),
                                      (route) => false,
                                );
                                return;
                              }
                            } catch (e) {
                              debugPrint("Maintenance check error: $e");
                            }

                            if (mounted) Navigator.pop(context); // Final close of loading
                            Navigator.of(context).pushNamedAndRemoveUntil('/mainshell', (r) => false);
                            return;
                          } on AuthException catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context); // close loading

                            setState(() {
                              _loginError = 'Invalid email or password';
                            });

                            try {
                              final email = _emailController.text.trim().toLowerCase();

                              final resp = await supabase.functions.invoke(
                                'prof-login-guard',
                                body: {'email': email},
                              );

                              final data = Map<String, dynamic>.from(resp.data ?? {});
                              final locked = data['locked'] == true;
                              final lockSeconds = (data['lock_seconds'] as num?)?.toInt() ?? 0;

                              if (locked && lockSeconds > 0) {
                                _startLock(lockSeconds);
                                if (!mounted) return;
                                _showLockedDialog(lockSeconds);
                              }
                            } catch (_) {
                              // ignore (anti-enumeration safe)
                            }

                            // force redraw + show red text immediately
                            _formKey.currentState!.validate();
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context); // close loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Login failed. $e')),
                            );
                          }
                        },
                      child: Text(
                        _locked ? 'Locked ($_lockSeconds s)' : 'Sign In',
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

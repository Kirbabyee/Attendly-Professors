import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';

class NewPassword extends StatefulWidget {
  const NewPassword({super.key});

  @override
  State<NewPassword> createState() => _NewPasswordState();
}

class _NewPasswordState extends State<NewPassword> {
  final supabase = Supabase.instance.client;

  bool showPassword = true;
  bool saving = false;

  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // server error for OTP dialog
  String? _otpError;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ Strong password (same as earlier)
  String? validateStrongPassword(String? value) {
    final pw = (value ?? '').trim();
    if (pw.isEmpty) return 'Password is required';
    if (pw.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(pw)) return 'Must contain at least 1 uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(pw)) return 'Must contain at least 1 lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(pw)) return 'Must contain at least 1 number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]').hasMatch(pw)) {
      return 'Must contain at least 1 special character';
    }
    return null;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showSuccess() async {
    final screenHeight = MediaQuery.of(context).size.height;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Icon(Icons.check_circle_outline, color: Colors.green, size: screenHeight * .053),
        content: Text(
          'Your password has been changed successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: screenHeight * .017),
        ),
      ),
    );
  }

  // ============================
  // EDGE: send OTP (forgot)
  // ============================
  Future<void> _sendOtp({
    required String email,
  }) async {
    final res = await supabase.functions.invoke(
      'prof-forgot-otp-send',
      body: {
        'email': email,
      },
    );

    debugPrint("OTP SEND status: ${res.status}");
    debugPrint("OTP SEND data: ${res.data}");

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null) ??
          'Failed to send OTP';
      throw Exception(msg);
    }
  }

  // ============================
  // EDGE: verify OTP + reset pw
  // ============================
  Future<void> _verifyOtpAndReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final res = await supabase.functions.invoke(
      'prof-forgot-otp-verify',
      body: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      },
    );

    debugPrint("OTP VERIFY status: ${res.status}");
    debugPrint("OTP VERIFY data: ${res.data}");

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null) ??
          'OTP verification failed';
      throw Exception(msg);
    }
  }

  // ============================
  // OTP Dialog
  // ============================
  Future<bool> _showOtpModal({
    required String email, // ✅ add
    required Future<void> Function() onResend,
    required Future<void> Function(String otp) onVerify,
    int cooldownSeconds = 60,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpDialog(
        email: email, // ✅ pass
        cooldownSeconds: cooldownSeconds,
        onResend: onResend,
        onVerify: (otp) async {
          setState(() => _otpError = null);
          await onVerify(otp);
        },
        onError: (msg) {
          setState(() => _otpError = msg);
        },
        getError: () => _otpError,
      ),
    );
    return ok == true;
  }


  Future<void> _handleResetFlow() async {
    // get args from previous screen (ForgotPassword)
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final email = (args['email'] ?? '').toString().trim().toLowerCase();

    if (email.isEmpty) {
      _toast("Missing email. Please go back and try again.");
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final newPw = _newPasswordController.text.trim();

    setState(() => saving = true);
    try {
      // 1) send OTP
      await _sendOtp(email: email);

      if (!mounted) return;

      // 2) open OTP modal + verify
      final verified = await _showOtpModal(
        email: email, // ✅ add
        cooldownSeconds: 60,
        onResend: () => _sendOtp(email: email),
        onVerify: (otp) => _verifyOtpAndReset(
          email: email,
          otp: otp,
          newPassword: newPw,
        ),
      );


      if (!mounted) return;
      if (!verified) return;

      // 3) success -> go login
      await _showSuccess();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Login()),
      );
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
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
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight * .017),
                ),
                SizedBox(height: screenHeight * .048),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Password', style: TextStyle(fontSize: screenHeight * .017)),
                      SizedBox(height: screenHeight * .008),
                      SizedBox(
                        height: screenHeight * .065,
                        width: screenWidth * .83,
                        child: TextFormField(
                          obscureText: showPassword,
                          controller: _newPasswordController,
                          style: TextStyle(fontSize: screenHeight * .017),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            errorMaxLines: 2,
                            errorStyle: TextStyle(fontSize: screenHeight * .013, height: 1.2),
                            hintText: 'Enter new password',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: screenHeight * .017),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey, size: screenHeight * .023),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => showPassword = !showPassword),
                              icon: Icon(!showPassword ? Icons.visibility : Icons.visibility_off, size: screenHeight * .023),
                            ),
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
                          validator: validateStrongPassword,
                        ),
                      ),

                      SizedBox(height: screenHeight * .018),

                      Text('Confirm Password', style: TextStyle(fontSize: screenHeight * .017)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: screenHeight * .065,
                        width: screenWidth * .83,
                        child: TextFormField(
                          obscureText: showPassword,
                          controller: _confirmPasswordController,
                          style: TextStyle(fontSize: screenHeight * .017),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            errorMaxLines: 2,
                            errorStyle: TextStyle(fontSize: screenHeight * .013, height: 1.2),
                            hintText: 'Confirm your password',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: screenHeight * .017),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey, size: screenHeight * .023),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => showPassword = !showPassword),
                              icon: Icon(!showPassword ? Icons.visibility : Icons.visibility_off, size: screenHeight * .023),
                            ),
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
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) return 'Confirm password is required';
                            if (v != _newPasswordController.text.trim()) return 'Password must match';
                            return null;
                          },
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
                    onPressed: saving ? null : _handleResetFlow,
                    child: saving
                        ? SizedBox(
                      width: screenHeight * .02,
                      height: screenHeight * .02,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(
                      'Continue',
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

// ======================
// OTP dialog widget
// ======================
class _OtpDialog extends StatefulWidget {
  final String email; // ✅ add
  final int cooldownSeconds;
  final Future<void> Function() onResend;
  final Future<void> Function(String otp) onVerify;

  final void Function(String msg) onError;
  final String? Function() getError;

  const _OtpDialog({
    required this.email, // ✅ add
    required this.cooldownSeconds,
    required this.onResend,
    required this.onVerify,
    required this.onError,
    required this.getError,
  });

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  String maskEmail(String email) {
    final e = email.trim();
    final at = e.indexOf('@');
    if (at <= 1) return email; // fallback

    final local = e.substring(0, at);
    final domain = e.substring(at); // kasama na '@'

    if (local.length <= 2) {
      return '${local[0]}*${domain}';
    }

    final start = local.substring(0, 1);
    final end = local.substring(local.length - 1);

    return '$start${'*' * (local.length - 2)}$end$domain';
  }

  final _otp = TextEditingController();
  Timer? _t;
  int _left = 0;

  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown(widget.cooldownSeconds);
  }

  @override
  void dispose() {
    _t?.cancel();
    _otp.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _t?.cancel();
    setState(() => _left = seconds);
    _t = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_left <= 1) {
        timer.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left -= 1);
      }
    });
  }

  String get _otpValue => _otp.text.trim();

  @override
  Widget build(BuildContext context) {
    final err = widget.getError();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter OTP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit OTP to:\n${maskEmail(widget.email)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: err == null ? const Color(0xFFEAEAEA) : const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: err == null ? Colors.transparent : Colors.red, width: 1),
              ),
              child: TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w600),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) {
                  if (widget.getError() != null) widget.onError("");
                },
                decoration: const InputDecoration(border: InputBorder.none, hintText: '000000'),
              ),
            ),

            if (err != null && err.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      err,
                      style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _verifying ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004280),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: (_verifying || _otpValue.length != 6)
                        ? null
                        : () async {
                      setState(() => _verifying = true);
                      try {
                        await widget.onVerify(_otpValue);
                        if (!mounted) return;
                        Navigator.pop(context, true);
                      } catch (e) {
                        final msg = e.toString().replaceFirst('Exception: ', '');
                        if (!mounted) return;
                        widget.onError(msg.isEmpty ? 'Invalid OTP' : msg);
                        HapticFeedback.mediumImpact();
                      } finally {
                        if (mounted) setState(() => _verifying = false);
                      }
                    },
                    child: _verifying
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            InkWell(
              onTap: (_left > 0 || _resending)
                  ? null
                  : () async {
                setState(() => _resending = true);
                try {
                  await widget.onResend();
                  if (!mounted) return;
                  _startCooldown(widget.cooldownSeconds);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('OTP resent. Please check your email.')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                } finally {
                  if (mounted) setState(() => _resending = false);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _left > 0 ? 'Resend OTP (${_left}s)' : 'Resend OTP',
                  style: TextStyle(
                    fontSize: 12,
                    color: (_left > 0) ? Colors.grey : const Color(0xFF004280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

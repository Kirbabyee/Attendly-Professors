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

  String? _otpError;

  // Password validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validateInputs);
    _confirmPasswordController.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_validateInputs);
    _confirmPasswordController.removeListener(_validateInputs);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateInputs() {
    final pw = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    setState(() {
      _hasMinLength = pw.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(pw);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(pw);
      _hasNumber = RegExp(r'[0-9]').hasMatch(pw);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]').hasMatch(pw);
      _passwordsMatch = confirm.isNotEmpty && pw == confirm;
    });
  }

  bool get _isPasswordStrong =>
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;

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

  Future<void> _sendOtp({required String email}) async {
    final res = await supabase.functions.invoke(
      'prof-forgot-otp-send',
      body: {'email': email},
    );

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null) ??
          'Failed to send OTP';
      throw Exception(msg);
    }
  }

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

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null) ??
          'OTP verification failed';
      throw Exception(msg);
    }
  }

  Future<bool> _showOtpModal({
    required String email,
    required Future<void> Function() onResend,
    required Future<void> Function(String otp) onVerify,
    int cooldownSeconds = 60,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpDialog(
        email: email,
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
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    final email = (args['email'] ?? '').toString().trim().toLowerCase();

    if (email.isEmpty) {
      _toast("Missing email. Please go back and try again.");
      return;
    }

    final newPw = _newPasswordController.text.trim();

    setState(() => saving = true);
    try {
      await _sendOtp(email: email);
      if (!mounted) return;

      final verified = await _showOtpModal(
        email: email,
        cooldownSeconds: 60,
        onResend: () => _sendOtp(email: email),
        onVerify: (otp) => _verifyOtpAndReset(
          email: email,
          otp: otp,
          newPassword: newPw,
        ),
      );

      if (!mounted || !verified) return;

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
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFEAF5FB),
      body: Stack(
        children: [
          Stack(
            children: [
              if (!isKeyboard) // Itago ang background shapes kapag may keyboard para mas maluwag
                Positioned(
                  top: screenHeight > 640 ? 0 : -50,
                  left: 0,
                  right: 0,
                  child: Image.asset('assets/Ellipse 2.png', width: double.infinity, fit: BoxFit.cover),
                ),
              if (!isKeyboard)
                Positioned(
                  top: screenHeight > 640 ? 0 : -50,
                  left: 0,
                  right: 0,
                  child: Image.asset('assets/Ellipse 1.png', width: double.infinity, fit: BoxFit.cover),
                ),
            ],
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * .085),
              child: Column(
                children: [
                  SizedBox(height: !isKeyboard ? screenHeight * .18 : 20),
                  Image.asset(
                    'assets/logo.png',
                    width: screenWidth * .9, // Paliitin ang logo kapag may keyboard
                  ),
                  SizedBox(height: screenHeight * .013),
                  Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight * .02),
                  ),
                  SizedBox(height: !isKeyboard ? screenHeight * .03 : 15),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Password', style: TextStyle(fontSize: screenHeight * .017)),
                        SizedBox(height: screenHeight * .008),
                        SizedBox(
                          width: screenWidth * .83,
                          child: TextFormField(
                            obscureText: showPassword,
                            controller: _newPasswordController,
                            style: TextStyle(fontSize: screenHeight * .017),
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
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
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        // Requirements before confirm field
                        _buildRequirementRow('Minimum 8 characters', _hasMinLength),
                        _buildRequirementRow('At least 1 uppercase letter', _hasUppercase),
                        _buildRequirementRow('At least 1 lowercase letter', _hasLowercase),
                        _buildRequirementRow('At least 1 number', _hasNumber),
                        _buildRequirementRow('At least 1 special character', _hasSpecialChar),

                        SizedBox(height: screenHeight * .018),

                        Text('Confirm Password', style: TextStyle(fontSize: screenHeight * .017)),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: screenWidth * .83,
                          child: TextFormField(
                            obscureText: showPassword,
                            controller: _confirmPasswordController,
                            style: TextStyle(fontSize: screenHeight * .017),
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildRequirementRow('Passwords match', _passwordsMatch),
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
                      onPressed: (saving || !_isPasswordStrong || !_passwordsMatch) ? null : _handleResetFlow,
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
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: screenHeight * .018,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: screenHeight * .014,
              color: isMet ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpDialog extends StatefulWidget {
  final String email;
  final int cooldownSeconds;
  final Future<void> Function() onResend;
  final Future<void> Function(String otp) onVerify;
  final void Function(String msg) onError;
  final String? Function() getError;

  const _OtpDialog({
    required this.email,
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
    if (at <= 1) return email;

    final local = e.substring(0, at);
    final domain = e.substring(at);

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

  Future<void> _showSuccessModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
            const SizedBox(height: 14),
            const Text(
              "OTP successfully sent",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please check your email for the new code.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004280),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Got it!", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                        widget.onError(msg.isEmpty ? 'Invalid OTP' : 'Invalid OTP');
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
                  _showSuccessModal();
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

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_handler.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final supabase = Supabase.instance.client;

  // step control
  int step = 1;

  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;

  bool saving = false;
  bool _checkingPw = false;

  String? _pwError;

  final _pwFormKey = GlobalKey<FormState>();
  final _newPwFormKey = GlobalKey<FormState>();

  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newPwController.addListener(_validateInputs);
    _confirmPwController.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _newPwController.removeListener(_validateInputs);
    _confirmPwController.removeListener(_validateInputs);
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  // Password validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  void _validateInputs() {
    final pw = _newPwController.text.trim();
    final confirmPw = _confirmPwController.text.trim();
    setState(() {
      _hasMinLength = pw.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(pw);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(pw);
      _hasNumber = RegExp(r'[0-9]').hasMatch(pw);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]').hasMatch(pw);
      _passwordsMatch = confirmPw.isNotEmpty && confirmPw == pw;
    });
  }

  bool get _isPasswordStrong => 
      _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showSuccess() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
        content: const Text(
          'Your password has been changed successfully.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _checkCurrentPassword() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Not logged in");

    final pw = _currentPwController.text.trim();
    if (pw.isEmpty) throw Exception("Password is required");

    final res = await supabase.functions.invoke(
      'check-password',
      body: {
        'professor_id': userId,
        'current_password': pw,
      },
    );

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null)
          ?? 'Incorrect current password';
      throw Exception(msg);
    }
  }

  Future<void> _sendOtpForChangePassword() async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    final res = await supabase.functions.invoke(
      'prof-change-password-otp',
      body: {'professor_id': user.id},
    );

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null)
          ?? 'Failed to send OTP';
      throw Exception(msg);
    }
  }

  Future<bool> _showOtpModal({
    required String email,
    required String password,
    required Future<void> Function() onResend,
    required Future<void> Function(String otp) onVerify,
    int cooldownSeconds = 60,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OtpDialog(
        email: email,
        password: password,
        cooldownSeconds: cooldownSeconds,
        onResend: onResend,
        onVerify: onVerify,
      ),
    );
    return ok == true;
  }

  Future<void> _verifyOtpAndChangePassword(String otp, String newPassword) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Not logged in");

    final res = await supabase.functions.invoke(
      'prof-change-password-otp-verify',
      body: {
        'professor_id': userId,
        'otp': otp,
        'new_password': newPassword,
      },
    );

    if (res.status != 200) {
      final msg = (res.data is Map ? (res.data['message'] ?? res.data['error']) : null)
          ?? 'OTP verification failed';
      throw Exception(msg);
    }
  }


  InputDecoration _input(String hint, {Widget? suffix, String? errorText}) {
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
      errorText: errorText,
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
                    child: const Icon(Icons.lock_outline, color: Colors.white, size: 50),
                  ),
                  const SizedBox(width: 15),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 15),
                      ),
                      SizedBox(height: 6),
                      Text('Secure your account', style: TextStyle(fontSize: 11, color: Colors.white)),
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
                  const Text('Back'),
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
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 5))],
                    ),
                    child: step == 1 ? _currentPasswordStep() : _newPasswordStep(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentPasswordStep() {
    final w = MediaQuery.of(context).size.width;

    return Column(
      children: [
        const Text(
          'Confirm your current password',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'For security, enter your current password to continue.',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        Form(
          key: _pwFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Password', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _currentPwController,
                obscureText: !showCurrent,
                style: const TextStyle(fontSize: 12),
                onChanged: (_) {
                  if (_pwError != null) setState(() => _pwError = null);
                },
                decoration: _input(
                  'Enter current password',
                  errorText: _pwError != null ? _pwError : null,
                  suffix: IconButton(
                    onPressed: () => setState(() => showCurrent = !showCurrent),
                    icon: Icon(showCurrent ? Icons.visibility : Icons.visibility_off, size: 18),
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
            onPressed: _checkingPw
                ? null
                : () async {
              if (!_pwFormKey.currentState!.validate()) return;

              setState(() {
                _checkingPw = true;
                _pwError = null;
              });

              try {
                await _checkCurrentPassword();
                if (!mounted) return;
                setState(() => step = 2);
              } catch (e) {
                final msg = ErrorHandler.getMessage(e);
                if (!mounted) return;
                setState(() => _pwError = msg);
              } finally {
                if (mounted) setState(() => _checkingPw = false);
              }
            },
            child: _checkingPw
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _newPasswordStep() {
    final w = MediaQuery.of(context).size.width;

    return Column(
      children: [
        const Text(
          'Set your new password',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Use a strong password you can remember.',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        Form(
          key: _newPwFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Password', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _newPwController,
                obscureText: !showNew,
                style: const TextStyle(fontSize: 12),
                decoration: _input(
                  'Enter new password',
                  suffix: IconButton(
                    onPressed: () => setState(() => showNew = !showNew),
                    icon: Icon(showNew ? Icons.visibility : Icons.visibility_off, size: 18),
                  ),
                ),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v == _currentPwController.text.trim()) return 'New password must be different';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ✅ Password Requirement List
              _buildRequirementRow('Minimum 8 characters', _hasMinLength),
              _buildRequirementRow('At least 1 uppercase letter', _hasUppercase),
              _buildRequirementRow('At least 1 lowercase letter', _hasLowercase),
              _buildRequirementRow('At least 1 number', _hasNumber),
              _buildRequirementRow('At least 1 special character', _hasSpecialChar),

              const SizedBox(height: 12),

              const Text('Confirm Password', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmPwController,
                obscureText: !showConfirm,
                style: const TextStyle(fontSize: 12),
                decoration: _input(
                  'Re-enter new password',
                  suffix: IconButton(
                    onPressed: () => setState(() => showConfirm = !showConfirm),
                    icon: Icon(showConfirm ? Icons.visibility : Icons.visibility_off, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // ✅ Passwords match validation
              _buildRequirementRow('Passwords match', _passwordsMatch),
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
            onPressed: (saving || !_isPasswordStrong || !_passwordsMatch)
                ? null
                : () async {
              if (!_newPwFormKey.currentState!.validate()) return;

              final newPw = _newPwController.text.trim();

              setState(() => saving = true);
              try {
                await _sendOtpForChangePassword();
                if (!mounted) return;

                final currentEmail = supabase.auth.currentUser?.email ?? '';

                final verified = await _showOtpModal(
                  email: currentEmail,
                  password: newPw,
                  cooldownSeconds: 60,
                  onResend: () => _sendOtpForChangePassword(),
                  onVerify: (otp) => _verifyOtpAndChangePassword(otp, newPw),
                );

                if (!mounted) return;
                if (!verified) return;

                await _showSuccess();
                if (!mounted) return;

                Navigator.pop(context, true);
              } catch (e) {
                _toast(ErrorHandler.getMessage(e));
              } finally {
                if (mounted) setState(() => saving = false);
              }
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
                Text(saving ? 'Saving...' : 'Update Password', style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}


class _OtpDialog extends StatefulWidget {
  final String email;
  final String password;
  final int cooldownSeconds;
  final Future<void> Function() onResend;
  final Future<void> Function(String otp) onVerify;

  const _OtpDialog({
    required this.email,
    required this.password,
    required this.cooldownSeconds,
    required this.onResend,
    required this.onVerify,
  });

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  String? _otpError;
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

    _otp.addListener(() {
      if (mounted) setState(() {});
    });
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
                color: _otpError == null ? const Color(0xFFEAEAEA) : const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _otpError == null ? Colors.transparent : Colors.red,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) {
                  if (_otpError != null) setState(() => _otpError = null);
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '000000',
                ),
              ),
            ),
            if (_otpError != null) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$_otpError',
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
                        final msg = ErrorHandler.getMessage(e);

                        if (!mounted) return;
                        setState(() => _otpError = msg);

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
                setState(() {
                  _resending = true;
                  _otpError = null;
                  _otp.clear();
                });
                try {
                  await widget.onResend();
                  if (!mounted) return;
                  _startCooldown(widget.cooldownSeconds);
                  _showSuccessModal();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ErrorHandler.getMessage(e))),
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

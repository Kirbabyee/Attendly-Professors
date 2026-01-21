import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TwoFAVerificationPage extends StatefulWidget {
  final String email; // display only
  final Future<bool> Function(String otp) onVerify;
  final Future<void> Function() onResend;
  final int resendSeconds;

  const TwoFAVerificationPage({
    super.key,
    required this.email,
    required this.onVerify,
    required this.onResend,
    this.resendSeconds = 60,
  });

  static Future<bool?> open(
      BuildContext context, {
        required String email,
        required Future<bool> Function(String otp) onVerify,
        required Future<void> Function() onResend,
        int resendSeconds = 60,
      }) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => TwoFAVerificationPage(
          email: email,
          onVerify: onVerify,
          onResend: onResend,
          resendSeconds: resendSeconds,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<TwoFAVerificationPage> createState() => _TwoFAVerificationPageState();
}

class _TwoFAVerificationPageState extends State<TwoFAVerificationPage> {
  // ✅ one controller only
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();

  bool _verifying = false;
  String? _error;

  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.resendSeconds;
    _startCountdown();

    // auto focus after open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remaining = widget.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _otpValue => _otp.text.trim();
  bool get _otpComplete => RegExp(r'^\d{6}$').hasMatch(_otpValue);

  Future<void> _verify() async {
    if (!_otpComplete || _verifying) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final ok = await widget.onVerify(_otpValue);
      if (!mounted) return;

      if (!ok) {
        setState(() => _error = "Invalid OTP. Try again.");
        HapticFeedback.mediumImpact();
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Verification failed. $e");
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_remaining > 0) return;

    setState(() => _error = null);
    try {
      await widget.onResend();
      if (!mounted) return;

      _otp.clear();
      _otpFocus.requestFocus();
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Resend failed. $e");
    }
  }

  void _cancel() => Navigator.of(context).pop(false);

  Widget _otpBox(String? ch, {required bool active}) {
    final hasError = _error != null && _error!.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 34,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError
              ? Colors.red
              : (active ? const Color(0xFF004280) : Colors.transparent),
          width: (hasError || active) ? 1.5 : 0,
        ),
      ),
      child: Text(
        ch ?? "",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verifyEnabled = _otpComplete && !_verifying;

    // ✅ always show 6 boxes
    final padded = _otpValue.padRight(6);
    final d = padded.substring(0, 6).split('');

    // active box = next empty (or last if complete)
    int activeIndex = d.indexWhere((e) => e.trim().isEmpty);
    if (activeIndex == -1) activeIndex = 5;

    final hasError = _error != null && _error!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.45),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Enter OTP",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We sent a 6-digit OTP to your email.\nPlease enter it below.",
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(fontSize: 12.5, color: Colors.black.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 14),

                  // ✅ One real TextField, 6 visual boxes
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _otpFocus.requestFocus(),
                    child: Stack(
                      children: [
                        // keep keyboard + cursor working
                        SizedBox(
                          height: 72,
                          child: TextField(
                            controller: _otp,
                            focusNode: _otpFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            // ✅ make it "invisible" but still focusable
                            style: const TextStyle(
                              color: Colors.transparent,
                              height: 0.01, // keep caret area tiny
                            ),
                            cursorColor: Colors.transparent,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) {
                              if (hasError) setState(() => _error = null);
                              setState(() {}); // refresh boxes
                            },
                            onSubmitted: (_) => _verify(),
                          ),
                        ),

                        // visual container
                        IgnorePointer(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F1F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasError ? Colors.red : Colors.transparent,
                                width: hasError ? 1.2 : 0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                6,
                                    (i) => _otpBox(
                                  d[i].trim().isEmpty ? null : d[i],
                                  active: i == activeIndex,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (hasError) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _verifying ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: verifyEnabled ? _verify : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004280),
                            disabledBackgroundColor: const Color(0xFF004280).withOpacity(0.35),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _verifying
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                              : const Text("Verify", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  InkWell(
                    onTap: _resend,
                    child: Text(
                      _remaining > 0 ? "Resend OTP (${_remaining}s)" : "Resend OTP",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _remaining > 0 ? Colors.black38 : const Color(0xFF004280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

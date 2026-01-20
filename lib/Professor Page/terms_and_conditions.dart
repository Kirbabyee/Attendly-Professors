import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'professor_session.dart'; // ✅ use your prof session cache
import 'mainshell.dart';
import '../main.dart'; // LandingPage / root

class ProfTermsAndConditionsPage extends StatefulWidget {
  const ProfTermsAndConditionsPage({super.key});

  @override
  State<ProfTermsAndConditionsPage> createState() => _ProfTermsAndConditionsPageState();
}

class _ProfTermsAndConditionsPageState extends State<ProfTermsAndConditionsPage> {
  final supabase = Supabase.instance.client;

  final _scroll = ScrollController();
  bool _reachedBottom = false;

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 8) {
        setState(() => _reachedBottom = true);
      }
    });
  }

  void _onScroll() {
    if (_reachedBottom) return;
    if (!_scroll.hasClients) return;

    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.offset;

    if (max <= 8 || (max - cur) < 24) {
      setState(() => _reachedBottom = true);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_reachedBottom || _saving) return;

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception("Not logged in");

      await supabase.from('professors').update({'terms_conditions': 1}).eq('id', uid);

      ProfessorSession.clear();
      try {
        await ProfessorSession.get(force: true);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Mainshell()),
            (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _err = "$e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _decline() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
          (route) => false,
    );
  }

  // helpers (same as student)
  Widget _muted(String t) => Text(t, style: const TextStyle(fontSize: 12, color: Colors.black54));
  Widget _p(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 13.2, height: 1.55)),
  );
  Widget _secTitle(String t) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
  );
  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("•  ", style: TextStyle(fontSize: 13.2, height: 1.55)),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 13.2, height: 1.55))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FB),
      body: Stack(
        children: [
          Container(color: Colors.black.withOpacity(0.35)),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 320,
                maxHeight: size.height * 0.72,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: const Text(
                        "Terms & Conditions",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Scrollbar(
                        controller: _scroll,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _muted("Last updated: 4 October 2023"),
                              const SizedBox(height: 10),

                              _p(
                                "Please read these terms and conditions (\"terms and conditions\", \"terms\") carefully before using Attendly (\"application\", \"app\", \"service\").",
                              ),

                              _secTitle("1. Terms of Service"),
                              _p(
                                "Welcome to Attendly. By accessing or using the Attendly system, you agree to comply with and be bound by these Terms of Service. If you do not agree with these terms, please refrain from using the system.",
                              ),

                              _secTitle("2. Privacy Policy"),
                              _p(
                                "Attendly is committed to protecting user privacy and handling personal data responsibly. This policy explains how information is collected, used, and safeguarded within the system.",
                              ),

                              _secTitle("Information Collected"),
                              _bullet("Professor identification details (e.g., name, ID, assigned classes)."),
                              _bullet("Device identifiers used for presence validation."),
                              _bullet("Attendance/class-related records (course, schedule, sessions)."),

                              _secTitle("Data Sharing"),
                              _p("Attendly does not sell, rent, or share user data with third parties."),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (_err != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _saving ? null : _decline,
                              child: const Text("Decline", style: TextStyle(color: Colors.black)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_reachedBottom && !_saving) ? _accept : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004280),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF004280).withOpacity(0.35),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : Text(_reachedBottom ? "Accept" : "Scroll"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../professor_session.dart';
import 'privacy_policy.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  void initState() {
    super.initState();
    _loadProfessor();
  }

  Map<String, dynamic>? _professor;
  bool _loadingProfessor = true;
  String? _professorError;

  Future<void> _loadProfessor({bool force = false}) async {
    setState(() {
      _professorError = null;
      if (_professor == null) _loadingProfessor = true;
    });

    try {
      final s = await ProfessorSession.get(force: force); // ✅ use force
      if (!mounted) return;
      setState(() {
        _professor = s;
        _loadingProfessor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _professorError = e.toString();
        _loadingProfessor = false;
      });
    }
  }

  bool isOn = false;

  String termOfService = 'Welcome to Attendly. By accessing or using the Attendly system, you agree to comply with and be bound by the following Terms of Service. If you do not agree with these terms, please refrain from using the system.\n'
      '\nAttendly is an attendance monitoring system designed for academic use. The system verifies attendance through network-based detection, hardware-assisted presence validation, and biometric face verification. Users are expected to use the system solely for its intended educational purpose.\n'
      '\nUsers must provide accurate and truthful information during account usage. Any attempt to misuse the system, falsify attendance records, impersonate another user, tamper with assigned devices, or bypass verification mechanisms is strictly prohibited and may result in account suspension or administrative action.\n'
      '\nAttendly does not guarantee uninterrupted availability and may experience temporary downtime due to maintenance or technical limitations. The system is provided “as is” for academic and institutional use.\n'
      '\nAttendly reserves the right to update, modify, or suspend system features when necessary to improve performance, security, or compliance with institutional requirements.';

  String privacyPolicy = PrivacyPolicy().privacyPolicy;

  Widget sectionTitle(String text) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.only(bottom: screenHeight * .009, top: screenHeight * .015),
      child: Text(
        text,
        style: TextStyle(
          fontSize: screenHeight * .018,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget bullet(String text) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.only(left: screenHeight * .011, bottom: screenHeight * .009),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(fontSize: screenHeight * .017)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: screenHeight * .017, height: screenHeight * .0018),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER (fixed)
            Container(
              height: screenHeight * .12,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * .08),
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
                      size: screenHeight * .06,
                    ),
                  ),
                  SizedBox(width: 15),
                  Container(
                    height: screenHeight * .06,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: screenHeight * .018,
                          ),
                        ),
                        SizedBox(height: screenHeight * .01),
                        Text(
                          'Manage your preferences',
                          style: TextStyle(
                            fontSize: screenHeight * .014,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: screenHeight * .023),
                child: Column(
                  children: [
                    // Account Information
                    SizedBox(
                      width: screenWidth * .9,
                      height: screenHeight * .083,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(8),
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                        ),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/account_information');
                          await _loadProfessor(force: true);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline_outlined, color: Colors.black, size: screenHeight * .023,),
                                SizedBox(width: 10),
                                Text(
                                  'Account Information',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: screenHeight * .017
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.keyboard_arrow_right, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * .023),

                    // Notification
                    Container(
                      width: screenWidth * .9,
                      padding: EdgeInsets.all(screenHeight * .023),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_outlined, size: screenHeight * .023, color: Colors.black),
                              SizedBox(width: 10),
                              Text(
                                'Notification',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: screenHeight * .017
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: 10),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * .05, vertical: screenHeight * .005),
                            decoration: BoxDecoration(
                              color: Color(0x90D9D9D9),
                              borderRadius: BorderRadiusGeometry.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Push Notification',
                                      style: TextStyle(fontSize: screenHeight * .014, fontWeight: FontWeight.w600),
                                    ),
                                    Text('Receive app notifications', style: TextStyle(fontSize: screenHeight * .014)),
                                  ],
                                ),
                                Transform.scale(
                                  scale: screenHeight * .001,
                                  child: Switch(
                                    value: isOn,
                                    onChanged: (value) {
                                      setState(() {
                                        isOn = value;
                                      });
                                    },
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: Color(0xFF043B6F),
                                    inactiveTrackColor: Colors.white,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * .023),

                    Container(
                      width: screenWidth * .9,
                      padding: EdgeInsets.all(screenHeight * .023),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings, size: screenHeight * .023, color: Colors.black),
                              SizedBox(width: 10),
                              Text(
                                'Session Settings',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: screenHeight * .017
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: 10),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: screenWidth * .05, vertical: screenHeight * .005),
                            decoration: BoxDecoration(
                              color: Color(0x90D9D9D9),
                              borderRadius: BorderRadiusGeometry.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-End Sessions',
                                      style: TextStyle(fontSize: screenHeight * .014, fontWeight: FontWeight.w600),
                                    ),
                                    Text('End Session when class time expires', style: TextStyle(fontSize: screenHeight * .012)),
                                  ],
                                ),
                                Transform.scale(
                                  scale: screenHeight * .001,
                                  child: Switch(
                                    value: isOn,
                                    onChanged: (value) {
                                      setState(() {
                                        isOn = value;
                                      });
                                    },
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: Color(0xFF043B6F),
                                    inactiveTrackColor: Colors.white,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * .023),
                    // Security & Privacy
                    Container(
                      width: screenWidth * .9,
                      padding: EdgeInsets.all(screenHeight * .023),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_outline, size: screenHeight * .023, color: Colors.black),
                              SizedBox(width: 10),
                              Text(
                                'Security & Privacy',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: screenHeight * .017
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: screenHeight * .013),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/change_password');
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadiusGeometry.circular(8),
                              ),
                              side: BorderSide.none,
                              backgroundColor: Color(0x90D9D9D9),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: screenHeight * .013),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Change Password',
                                        style: TextStyle(
                                          fontSize: screenHeight * .014,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        'Update your account password',
                                        style: TextStyle(
                                          fontSize: screenHeight * .014,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_right,
                                    size: screenHeight * .023,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * .023),

                    // About
                    Container(
                      width: screenWidth * .9,
                      padding: EdgeInsets.all(screenHeight * .023),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: screenHeight * .023),
                              SizedBox(width: 10),
                              Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight * .017)),
                            ],
                          ),
                          SizedBox(height: screenHeight * .023),
                          SizedBox(
                            width: screenWidth * .7,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'App Version',
                                  style: TextStyle(
                                      fontSize: screenHeight * .015
                                  ),
                                ),
                                Text(
                                  '1.0.0',
                                  style: TextStyle(
                                      fontSize: screenHeight * .015
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          SizedBox(
                            width: screenWidth * .7,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Build',
                                  style: TextStyle(
                                      fontSize: screenHeight * .015
                                  ),
                                ),
                                Text(
                                  '2025.30.14',
                                  style: TextStyle(
                                      fontSize: screenHeight * .015
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10,),

                    // Terms and Privacy Policy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            height: screenHeight * .021,
                            child: InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadiusGeometry.circular(8)
                                        ),
                                        backgroundColor: Colors.white,
                                        title: Text(
                                          'Terms of Service',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: screenHeight * .027
                                          ),
                                        ),
                                        content: SingleChildScrollView( // 👈 makes it scrollable
                                          child: Text(
                                            termOfService,
                                            textAlign: TextAlign.justify,
                                            style: TextStyle(
                                                fontSize: screenHeight * .019
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                      fontSize: screenHeight * .015,
                                      color: Colors.black
                                  ),
                                )
                            )
                        ),
                        SizedBox(width: screenHeight * .023,),
                        SizedBox(
                          height: screenHeight * .021,
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadiusGeometry.circular(8)
                                    ),
                                    backgroundColor: Colors.white,
                                    title: Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: screenHeight * .027
                                      ),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Attendly is committed to protecting user privacy and handling personal data responsibly.',
                                            style: TextStyle(fontSize: screenHeight * .017, height: screenHeight * .0019),
                                          ),

                                          sectionTitle('Information Collected'),
                                          bullet('professor and professor identification details'),
                                          bullet('Device identifiers used for presence validation'),
                                          bullet('Facial biometric data for face verification'),
                                          bullet('Attendance timestamps and class records'),

                                          sectionTitle('Use of Information'),
                                          bullet('Verifying professor identity and physical presence'),
                                          bullet('Recording and managing attendance'),
                                          bullet('Supporting academic and administrative processes'),

                                          sectionTitle('Data Protection'),
                                          Text(
                                            'Facial data is stored as encrypted templates and protected through access controls.',
                                            style: TextStyle(fontSize: screenHeight * .017, height: screenHeight * .0019),
                                          ),

                                          sectionTitle('User Rights'),
                                          bullet('Access attendance records'),
                                          bullet('Request correction of inaccurate information'),
                                          bullet('Request face re-enrollment'),

                                          sectionTitle('Policy Updates'),
                                          Text(
                                            'This Privacy Policy may be updated to reflect system or regulatory changes.',
                                            style: TextStyle(fontSize: screenHeight * .017, height: screenHeight * .0019),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenHeight * .015
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * .023),

                    // Logout Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Color(0xFFFDDCDC),
                        side: BorderSide.none,
                      ),
                      onPressed: () async {
                        final bool? confirm = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: Colors.white,
                              title: Text(
                                'Sign Out',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: screenHeight * .025),
                              ),
                              content: Text(
                                'Are you sure you want to sign out?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: screenHeight * .017
                                ),
                              ),
                              actionsAlignment: MainAxisAlignment.center,
                              actions: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text('Cancel', style: TextStyle(color: Colors.black, fontSize: screenHeight * .017)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB60202),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: screenHeight * .017)),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm != true) return;

                        // Loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) {
                            return Dialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: EdgeInsets.all(screenHeight * .021),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: screenHeight * .021,
                                      child: const CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Signing out...', style: TextStyle(fontSize: screenHeight * .017)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        try {
                          // ✅ ito na yung tunay na “delay”
                          await Supabase.instance.client.auth.signOut();
                          ProfessorSession.clear();

                          if (!mounted) return;
                          Navigator.pop(context); // close loading dialog

                          // ✅ clear stack, go to login
                          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                        } catch (e) {
                          if (!mounted) return;
                          Navigator.pop(context); // close loading dialog

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logout failed: $e')),
                          );
                        }
                      },
                      icon: Icon(Icons.logout_outlined, color: Colors.red, size: screenHeight * .023,),
                      label: Text('Sign Out', style: TextStyle(color: Colors.red, fontSize: screenHeight * .017)),
                    ),

                    SizedBox(height: screenHeight * .023),
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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../login.dart';
import 'privacy_policy.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool pushNotif = false;
  bool sessionNotif = false;

  String termOfService = 'Welcome to Attendly. By accessing or using the Attendly system, you agree to comply with and be bound by the following Terms of Service. If you do not agree with these terms, please refrain from using the system.\n'
  '\nAttendly is an attendance monitoring system designed for academic use. The system verifies attendance through network-based detection, hardware-assisted presence validation, and biometric face verification. Users are expected to use the system solely for its intended educational purpose.\n'
  '\nUsers must provide accurate and truthful information during account usage. Any attempt to misuse the system, falsify attendance records, impersonate another user, tamper with assigned devices, or bypass verification mechanisms is strictly prohibited and may result in account suspension or administrative action.\n'
  '\nAttendly does not guarantee uninterrupted availability and may experience temporary downtime due to maintenance or technical limitations. The system is provided “as is” for academic and institutional use.\n'
  '\nAttendly reserves the right to update, modify, or suspend system features when necessary to improve performance, security, or compliance with institutional requirements.';

  String privacyPolicy = PrivacyPolicy().privacyPolicy;

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER (fixed)
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
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    // Account Information
                    SizedBox(
                      width: screenHeight > 700 ? 350 : 320,
                      height: 80,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusGeometry.circular(8),
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/account_information');
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline_outlined, color: Colors.black),
                                SizedBox(width: 10),
                                Text(
                                  'Account Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.keyboard_arrow_right, color: Colors.black),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Notification
                    Container(
                      width: screenHeight > 700 ? 350 : 320,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_outlined, size: 20, color: Colors.black),
                              SizedBox(width: 10),
                              Text(
                                'Notification',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: 10),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 3),
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
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    Text('Receive app notifications', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                Transform.scale(
                                  scale: screenHeight > 700 ? 1 : .8,
                                  child: Switch(
                                    value: pushNotif,
                                    onChanged: (value) {
                                      setState(() {
                                        pushNotif = value;
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
                          SizedBox(height: 10,),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 3),
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
                                      'Session Start Alerts',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    Text('Get notified before session start', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                Transform.scale(
                                  scale: screenHeight > 700 ? 1 : .8,
                                  child: Switch(
                                    value: sessionNotif,
                                    onChanged: (value) {
                                      setState(() {
                                        sessionNotif = value;
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
                    SizedBox(height: 20),

                    // Security & Privacy
                    Container(
                      width: screenHeight > 700 ? 350 : 320,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_outline, size: 20, color: Colors.black),
                              SizedBox(width: 10),
                              Text(
                                'Security & Privacy',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: 10),
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
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Change Password',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        'Update your account password',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.keyboard_arrow_right),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // About
                    Container(
                      width: screenHeight > 700 ? 350 : 320,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadiusGeometry.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 20),
                              SizedBox(width: 10),
                              Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: 280,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('App Version'),
                                Text('1.0.0'),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          SizedBox(
                            width: 280,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Build'),
                                Text('2025.30.14'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    // Terms and Privacy Policy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
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
                                    title: const Text(
                                      'Terms of Service',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500
                                      ),
                                    ),
                                    content: SingleChildScrollView( // 👈 makes it scrollable
                                      child: Text(
                                        termOfService,
                                        textAlign: TextAlign.justify,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.underline
                              ),
                            )
                          )
                        ),
                        SizedBox(width: 20,),
                        SizedBox(
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
                                    title: const Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500
                                      ),
                                    ),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Attendly is committed to protecting user privacy and handling personal data responsibly.',
                                            style: TextStyle(fontSize: 14, height: 1.6),
                                          ),

                                          sectionTitle('Information Collected'),
                                          bullet('Student and professor identification details'),
                                          bullet('Device identifiers used for presence validation'),
                                          bullet('Facial biometric data for face verification'),
                                          bullet('Attendance timestamps and class records'),

                                          sectionTitle('Use of Information'),
                                          bullet('Verifying student identity and physical presence'),
                                          bullet('Recording and managing attendance'),
                                          bullet('Supporting academic and administrative processes'),

                                          sectionTitle('Data Protection'),
                                          const Text(
                                            'Facial data is stored as encrypted templates and protected through access controls.',
                                            style: TextStyle(fontSize: 14, height: 1.6),
                                          ),

                                          sectionTitle('User Rights'),
                                          bullet('Access attendance records'),
                                          bullet('Request correction of inaccurate information'),
                                          bullet('Request face re-enrollment'),

                                          sectionTitle('Policy Updates'),
                                          const Text(
                                            'This Privacy Policy may be updated to reflect system or regulatory changes.',
                                            style: TextStyle(fontSize: 14, height: 1.6),
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
                                fontSize: 12,
                                decoration: TextDecoration.underline
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

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
                              title: const Text(
                                'Sign Out',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              content: const Text(
                                'Are you sure you want to sign out?',
                                textAlign: TextAlign.center,
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
                                  child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB60202),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm != true) return;

                        // Loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false, // user can't close it
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
                                    Text('Signing out...',),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        // ✅ Do your logout logic here (Firebase signOut, etc.)
                        await Future.delayed(const Duration(milliseconds: 2000)); // Load for 2 seconds

                        if (!mounted) return;

                        Navigator.pop(context); // close loading dialog

                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const Login()),
                        );
                      },


                      icon: Icon(Icons.logout_outlined, color: Colors.red),
                      label: Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),

                    SizedBox(height: 10),
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

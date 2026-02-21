
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:professor/Professor%20Page/mainshell.dart';
import 'package:professor/Professor%20Page/new_password.dart';
import 'package:professor/Professor%20Page/terms_and_conditions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Professor Page/History/history.dart';
import 'Professor Page/Notification/notification_ui.dart';
import 'Professor Page/Settings/account_information.dart';
import 'Professor Page/Settings/add_device.dart';
import 'Professor Page/Settings/change_password.dart';
import 'Professor Page/Settings/settings.dart';
import 'Professor Page/auth_gate.dart';
import 'Professor Page/device_registration.dart';
import 'Professor Page/forgot_password.dart';
import 'Professor Page/login.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // MUST init firebase in bg isolate
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // optional: do lightweight work only
  // print('BG message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) init Firebase BEFORE messaging
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) register background handler (BEFORE runApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationUI.initOnce();

  FirebaseMessaging.onMessage.listen((msg) async {
    // show banner even when app is open
    await NotificationUI.showFromMessage(msg);
  });

  // 5) Supabase init
  await Supabase.initialize(
    url: 'https://ucfundmbawljngzowzgd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVjZnVuZG1iYXdsam5nem93emdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1OTY5NDQsImV4cCI6MjA4MzE3Mjk0NH0.rPcB5ZIHZ77hR2DzXHKwJp8nF-IJH-bmICzioCma5Bk',
  );

  runApp(const MyApp());
}

// optional shortcut access anywhere
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: const Color(0xFFEAF5FB),
      ),
      home: const AuthGate(), // ito na root
      routes: {
        '/login': (context) => Login(),
        '/history': (context) => History(),
        '/settings': (context) => Settings(),
        '/account_information': (context) => AccountInformation(),
        '/change_password': (context) => ChangePassword(),
        '/forgot_password': (context) => ForgotPassword(),
        '/mainshell': (context) => Mainshell(),
        '/new_password': (context) => NewPassword(),
        '/terms_conditions': (context) => ProfTermsAndConditionsPage(),
        '/add_device': (context) => AddDevice(),
        '/device_registration': (context) => DeviceRegistration(),
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Color(0xFFEAF5FB),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, // To align the whole page in vertically centered
        children: [
          Container( // Logo
            margin: EdgeInsets.fromLTRB(0,screenHeight > 700 ? 150 : 80,0,0),
            child: Image(
              width: screenHeight > 700 ? 400 : 350,
              image: AssetImage('assets/logo.png')
            ),
          ),
          Text( // Subheader
            'Welcome to Attendly Professor',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: screenHeight > 700 ? 16 : 14,
            ),
          ),
          Container( // Subheader
            margin: EdgeInsetsGeometry.symmetric(vertical: screenHeight > 700 ? 60 : 50),
            child: Text(
              'Secure, Fast, and Reliable class attendance for professors monitoring with face verification and network-based authentication',
              textAlign: TextAlign.center,
              style: TextStyle( // Text Style
                fontSize: screenHeight > 700 ? 18 : 16,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton( // Get started button
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const Login()),
              );
            },
            style: ElevatedButton.styleFrom( // Button style
              shape: RoundedRectangleBorder( // To achieved a round rectangle border radius
                borderRadius: BorderRadius.circular(50)
              ),
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5), // Button padding
              backgroundColor: Color(0xFF004280), // Button BG color
            ),
            child: Row( // To arrange in row the widgets inside the button
              mainAxisSize: MainAxisSize.min, // To avoid full-width button
              children: [
                CircleAvatar( // Icon with circular border
                  radius: 15, // Circle size
                  backgroundColor: Colors.white,
                  child: Icon( // Icon
                    Icons.arrow_forward,
                    size: 18, // Icon size
                    color: Color(0xFF004280),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(10,0,15,0),
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                )
              ],
            )
          ),
          Container( // Footer
            margin: EdgeInsets.fromLTRB(0, screenHeight > 700 ? 150 : 90,0,0),
            child: Text(
              '© 2025 Attendly. All rights reserved.',
              style: TextStyle(
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ],
      ),
    );
  }
}


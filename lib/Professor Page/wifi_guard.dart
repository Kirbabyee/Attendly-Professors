import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mainshell.dart'; // Siguraduhing tama ang import path nito

class WifiGuard extends StatefulWidget {
  const WifiGuard({super.key});

  @override
  State<WifiGuard> createState() => _WifiGuardState();
}

class _WifiGuardState extends State<WifiGuard> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeToLocationChanges();
  }

  void _subscribeToLocationChanges() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _channel = supabase
        .channel('public:professors_check') // Mas simple na channel name
        .onPostgresChanges(
      event: PostgresChangeEvent.all, // Pakinggan lahat (update, insert, delete)
      schema: 'public',
      table: 'professors',
      callback: (payload) {
        print('Realtime Payload Received: ${payload.newRecord}'); // Tingnan sa console

        final newLocation = payload.newRecord['location']?.toString().toUpperCase();
        final recordId = payload.newRecord['id'];

        // Siguraduhin na ang update ay para sa kasalukuyang user
        if (recordId == userId && newLocation == 'CLASSROOM') {
          print('Match found! Redirecting...');
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const Mainshell()),
                  (route) => false,
            );
          }
        }
      },
    )
        .subscribe((status, [error]) {
      print('Subscription Status: $status'); // Dapat lumabas ay 'SUBSCRIBED'
      if (error != null) print('Subscription Error: $error');
    });
  }

  @override
  void dispose() {
    // Importante: I-stop ang pag-listen kapag umalis na sa page para iwas memory leak
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.lock_shield_fill,
                  size: 80,
                  color: Color(0xFF004280),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Access Restricted',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 15),
              const Text(
                'You are not connected to the classroom\'s AP. Attendly features are disabled for security purposes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 50),

              // Animated Loader para ipakita na "nagbabantay" ang app
              const CupertinoActivityIndicator(radius: 12),
              const SizedBox(height: 10),
              const Text(
                "Waiting for Classroom Signal...",
                style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic),
              ),

              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.location_north_fill, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text("Current Location: GATE", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              CupertinoButton(
                child: const Text('Log Out', style: TextStyle(color: Colors.black)),
                onPressed: () async => await supabase.auth.signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
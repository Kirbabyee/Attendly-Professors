import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mainshell.dart';

class MaintenanceGuard extends StatefulWidget {
  const MaintenanceGuard({super.key});

  @override
  State<MaintenanceGuard> createState() => _MaintenanceGuardState();
}

class _MaintenanceGuardState extends State<MaintenanceGuard> {
  final supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _listenToMaintenanceStatus();
  }

  void _listenToMaintenanceStatus() {
    // Kinukuha ang realtime updates mula sa system_settings table
    _channel = supabase
        .channel('public:system_settings')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'system_settings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: 'maintenance_mode',
      ),
      callback: (payload) {
        final isActive = payload.newRecord['is_active'] as bool;

        // Kung naging FALSE (Online na), i-close ang maintenance screen
        if (!isActive && mounted) {
          print('System is back online! Redirecting...');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const Mainshell()),
                (route) => false,
          );
        }
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFEFE), // Halos puti para malinis
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE74C3C), // Maintenance Red
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.settings_solid,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'System Maintenance',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Attendly is currently undergoing scheduled maintenance to improve our services. Attendance and other features will be back shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.blueGrey,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 50),

              // Animated Indicator
              const CupertinoActivityIndicator(radius: 10),
              const SizedBox(height: 12),
              const Text(
                "Restoring Services...",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 60),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF2C3E50).withOpacity(0.1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.info_circle_fill, size: 16, color: Color(0xFF2C3E50)),
                    SizedBox(width: 8),
                    Text(
                      "Status: Under Maintenance",
                      style: TextStyle(
                        color: Color(0xFF2C3E50),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              CupertinoButton(
                child: const Text(
                  'Refresh Connection',
                  style: TextStyle(fontSize: 14, color: Colors.blueAccent),
                ),
                onPressed: () {
                  // Manual check logic can be added here
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
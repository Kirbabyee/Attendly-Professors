import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddDevice extends StatefulWidget {
  const AddDevice({super.key});

  @override
  State<AddDevice> createState() => _AddDeviceState();
}

class _AddDeviceState extends State<AddDevice> {
  final _supabase = Supabase.instance.client;
  bool _isScanning = false;
  Map<String, dynamic>? _deviceInfo;
  bool _isLoadingInfo = true;

  final Color primaryBlue = const Color(0xFF004280);
  final Color backgroundColor = const Color(0xFFf0f4f7);

  @override
  void initState() {
    super.initState();
    _fetchCurrentDevice();
  }

  Future<void> _fetchCurrentDevice() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('devices')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        _deviceInfo = data;
        _isLoadingInfo = false;
      });
    } catch (e) {
      setState(() => _isLoadingInfo = false);
    }
  }

  // Reminder Dialog bago mag-scan
  Future<void> _showChangeDeviceReminder() async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Device Reminder", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Changing your device will unbind the current one. Please only proceed if your device is broken or lost.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Proceed", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      setState(() => _isScanning = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: screenHeight * .13,
              padding: EdgeInsets.symmetric(horizontal: screenHeight * .033),
              decoration: const BoxDecoration(
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
                      borderRadius: BorderRadius.circular(7),
                      color: const Color(0x30FFFFFF),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: screenHeight * .053,
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
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
                        SizedBox(height: screenHeight * .013),
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

            SizedBox(height: screenHeight * .053),

            // Back
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(CupertinoIcons.arrow_left, size: screenHeight * .023),
                ),
                Text(
                  'Back',
                  style: TextStyle(fontSize: screenHeight * .017),
                ),
              ],
            ),

            SizedBox(height: screenHeight * .023),
            _isScanning
                ? _buildScannerUI()
                : _isLoadingInfo
                ? _buildLoadingUI() // DITO ANG LOADING STATE
                : _buildMainUI(screenHeight, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 15), // Elegant iOS-style loading
          const SizedBox(height: 15),
          Text(
            "Fetching device status...",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMainUI(double screenHeight, double screenWidth) {
    int battery = _deviceInfo?['battery_level'] ?? 0;
    bool isOnline = _deviceInfo?['is_online'] ?? false;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BIG CPU/MEMORY ICON
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                ),
                child: Icon(Icons.memory, size: 100, color: primaryBlue),
              ),
              const SizedBox(height: 30),

              // DEVICE STATUS SECTION
              Text(
                _deviceInfo != null ? "ESP32 Device Linked" : "No Device Linked",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_deviceInfo != null) ...[
                // ONLINE/OFFLINE CHIP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isOnline ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    isOnline ? "● ONLINE" : "● OFFLINE",
                    style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 25),

                // BATTERY INFO
                SizedBox(
                  width: screenWidth * 0.6,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getBatteryIcon(battery), color: _getBatteryColor(battery)),
                          const SizedBox(width: 10),
                          Text("$battery%", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: battery / 100,
                          backgroundColor: Colors.grey[300],
                          color: _getBatteryColor(battery),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 50),

              // CHANGE DEVICE BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _showChangeDeviceReminder,
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  label: Text(
                    _deviceInfo != null ? "Change Device" : "Link New Device",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                ),
              ),
              if (_deviceInfo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text("MAC: ${_deviceInfo?['mac_address']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerUI() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final code = capture.barcodes.first.rawValue;
            if (code != null) {
              setState(() => _isScanning = false);
              _showConfirmDialog(code);
            }
          },
        ),
        // Overlay guide
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => setState(() => _isScanning = false),
          ),
        ),
      ],
    );
  }

  // Helpers para sa kulay at icons
  Color _getBatteryColor(int level) => level > 60 ? Colors.green : (level > 20 ? Colors.orange : Colors.red);
  IconData _getBatteryIcon(int level) => level > 80 ? Icons.battery_full : (level > 50 ? Icons.battery_6_bar : Icons.battery_alert);

  // Success, Error, at Confirmation Dialogs (Manatili ang dati mong logic...)
  // --- CONFIRMATION DIALOG ---
  void _showConfirmDialog(String detectedValue) {
    String macAddress = detectedValue.trim().toUpperCase();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Icon(Icons.qr_code_2, color: Color(0xFF004280), size: 50),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Device Detected!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "MAC: $macAddress",
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            const Text("Link this device to your account?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true); // Balik sa scanner kung ayaw
            },
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close confirm dialog
              _linkDeviceToSupabase(macAddress); // Proceed to validation and linking
            },
            child: const Text("Bind Device", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- SUPABASE LINKING WITH VALIDATION ---
  Future<void> _linkDeviceToSupabase(String macAddress) async {

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User session not found.';

      // 1. VALIDATION: Check if this MAC is already owned by someone else
      final existingDevice = await _supabase
          .from('devices')
          .select('user_id')
          .eq('mac_address', macAddress)
          .maybeSingle();

      // Kung may nahanap at hindi ID ng current user, error!
      if (existingDevice != null && existingDevice['user_id'] != user.id) {
        if (mounted) Navigator.pop(context); // Close loading
        _showCompactError(
            "Device Busy",
            "This ESP32 is already registered to another user."
        );
        return;
      }

      // 2. UPDATE professors Table (Para sa profile details)
      await _supabase
          .from('professors')
          .update({'mac_address': macAddress})
          .eq('id', user.id);

      // 3. UPSERT Devices Table (Para sa hardware monitoring)
      await _supabase
          .from('devices')
          .upsert({
        'user_id': user.id,
        'mac_address': macAddress,
        'battery_level': 0,
        'is_online': false,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'mac_address');

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      await _showCompactSuccess();

      // Redirect balik sa main shell para ma-refresh ang data
      Navigator.of(context).pushNamedAndRemoveUntil('/mainshell', (route) => false);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showCompactError("Link Failed", e.toString());
      }
    }
  }
  void _showCompactError(String title, String msg) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isScanning = true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("OK", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCompactSuccess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 45),
              const SizedBox(height: 15),
              const Text("Registered!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 8),
              const Text("Device linked successfully.", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              const CircularProgressIndicator(strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 2000));
  }
}
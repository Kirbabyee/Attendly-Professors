import 'dart:async';
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

  // 1. Idagdag ang Controller para ma-control ang camera (start/stop)
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // Iwasan ang sunod-sunod na scan
    facing: CameraFacing.back,
  );

  StreamSubscription<List<Map<String, dynamic>>>? _deviceSubscription;

  final Color primaryBlue = const Color(0xFF004280);
  final Color backgroundColor = const Color(0xFFf0f4f7);

  @override
  void initState() {
    super.initState();
    _initRealtimeListener();
  }

  void _initRealtimeListener() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _deviceSubscription = _supabase
        .from('devices')
        .stream(primaryKey: ['mac_address'])
        .eq('user_id', user.id)
        .listen((List<Map<String, dynamic>> data) {
      if (mounted) {
        setState(() {
          _deviceInfo = data.isNotEmpty ? data.first : null;
          _isLoadingInfo = false;
        });
      }
    }, onError: (error) {
      if (mounted) setState(() => _isLoadingInfo = false);
    });
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _scannerController.dispose();
    _detectionTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  // --- UI COMPONENTS ---

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
                      Icons.memory,
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
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: screenHeight * .005),
                        const Text(
                          'Manage your preferences',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

            SizedBox(height: screenHeight * .013),

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

            SizedBox(height: screenHeight * .013),
            _isScanning
                ? Expanded(child: _buildScannerUI())
                : _isLoadingInfo
                ? _buildLoadingUI()
                : _buildMainUI(screenHeight, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(radius: 15),
          SizedBox(height: 15),
          Text(
            "Fetching device status...",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMainUI(double screenHeight, double screenWidth) {
    int battery = _deviceInfo?['battery_level'] ?? 0;
    bool isOnline = _deviceInfo?['is_online'] ?? false;
    String ssid = _deviceInfo?['connected_ssid'] ?? "Not Connected";
    int rssi = _deviceInfo?['rssi'] ?? -100;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                ),
                child: Icon(Icons.memory, size: 80, color: primaryBlue),
              ),
              const SizedBox(height: 30),

              Text(
                _deviceInfo != null ? "ESP32 Device Linked" : "No Device Linked",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (_deviceInfo != null) ...[
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

                // WIFI CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.blue[50] : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOnline ? Icons.wifi : Icons.wifi_off,
                          color: isOnline ? Colors.blue : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Connected Network",
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              isOnline ? ssid : "Disconnected",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isOnline) _buildSignalIndicator(rssi),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // BATTERY CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Battery Level", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                          Text("$battery%", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: battery / 100,
                          backgroundColor: Colors.grey[100],
                          color: _getBatteryColor(battery),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

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

  Widget _buildSignalIndicator(int rssi) {
    int bars = 0;
    if (rssi > -60) bars = 3;
    else if (rssi > -75) bars = 2;
    else if (rssi > -90) bars = 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 4,
          height: (index + 1) * 4.0,
          decoration: BoxDecoration(
            color: index < bars ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Timer? _detectionTimer;
  String? _lastDetectedCode;
  bool _isProcessing = false;

  Widget _buildScannerUI() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: screenHeight * .35,
              width: double.infinity,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && !_isProcessing) {
                        final String? code = barcodes.first.rawValue;

                        if (code != null) {
                          // Kung bago ang code o nawala ang focus, i-reset ang timer
                          if (code != _lastDetectedCode) {
                            _detectionTimer?.cancel();
                            _lastDetectedCode = code;

                            // Simulan ang delay (e.g., 1.5 seconds na tutok sa QR)
                            _detectionTimer = Timer(const Duration(milliseconds: 1500), () async {
                              _isProcessing = true; // Lock scanning
                              _scannerController.stop();

                              // Visual feedback na nakuha na
                              if (mounted) {
                                setState(() => _isScanning = false);
                                _showConfirmDialog(code);
                                _isProcessing = false;
                                _lastDetectedCode = null;
                              }
                            });
                          }
                        }
                      } else {
                        // Kung walang ma-detect, i-cancel ang timer
                        _detectionTimer?.cancel();
                        _lastDetectedCode = null;
                      }
                    },
                  ),

                  // Square Guide Overlay
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          // Magpapalit ng kulay kapag "puno" na ang timer (Optional visual cue)
                          color: Colors.greenAccent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      // Hint na kailangan mag-antay
                      child: _lastDetectedCode != null
                          ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Hold steady for a moment...', // I-update ang text instruction
            style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              _detectionTimer?.cancel();
              _scannerController.stop();
              setState(() => _isScanning = false);
            },
            icon: const Icon(Icons.close, color: Colors.grey),
            label: const Text('Cancel Scan', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) => level > 60 ? Colors.green : (level > 20 ? Colors.orange : Colors.red);

  // --- LOGIC (RE-BINDING & DIALOGS) ---

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
            const Text("Device Detected!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text("MAC: $macAddress", style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            const SizedBox(height: 15),
            const Text("Link this device to your account?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
              _scannerController.start(); // 5. I-RESTART ang scanner kung kinansela
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
            onPressed: () {
              Navigator.pop(context);
              _linkDeviceToSupabase(macAddress);
            },
            child: const Text("Bind Device", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _linkDeviceToSupabase(String macAddress) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User session not found.';

      final existingDevice = await _supabase
          .from('devices')
          .select('user_id')
          .eq('mac_address', macAddress)
          .maybeSingle();

      if (existingDevice != null && existingDevice['user_id'] != user.id) {
        _showCompactError("Device Busy", "This ESP32 is already registered to another user.");
        return;
      }

      await _supabase.from('professors').update({'mac_address': macAddress}).eq('id', user.id);

      await _supabase.from('devices').upsert({
        'user_id': user.id,
        'mac_address': macAddress,
        'is_online': true,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'mac_address');

      if (!mounted) return;
      await _showCompactSuccess();
      Navigator.of(context).pushNamedAndRemoveUntil('/mainshell', (route) => false);
    } catch (e) {
      if (mounted) _showCompactError("Link Failed", e.toString());
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
                  onPressed: () => Navigator.pop(context),
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
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 45),
              SizedBox(height: 15),
              Text("Registered!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 8),
              Text("Device linked successfully.", style: TextStyle(fontSize: 13, color: Colors.grey)),
              SizedBox(height: 20),
              CircularProgressIndicator(strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 2000));
  }
}